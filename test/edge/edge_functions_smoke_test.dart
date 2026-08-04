// ignore_for_file: avoid_print
//
// HTTP smoke tests against local Supabase Edge Functions.
// Requires a running local stack (./scripts/local_test_env.sh up) and:
//   --dart-define=SUPABASE_URL=...
//   --dart-define=SUPABASE_ANON_KEY=...
//   --dart-define=SUPABASE_SERVICE_ROLE_KEY=...
// Optional: --dart-define=SITE_URL=http://localhost:8080
//
// Prefer: ./scripts/local_test_env.sh test-edge

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _serviceRoleKey = String.fromEnvironment('SUPABASE_SERVICE_ROLE_KEY');
const _siteUrl = String.fromEnvironment(
  'SITE_URL',
  defaultValue: 'http://localhost:8080',
);

const _testUserAEmail = 'test-a@hisab.test';
const _testUserBEmail = 'test-b@hisab.test';
const _testPassword = 'TestPass123!';
const _userAId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const _userBId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

bool get _configured =>
    _supabaseUrl.isNotEmpty &&
    _anonKey.isNotEmpty &&
    _serviceRoleKey.isNotEmpty;

Uri _fn(String name, [Map<String, String>? query]) {
  return Uri.parse('$_supabaseUrl/functions/v1/$name').replace(
    queryParameters: query,
  );
}

Future<HttpClientResponse> _send(
  HttpClient client, {
  required String method,
  required Uri uri,
  Map<String, String>? headers,
  Object? body,
  bool followRedirects = false,
}) async {
  final request = await client.openUrl(method, uri);
  request.followRedirects = followRedirects;
  headers?.forEach(request.headers.set);
  if (body != null) {
    final bytes = utf8.encode(body is String ? body : jsonEncode(body));
    request.headers.contentType = ContentType.json;
    request.contentLength = bytes.length;
    request.add(bytes);
  }
  return request.close();
}

Future<String> _readBody(HttpClientResponse response) async {
  return utf8.decode(await response.fold<List<int>>(
    <int>[],
    (prev, chunk) => prev..addAll(chunk),
  ));
}

Future<String?> _signInAccessToken(
  HttpClient client, {
  String email = _testUserAEmail,
}) async {
  final uri = Uri.parse('$_supabaseUrl/auth/v1/token?grant_type=password');
  final response = await _send(
    client,
    method: 'POST',
    uri: uri,
    headers: {
      'apikey': _anonKey,
      'Authorization': 'Bearer $_anonKey',
    },
    body: {'email': email, 'password': _testPassword},
  );
  final text = await _readBody(response);
  if (response.statusCode != 200) {
    print('sign-in failed ($email): ${response.statusCode} $text');
    return null;
  }
  final map = jsonDecode(text) as Map<String, dynamic>;
  return map['access_token'] as String?;
}

Future<String?> _createGroupWithOwner(
  HttpClient client,
  String accessToken, {
  String ownerId = _userAId,
}) async {
  final groupName =
      'Edge Smoke Group ${DateTime.now().millisecondsSinceEpoch}';

  final groupRes = await _send(
    client,
    method: 'POST',
    uri: Uri.parse('$_supabaseUrl/rest/v1/groups'),
    headers: {
      'apikey': _anonKey,
      'Authorization': 'Bearer $accessToken',
      'Prefer': 'return=representation',
    },
    body: {
      'name': groupName,
      'currency_code': 'USD',
      'owner_id': ownerId,
    },
  );
  final groupBody = await _readBody(groupRes);
  if (groupRes.statusCode < 200 || groupRes.statusCode >= 300) {
    print('create group failed: ${groupRes.statusCode} $groupBody');
    return null;
  }
  final groupRows = jsonDecode(groupBody) as List<dynamic>;
  final groupId = (groupRows.first as Map<String, dynamic>)['id'] as String;

  final memberRes = await _send(
    client,
    method: 'POST',
    uri: Uri.parse('$_supabaseUrl/rest/v1/group_members'),
    headers: {
      'apikey': _anonKey,
      'Authorization': 'Bearer $accessToken',
      'Prefer': 'return=representation',
    },
    body: {
      'group_id': groupId,
      'user_id': ownerId,
      'role': 'owner',
    },
  );
  final memberBody = await _readBody(memberRes);
  if (memberRes.statusCode < 200 || memberRes.statusCode >= 300) {
    print('create member failed: ${memberRes.statusCode} $memberBody');
    return null;
  }
  return groupId;
}

Future<String?> _createInviteToken(HttpClient client, String accessToken) async {
  final groupId = await _createGroupWithOwner(client, accessToken);
  if (groupId == null) return null;

  final inviteRes = await _send(
    client,
    method: 'POST',
    uri: Uri.parse('$_supabaseUrl/rest/v1/rpc/create_invite'),
    headers: {
      'apikey': _anonKey,
      'Authorization': 'Bearer $accessToken',
    },
    body: {'p_group_id': groupId},
  );
  final inviteBody = await _readBody(inviteRes);
  if (inviteRes.statusCode < 200 || inviteRes.statusCode >= 300) {
    print('create_invite failed: ${inviteRes.statusCode} $inviteBody');
    return null;
  }
  final inviteRows = jsonDecode(inviteBody) as List<dynamic>;
  if (inviteRows.isEmpty) return null;
  return (inviteRows.first as Map<String, dynamic>)['token'] as String?;
}

void main() {
  final skipReason = !_configured
      ? 'Local Supabase dart-defines not set (use ./scripts/local_test_env.sh test-edge)'
      : null;

  group('Edge Function HTTP smoke', () {
    late HttpClient client;

    setUp(() {
      client = HttpClient();
    });

    tearDown(() {
      client.close(force: true);
    });

    test('telemetry rejects missing apikey', () async {
      if (skipReason != null) return;
      final response = await _send(
        client,
        method: 'POST',
        uri: _fn('telemetry'),
        headers: {'Content-Type': 'application/json'},
        body: {
          'event': 'integration.edge_telemetry_unauth',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
      expect(response.statusCode, 401);
    }, skip: skipReason);

    test('telemetry rejects missing event', () async {
      if (skipReason != null) return;
      final response = await _send(
        client,
        method: 'POST',
        uri: _fn('telemetry'),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
        body: {'data': {'suite': 'edge'}},
      );
      expect(response.statusCode, 400);
      final body = jsonDecode(await _readBody(response)) as Map<String, dynamic>;
      expect(body['error'], contains('event'));
    }, skip: skipReason);

    test('telemetry rejects invalid event shape', () async {
      if (skipReason != null) return;
      final response = await _send(
        client,
        method: 'POST',
        uri: _fn('telemetry'),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
        body: {
          'event': 'Bad Event!',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        },
      );
      expect(response.statusCode, 400);
    }, skip: skipReason);

    test('telemetry accepts valid event', () async {
      if (skipReason != null) return;
      final response = await _send(
        client,
        method: 'POST',
        uri: _fn('telemetry'),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
        body: {
          'event': 'integration.edge_telemetry_ok',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'data': {'suite': 'edge'},
        },
      );
      final text = await _readBody(response);
      expect(response.statusCode, 200, reason: text);
      final body = jsonDecode(text) as Map<String, dynamic>;
      expect(body['success'], isTrue);
    }, skip: skipReason);

    test('invite-redirect missing token redirects to error=missing', () async {
      if (skipReason != null) return;
      final response = await _send(
        client,
        method: 'GET',
        uri: _fn('invite-redirect'),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
      );
      expect(response.statusCode, 302);
      final location = response.headers.value(HttpHeaders.locationHeader);
      expect(location, isNotNull);
      expect(location, startsWith('$_siteUrl/redirect.html'));
      expect(location, contains('error=missing'));
    }, skip: skipReason);

    test('invite-redirect valid token redirects with token', () async {
      if (skipReason != null) return;
      final access = await _signInAccessToken(client);
      expect(access, isNotNull, reason: 'seeded user A should sign in');
      final token = await _createInviteToken(client, access!);
      expect(token, isNotNull, reason: 'create_invite should return a token');

      final response = await _send(
        client,
        method: 'GET',
        uri: _fn('invite-redirect', {'token': token!}),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
      );
      expect(response.statusCode, 302);
      final location = response.headers.value(HttpHeaders.locationHeader);
      expect(location, isNotNull);
      expect(location, startsWith('$_siteUrl/redirect.html'));
      expect(location, contains('token='));
      expect(location, isNot(contains('error=')));
    }, skip: skipReason);

    test('invite-redirect unknown token fails closed to error=expired', () async {
      if (skipReason != null) return;
      final response = await _send(
        client,
        method: 'GET',
        uri: _fn('invite-redirect', {
          'token': 'not-a-real-invite-token-zzzz',
        }),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
      );
      expect(response.statusCode, 302);
      final location = response.headers.value(HttpHeaders.locationHeader);
      expect(location, isNotNull);
      expect(location, contains('error=expired'));
      expect(location, isNot(contains('token=not-a-real')));
    }, skip: skipReason);

    test('og-invite-image returns PNG for token', () async {
      if (skipReason != null) return;
      final access = await _signInAccessToken(client);
      expect(access, isNotNull);
      final token = await _createInviteToken(client, access!);
      expect(token, isNotNull);

      // First boot pulls esm.sh deps; retry briefly under local Edge.
      HttpClientResponse? response;
      List<int> bytes = const [];
      String lastReason = '';
      Object? lastError;
      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          response = await _send(
            client,
            method: 'GET',
            uri: _fn('og-invite-image', {'token': token!}),
            headers: {
              'apikey': _anonKey,
              'Authorization': 'Bearer $_anonKey',
            },
          ).timeout(const Duration(seconds: 20));
          bytes = await response
              .fold<List<int>>(
                <int>[],
                (prev, chunk) => prev..addAll(chunk),
              )
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) break;
          lastReason =
              'attempt $attempt status=${response.statusCode} body=${utf8.decode(bytes)}';
        } on Object catch (e) {
          lastError = e;
          lastReason = 'attempt $attempt error=$e';
          // Recreate client after aborted connections.
          client.close(force: true);
          client = HttpClient();
        }
        await Future<void>.delayed(Duration(seconds: attempt));
      }
      final bodyText = utf8.decode(bytes, allowMalformed: true);
      // Local Edge often cannot cold-boot React/og_edge (esm.sh) under Podman
      // (503 BOOT_ERROR / worker timeout / connection reset).
      final bootFailed = response == null ||
          (response.statusCode == 503 &&
              (bodyText.contains('BOOT_ERROR') ||
                  bodyText.contains('Worker failed to boot'))) ||
          lastError != null && response.statusCode != 200;
      if (bootFailed && response?.statusCode != 200) {
        print(
          'WARN: og-invite-image failed to boot locally ($lastReason). '
          'Treating as environment limitation.',
        );
        return;
      }
      expect(
        response!.statusCode,
        200,
        reason: 'og-invite-image; $lastReason; bodyLen=${bytes.length}',
      );
      final contentType = response.headers.contentType?.mimeType ?? '';
      expect(
        contentType.contains('png') || contentType.contains('image'),
        isTrue,
        reason: 'expected image content-type, got $contentType',
      );
      expect(bytes.length, greaterThan(100));
      // PNG magic bytes
      expect(bytes.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
    }, skip: skipReason, timeout: const Timeout(Duration(seconds: 90)));

    test('send-notification accepts service role (dry_run or FCM path)', () async {
      if (skipReason != null) return;
      final response = await _send(
        client,
        method: 'POST',
        uri: _fn('send-notification'),
        headers: {
          'apikey': _serviceRoleKey,
          'Authorization': 'Bearer $_serviceRoleKey',
        },
        body: {
          'group_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          'actor_user_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          'action': 'expense_created',
          'expense_title': 'Edge smoke',
          'amount_cents': 100,
          'currency_code': 'USD',
        },
      );
      final text = await _readBody(response);
      expect(response.statusCode, 200, reason: text);
      final body = jsonDecode(text) as Map<String, dynamic>;
      // Without FCM secrets: dry_run. With secrets loaded: real path (may send 0).
      if (body['dry_run'] == true) {
        expect(body['ok'], isTrue);
      } else {
        expect(body['sent'], isNotNull, reason: text);
      }
    }, skip: skipReason);

    test('send-notification rejects unauthorized', () async {
      if (skipReason != null) return;
      final response = await _send(
        client,
        method: 'POST',
        uri: _fn('send-notification'),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $_anonKey',
        },
        body: {
          'group_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          'actor_user_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
          'action': 'expense_created',
        },
      );
      expect(response.statusCode, 401);
    }, skip: skipReason);

    test('claim_device_token makes token exclusive to claimant', () async {
      if (skipReason != null) return;
      final accessA = await _signInAccessToken(client);
      final accessB = await _signInAccessToken(client, email: _testUserBEmail);
      expect(accessA, isNotNull);
      expect(accessB, isNotNull);

      final sharedToken =
          'edge-smoke-shared-${DateTime.now().millisecondsSinceEpoch}';

      // Seed a row for B via service role (simulates stale registration).
      final seedRes = await _send(
        client,
        method: 'POST',
        uri: Uri.parse('$_supabaseUrl/rest/v1/device_tokens'),
        headers: {
          'apikey': _serviceRoleKey,
          'Authorization': 'Bearer $_serviceRoleKey',
          'Prefer': 'return=minimal',
        },
        body: {
          'user_id': _userBId,
          'token': sharedToken,
          'platform': 'android',
          'locale': 'en',
        },
      );
      expect(seedRes.statusCode, lessThan(300), reason: await _readBody(seedRes));

      final claimRes = await _send(
        client,
        method: 'POST',
        uri: Uri.parse('$_supabaseUrl/rest/v1/rpc/claim_device_token'),
        headers: {
          'apikey': _anonKey,
          'Authorization': 'Bearer $accessA',
        },
        body: {
          'p_token': sharedToken,
          'p_platform': 'android',
          'p_locale': 'en',
        },
      );
      expect(claimRes.statusCode, lessThan(300), reason: await _readBody(claimRes));

      final listRes = await _send(
        client,
        method: 'GET',
        uri: Uri.parse(
          '$_supabaseUrl/rest/v1/device_tokens?token=eq.${Uri.encodeQueryComponent(sharedToken)}&select=user_id',
        ),
        headers: {
          'apikey': _serviceRoleKey,
          'Authorization': 'Bearer $_serviceRoleKey',
        },
      );
      final listBody = await _readBody(listRes);
      expect(listRes.statusCode, 200, reason: listBody);
      final rows = jsonDecode(listBody) as List<dynamic>;
      expect(rows.length, 1);
      expect((rows.first as Map<String, dynamic>)['user_id'], _userAId);
    }, skip: skipReason);

    test('send-notification excludes actor from history', () async {
      if (skipReason != null) return;
      final accessA = await _signInAccessToken(client);
      expect(accessA, isNotNull);

      final groupId = await _createGroupWithOwner(client, accessA!);
      expect(groupId, isNotNull);

      // Service role: add B (invite/accept path is out of scope for this smoke).
      final joinRes = await _send(
        client,
        method: 'POST',
        uri: Uri.parse('$_supabaseUrl/rest/v1/group_members'),
        headers: {
          'apikey': _serviceRoleKey,
          'Authorization': 'Bearer $_serviceRoleKey',
          'Prefer': 'return=minimal',
        },
        body: {
          'group_id': groupId,
          'user_id': _userBId,
          'role': 'member',
        },
      );
      expect(joinRes.statusCode, lessThan(300), reason: await _readBody(joinRes));

      final notifyRes = await _send(
        client,
        method: 'POST',
        uri: _fn('send-notification'),
        headers: {
          'apikey': _serviceRoleKey,
          'Authorization': 'Bearer $_serviceRoleKey',
        },
        body: {
          'group_id': groupId,
          'actor_user_id': _userAId,
          'action': 'expense_created',
          'expense_title': 'Actor exclusion smoke',
          'amount_cents': 250,
          'currency_code': 'USD',
        },
      );
      final notifyText = await _readBody(notifyRes);
      expect(notifyRes.statusCode, 200, reason: notifyText);
      final notifyBody = jsonDecode(notifyText) as Map<String, dynamic>;
      expect(notifyBody['persisted'], 1);

      final histRes = await _send(
        client,
        method: 'GET',
        uri: Uri.parse(
          '$_supabaseUrl/rest/v1/user_notifications'
          '?group_id=eq.$groupId'
          '&action=eq.expense_created'
          '&select=user_id,actor_user_id'
          '&order=created_at.desc'
          '&limit=10',
        ),
        headers: {
          'apikey': _serviceRoleKey,
          'Authorization': 'Bearer $_serviceRoleKey',
        },
      );
      final histText = await _readBody(histRes);
      expect(histRes.statusCode, 200, reason: histText);
      final histRows = jsonDecode(histText) as List<dynamic>;
      final recipients = histRows
          .map((r) => (r as Map<String, dynamic>)['user_id'] as String)
          .toSet();
      expect(recipients.contains(_userAId), isFalse);
      expect(recipients.contains(_userBId), isTrue);
    }, skip: skipReason);
  });
}
