// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_invite_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(inviteByToken)
final inviteByTokenProvider = InviteByTokenFamily._();

final class InviteByTokenProvider
    extends
        $FunctionalProvider<
          AsyncValue<({Group group, GroupInvite invite})?>,
          ({Group group, GroupInvite invite})?,
          FutureOr<({Group group, GroupInvite invite})?>
        >
    with
        $FutureModifier<({Group group, GroupInvite invite})?>,
        $FutureProvider<({Group group, GroupInvite invite})?> {
  InviteByTokenProvider._({
    required InviteByTokenFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'inviteByTokenProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$inviteByTokenHash();

  @override
  String toString() {
    return r'inviteByTokenProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<({Group group, GroupInvite invite})?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({Group group, GroupInvite invite})?> create(Ref ref) {
    final argument = this.argument as String;
    return inviteByToken(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InviteByTokenProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$inviteByTokenHash() => r'93bb2aed312ce473a5830ff2e6ea1d450900029e';

final class InviteByTokenFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<({Group group, GroupInvite invite})?>,
          String
        > {
  InviteByTokenFamily._()
    : super(
        retry: null,
        name: r'inviteByTokenProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InviteByTokenProvider call(String token) =>
      InviteByTokenProvider._(argument: token, from: this);

  @override
  String toString() => r'inviteByTokenProvider';
}

@ProviderFor(invitesByGroup)
final invitesByGroupProvider = InvitesByGroupFamily._();

final class InvitesByGroupProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GroupInvite>>,
          List<GroupInvite>,
          Stream<List<GroupInvite>>
        >
    with
        $FutureModifier<List<GroupInvite>>,
        $StreamProvider<List<GroupInvite>> {
  InvitesByGroupProvider._({
    required InvitesByGroupFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'invitesByGroupProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$invitesByGroupHash();

  @override
  String toString() {
    return r'invitesByGroupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<GroupInvite>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<GroupInvite>> create(Ref ref) {
    final argument = this.argument as String;
    return invitesByGroup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InvitesByGroupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$invitesByGroupHash() => r'639e8bc424ea6f78b76f1b634a57954569eb37bf';

final class InvitesByGroupFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<GroupInvite>>, String> {
  InvitesByGroupFamily._()
    : super(
        retry: null,
        name: r'invitesByGroupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InvitesByGroupProvider call(String groupId) =>
      InvitesByGroupProvider._(argument: groupId, from: this);

  @override
  String toString() => r'invitesByGroupProvider';
}

@ProviderFor(inviteUsages)
final inviteUsagesProvider = InviteUsagesFamily._();

final class InviteUsagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<InviteUsage>>,
          List<InviteUsage>,
          Stream<List<InviteUsage>>
        >
    with
        $FutureModifier<List<InviteUsage>>,
        $StreamProvider<List<InviteUsage>> {
  InviteUsagesProvider._({
    required InviteUsagesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'inviteUsagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$inviteUsagesHash();

  @override
  String toString() {
    return r'inviteUsagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<InviteUsage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<InviteUsage>> create(Ref ref) {
    final argument = this.argument as String;
    return inviteUsages(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is InviteUsagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$inviteUsagesHash() => r'a1f8a5419a1db1154fea714e82e61ef57da23312';

final class InviteUsagesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<InviteUsage>>, String> {
  InviteUsagesFamily._()
    : super(
        retry: null,
        name: r'inviteUsagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  InviteUsagesProvider call(String inviteId) =>
      InviteUsagesProvider._(argument: inviteId, from: this);

  @override
  String toString() => r'inviteUsagesProvider';
}
