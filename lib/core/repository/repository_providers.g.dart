// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repository_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(groupRepository)
final groupRepositoryProvider = GroupRepositoryProvider._();

final class GroupRepositoryProvider
    extends
        $FunctionalProvider<
          IGroupRepository,
          IGroupRepository,
          IGroupRepository
        >
    with $Provider<IGroupRepository> {
  GroupRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupRepositoryHash();

  @$internal
  @override
  $ProviderElement<IGroupRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IGroupRepository create(Ref ref) {
    return groupRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IGroupRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IGroupRepository>(value),
    );
  }
}

String _$groupRepositoryHash() => r'80ef1d952d4028a529ac365f605e237455ba83db';

@ProviderFor(participantRepository)
final participantRepositoryProvider = ParticipantRepositoryProvider._();

final class ParticipantRepositoryProvider
    extends
        $FunctionalProvider<
          IParticipantRepository,
          IParticipantRepository,
          IParticipantRepository
        >
    with $Provider<IParticipantRepository> {
  ParticipantRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'participantRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$participantRepositoryHash();

  @$internal
  @override
  $ProviderElement<IParticipantRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IParticipantRepository create(Ref ref) {
    return participantRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IParticipantRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IParticipantRepository>(value),
    );
  }
}

String _$participantRepositoryHash() =>
    r'a4c893329f2e472f561ab95bc00201753da3ef90';

@ProviderFor(expenseRepository)
final expenseRepositoryProvider = ExpenseRepositoryProvider._();

final class ExpenseRepositoryProvider
    extends
        $FunctionalProvider<
          IExpenseRepository,
          IExpenseRepository,
          IExpenseRepository
        >
    with $Provider<IExpenseRepository> {
  ExpenseRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expenseRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expenseRepositoryHash();

  @$internal
  @override
  $ProviderElement<IExpenseRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IExpenseRepository create(Ref ref) {
    return expenseRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IExpenseRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IExpenseRepository>(value),
    );
  }
}

String _$expenseRepositoryHash() => r'2876dbf340ae37464f0e149af17dc093ef28b6ac';

@ProviderFor(tagRepository)
final tagRepositoryProvider = TagRepositoryProvider._();

final class TagRepositoryProvider
    extends $FunctionalProvider<ITagRepository, ITagRepository, ITagRepository>
    with $Provider<ITagRepository> {
  TagRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tagRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tagRepositoryHash();

  @$internal
  @override
  $ProviderElement<ITagRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ITagRepository create(Ref ref) {
    return tagRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ITagRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ITagRepository>(value),
    );
  }
}

String _$tagRepositoryHash() => r'9a1c1d6f9c7d73342aef32685763998a1ae69b86';

@ProviderFor(groupMemberRepository)
final groupMemberRepositoryProvider = GroupMemberRepositoryProvider._();

final class GroupMemberRepositoryProvider
    extends
        $FunctionalProvider<
          IGroupMemberRepository,
          IGroupMemberRepository,
          IGroupMemberRepository
        >
    with $Provider<IGroupMemberRepository> {
  GroupMemberRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupMemberRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupMemberRepositoryHash();

  @$internal
  @override
  $ProviderElement<IGroupMemberRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IGroupMemberRepository create(Ref ref) {
    return groupMemberRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IGroupMemberRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IGroupMemberRepository>(value),
    );
  }
}

String _$groupMemberRepositoryHash() =>
    r'9087c5d7cb49bd87ed249198c8a33243f6937777';

@ProviderFor(groupInviteRepository)
final groupInviteRepositoryProvider = GroupInviteRepositoryProvider._();

final class GroupInviteRepositoryProvider
    extends
        $FunctionalProvider<
          IGroupInviteRepository,
          IGroupInviteRepository,
          IGroupInviteRepository
        >
    with $Provider<IGroupInviteRepository> {
  GroupInviteRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupInviteRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupInviteRepositoryHash();

  @$internal
  @override
  $ProviderElement<IGroupInviteRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IGroupInviteRepository create(Ref ref) {
    return groupInviteRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IGroupInviteRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IGroupInviteRepository>(value),
    );
  }
}

String _$groupInviteRepositoryHash() =>
    r'6e819df75291c288ca90445c45b5ff105acd603d';
