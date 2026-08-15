import 'package:hisab_backend/hisab_backend.dart';

/// Test doubles for the backend contract.
///
/// Each facet throws by default, so a test only overrides the handful of calls
/// it expects and any unexpected traffic fails loudly instead of quietly
/// returning empty data.

class FakeCloudInvites implements CloudInvites {
  FakeCloudInvites({
    this.baseUrl = 'https://hisab.example.com',
    Future<Map<String, dynamic>?> Function(String token)? onGetByToken,
    Future<Map<String, dynamic>?> Function(String token)? onPreviewGroup,
    Future<List<Map<String, dynamic>>> Function(String token)?
    onPreviewParticipants,
    Future<List<Map<String, dynamic>>> Function(String token)?
    onPreviewExpenses,
  }) : _onGetByToken = onGetByToken,
       _onPreviewGroup = onPreviewGroup,
       _onPreviewParticipants = onPreviewParticipants,
       _onPreviewExpenses = onPreviewExpenses;

  final String baseUrl;
  final Future<Map<String, dynamic>?> Function(String token)? _onGetByToken;
  final Future<Map<String, dynamic>?> Function(String token)? _onPreviewGroup;
  final Future<List<Map<String, dynamic>>> Function(String token)?
  _onPreviewParticipants;
  final Future<List<Map<String, dynamic>>> Function(String token)?
  _onPreviewExpenses;

  /// Names of the facet methods that were called, in order.
  final List<String> calls = <String>[];

  @override
  String get linkBaseUrl => baseUrl;

  @override
  String linkFor(String token) => '$baseUrl/invite/$token';

  @override
  Uri resolverUrlFor(String token) =>
      Uri.parse('$baseUrl/invite-redirect?token=$token');

  @override
  Future<Map<String, dynamic>?> getByToken(String token) {
    calls.add('getByToken');
    final handler = _onGetByToken;
    if (handler == null) throw UnimplementedError('getByToken');
    return handler(token);
  }

  @override
  Future<Map<String, dynamic>?> previewGroup(String token) {
    calls.add('previewGroup');
    final handler = _onPreviewGroup;
    if (handler == null) throw UnimplementedError('previewGroup');
    return handler(token);
  }

  @override
  Future<List<Map<String, dynamic>>> previewParticipants(String token) {
    calls.add('previewParticipants');
    final handler = _onPreviewParticipants;
    if (handler == null) return Future.value(const []);
    return handler(token);
  }

  @override
  Future<List<Map<String, dynamic>>> previewExpenses(String token) {
    calls.add('previewExpenses');
    final handler = _onPreviewExpenses;
    if (handler == null) return Future.value(const []);
    return handler(token);
  }

  /// Row returned by [create]; override to change the generated ids.
  Map<String, dynamic> createResult = const {
    'id': 'invite-id',
    'token': 'invite-token',
  };

  /// Group id returned by [accept].
  String acceptResult = 'group-id';

  final List<FakeCreateInviteCall> createCalls = [];
  final List<FakeAcceptInviteCall> acceptCalls = [];
  final List<String> revokedIds = [];
  final List<({String inviteId, bool active})> toggledIds = [];

  @override
  Future<Map<String, dynamic>> create(
    String groupId, {
    String? inviteeEmail,
    String? role,
    String? label,
    int? maxUses,
    Duration? expiresIn,
    String accessMode = 'standard',
  }) async {
    calls.add('create');
    createCalls.add(
      FakeCreateInviteCall(
        groupId: groupId,
        inviteeEmail: inviteeEmail,
        role: role,
        label: label,
        maxUses: maxUses,
        expiresIn: expiresIn,
        accessMode: accessMode,
      ),
    );
    return createResult;
  }

  @override
  Future<String> accept(
    String token, {
    String? participantId,
    String? newParticipantName,
  }) async {
    calls.add('accept');
    acceptCalls.add(
      FakeAcceptInviteCall(
        token: token,
        participantId: participantId,
        newParticipantName: newParticipantName,
      ),
    );
    return acceptResult;
  }

  @override
  Future<void> revoke(String inviteId) async {
    calls.add('revoke');
    revokedIds.add(inviteId);
  }

  @override
  Future<void> toggleActive(String inviteId, bool active) async {
    calls.add('toggleActive');
    toggledIds.add((inviteId: inviteId, active: active));
  }
}

class FakeCreateInviteCall {
  const FakeCreateInviteCall({
    required this.groupId,
    required this.inviteeEmail,
    required this.role,
    required this.label,
    required this.maxUses,
    required this.expiresIn,
    required this.accessMode,
  });

  final String groupId;
  final String? inviteeEmail;
  final String? role;
  final String? label;
  final int? maxUses;
  final Duration? expiresIn;
  final String accessMode;
}

class FakeAcceptInviteCall {
  const FakeAcceptInviteCall({
    required this.token,
    required this.participantId,
    required this.newParticipantName,
  });

  final String token;
  final String? participantId;
  final String? newParticipantName;
}

/// Minimal auth facet: only the identity the repositories stamp onto rows.
class FakeCloudAuth implements CloudAuth {
  FakeCloudAuth({this.currentUser});

  @override
  final CloudUser? currentUser;

  @override
  CloudSession? get currentSession =>
      currentUser == null ? null : CloudSession(user: currentUser!);

  @override
  bool get isAuthenticated => currentUser != null;

  @override
  Stream<CloudAuthState> get authStateChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Assembles the facets a test needs. Facets left null throw when touched.
class FakeCloudBackend implements CloudBackend {
  FakeCloudBackend({
    CloudAuth? auth,
    CloudSync? sync,
    CloudInvites? invites,
  }) : _auth = auth ?? FakeCloudAuth(),
       _sync = sync,
       _invites = invites;

  final CloudAuth _auth;
  final CloudSync? _sync;
  final CloudInvites? _invites;

  @override
  CloudAuth get auth => _auth;

  @override
  CloudSync get sync => _sync ?? (throw UnimplementedError('sync'));

  @override
  CloudInvites get invites => _invites ?? (throw UnimplementedError('invites'));

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Records every write the app pushes, so a test can assert on the payload
/// without a server.
class FakeCloudSync implements CloudSync {
  FakeCloudSync({this.currentUserId});

  @override
  final String? currentUserId;

  final List<({String table, Map<String, dynamic> data})> upserts = [];
  final List<({String table, String id, Map<String, dynamic> data})> updates =
      [];
  final List<({String table, String column, Object? value})> updateWheres = [];
  final List<({String table, String id})> deletes = [];

  @override
  Future<void> upsert(
    String table,
    Map<String, dynamic> data, {
    List<String>? conflictColumns,
  }) async {
    upserts.add((table: table, data: data));
  }

  @override
  Future<void> update(
    String table,
    Map<String, dynamic> data,
    String id,
  ) async {
    updates.add((table: table, id: id, data: data));
  }

  @override
  Future<void> updateWhere(
    String table,
    Map<String, dynamic> data, {
    required String column,
    required Object? value,
  }) async {
    updateWheres.add((table: table, column: column, value: value));
  }

  @override
  Future<void> delete(String table, String id) async {
    deletes.add((table: table, id: id));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
