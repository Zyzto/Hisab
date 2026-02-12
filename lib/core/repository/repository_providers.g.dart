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

String _$groupRepositoryHash() => r'f650776cc69524f79df964d0eb33955af109d09d';

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
    r'f0ed386a6db8fa4b2f5ed412b57de39956927f82';

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

String _$expenseRepositoryHash() => r'9663e8f59a506434555e5747e92fe2f339cb48c4';

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

String _$tagRepositoryHash() => r'3f7cac86008992fc667f0523f07baef084a2e8f7';
