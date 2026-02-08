// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dao_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(groupDao)
const groupDaoProvider = GroupDaoProvider._();

final class GroupDaoProvider
    extends $FunctionalProvider<GroupDao, GroupDao, GroupDao>
    with $Provider<GroupDao> {
  const GroupDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupDaoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupDaoHash();

  @$internal
  @override
  $ProviderElement<GroupDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GroupDao create(Ref ref) {
    return groupDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GroupDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GroupDao>(value),
    );
  }
}

String _$groupDaoHash() => r'619163864aea3c776eaac282383f5cc9c7599b89';

@ProviderFor(participantDao)
const participantDaoProvider = ParticipantDaoProvider._();

final class ParticipantDaoProvider
    extends $FunctionalProvider<ParticipantDao, ParticipantDao, ParticipantDao>
    with $Provider<ParticipantDao> {
  const ParticipantDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'participantDaoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$participantDaoHash();

  @$internal
  @override
  $ProviderElement<ParticipantDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ParticipantDao create(Ref ref) {
    return participantDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ParticipantDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ParticipantDao>(value),
    );
  }
}

String _$participantDaoHash() => r'1b4fd4cf8c40ec6e75db4f5bf6c77ad910c3a4b3';

@ProviderFor(expenseDao)
const expenseDaoProvider = ExpenseDaoProvider._();

final class ExpenseDaoProvider
    extends $FunctionalProvider<ExpenseDao, ExpenseDao, ExpenseDao>
    with $Provider<ExpenseDao> {
  const ExpenseDaoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'expenseDaoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$expenseDaoHash();

  @$internal
  @override
  $ProviderElement<ExpenseDao> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ExpenseDao create(Ref ref) {
    return expenseDao(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ExpenseDao value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ExpenseDao>(value),
    );
  }
}

String _$expenseDaoHash() => r'cb5ed281fb22cfd9d3d90f8b3d3c7116b7b6eb30';
