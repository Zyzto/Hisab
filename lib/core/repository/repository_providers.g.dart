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

String _$groupRepositoryHash() => r'c1f624b861b3fdb3dcaa7294e5e5ad26b642b1ba';

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
    r'1c974df30ef9e8dde9cb0a9bb98170dcfa70db66';

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

String _$expenseRepositoryHash() => r'e99ea648c300909d6a894fa816223bcebdbe63c0';

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

String _$tagRepositoryHash() => r'edc8c1ed19bbf6d6f6f489ad9d6530618cb703b0';
