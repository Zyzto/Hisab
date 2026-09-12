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

String _$groupRepositoryHash() => r'670c6004b1c4d9c183e4ca7d9bcfb5b2ef22171d';

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
    r'd47454f3d9dda2806ea30afa42166c4f8d0f02dd';

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

String _$expenseRepositoryHash() => r'9d052440579807e46645bf3a7064f250e6e267c6';

@ProviderFor(householdBalanceReassignmentRepository)
final householdBalanceReassignmentRepositoryProvider =
    HouseholdBalanceReassignmentRepositoryProvider._();

final class HouseholdBalanceReassignmentRepositoryProvider
    extends
        $FunctionalProvider<
          IHouseholdBalanceReassignmentRepository,
          IHouseholdBalanceReassignmentRepository,
          IHouseholdBalanceReassignmentRepository
        >
    with $Provider<IHouseholdBalanceReassignmentRepository> {
  HouseholdBalanceReassignmentRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'householdBalanceReassignmentRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$householdBalanceReassignmentRepositoryHash();

  @$internal
  @override
  $ProviderElement<IHouseholdBalanceReassignmentRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  IHouseholdBalanceReassignmentRepository create(Ref ref) {
    return householdBalanceReassignmentRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IHouseholdBalanceReassignmentRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<IHouseholdBalanceReassignmentRepository>(value),
    );
  }
}

String _$householdBalanceReassignmentRepositoryHash() =>
    r'4e25f4aaa7b02371f1744270777e3c2663b9452c';

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

String _$tagRepositoryHash() => r'7d5fdea11a11a29426590de5a8245f77e1b135b8';

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
    r'18ac35a3eb5d160f186506ce10d19738502133bb';
