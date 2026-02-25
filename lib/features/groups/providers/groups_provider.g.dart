// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'groups_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(groups)
final groupsProvider = GroupsProvider._();

final class GroupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Group>>,
          List<Group>,
          Stream<List<Group>>
        >
    with $FutureModifier<List<Group>>, $StreamProvider<List<Group>> {
  GroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'groupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$groupsHash();

  @$internal
  @override
  $StreamProviderElement<List<Group>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Group>> create(Ref ref) {
    return groups(ref);
  }
}

String _$groupsHash() => r'48fe58e6c4faa27f5cbf2813c95ad887b210acfc';

@ProviderFor(archivedGroups)
final archivedGroupsProvider = ArchivedGroupsProvider._();

final class ArchivedGroupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Group>>,
          List<Group>,
          Stream<List<Group>>
        >
    with $FutureModifier<List<Group>>, $StreamProvider<List<Group>> {
  ArchivedGroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'archivedGroupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$archivedGroupsHash();

  @$internal
  @override
  $StreamProviderElement<List<Group>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Group>> create(Ref ref) {
    return archivedGroups(ref);
  }
}

String _$archivedGroupsHash() => r'7c8ccc56915d5b508095faca65f4239477ccc4cb';

@ProviderFor(locallyArchivedGroups)
final locallyArchivedGroupsProvider = LocallyArchivedGroupsProvider._();

final class LocallyArchivedGroupsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Group>>,
          List<Group>,
          Stream<List<Group>>
        >
    with $FutureModifier<List<Group>>, $StreamProvider<List<Group>> {
  LocallyArchivedGroupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locallyArchivedGroupsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locallyArchivedGroupsHash();

  @$internal
  @override
  $StreamProviderElement<List<Group>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Group>> create(Ref ref) {
    return locallyArchivedGroups(ref);
  }
}

String _$locallyArchivedGroupsHash() =>
    r'fc0c3daf028580a15a4471eed0be8c002419b240';

@ProviderFor(locallyArchivedGroupIds)
final locallyArchivedGroupIdsProvider = LocallyArchivedGroupIdsProvider._();

final class LocallyArchivedGroupIdsProvider
    extends
        $FunctionalProvider<
          AsyncValue<Set<String>>,
          Set<String>,
          Stream<Set<String>>
        >
    with $FutureModifier<Set<String>>, $StreamProvider<Set<String>> {
  LocallyArchivedGroupIdsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'locallyArchivedGroupIdsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$locallyArchivedGroupIdsHash();

  @$internal
  @override
  $StreamProviderElement<Set<String>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Set<String>> create(Ref ref) {
    return locallyArchivedGroupIds(ref);
  }
}

String _$locallyArchivedGroupIdsHash() =>
    r'fa92c92d006bc461b11e0adaf49ecfab0f21e962';

@ProviderFor(futureGroup)
final futureGroupProvider = FutureGroupFamily._();

final class FutureGroupProvider
    extends $FunctionalProvider<AsyncValue<Group?>, Group?, FutureOr<Group?>>
    with $FutureModifier<Group?>, $FutureProvider<Group?> {
  FutureGroupProvider._({
    required FutureGroupFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'futureGroupProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$futureGroupHash();

  @override
  String toString() {
    return r'futureGroupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Group?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Group?> create(Ref ref) {
    final argument = this.argument as String;
    return futureGroup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FutureGroupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$futureGroupHash() => r'5a6ff2863b2b5e166622f6754231de992cccab5c';

final class FutureGroupFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Group?>, String> {
  FutureGroupFamily._()
    : super(
        retry: null,
        name: r'futureGroupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FutureGroupProvider call(String groupId) =>
      FutureGroupProvider._(argument: groupId, from: this);

  @override
  String toString() => r'futureGroupProvider';
}

@ProviderFor(expensesByGroup)
final expensesByGroupProvider = ExpensesByGroupFamily._();

final class ExpensesByGroupProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Expense>>,
          List<Expense>,
          Stream<List<Expense>>
        >
    with $FutureModifier<List<Expense>>, $StreamProvider<List<Expense>> {
  ExpensesByGroupProvider._({
    required ExpensesByGroupFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'expensesByGroupProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$expensesByGroupHash();

  @override
  String toString() {
    return r'expensesByGroupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Expense>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Expense>> create(Ref ref) {
    final argument = this.argument as String;
    return expensesByGroup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ExpensesByGroupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$expensesByGroupHash() => r'394e975da5b49ebcea458bdd6b91db9a5a7cb55c';

final class ExpensesByGroupFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Expense>>, String> {
  ExpensesByGroupFamily._()
    : super(
        retry: null,
        name: r'expensesByGroupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExpensesByGroupProvider call(String groupId) =>
      ExpensesByGroupProvider._(argument: groupId, from: this);

  @override
  String toString() => r'expensesByGroupProvider';
}

@ProviderFor(futureExpense)
final futureExpenseProvider = FutureExpenseFamily._();

final class FutureExpenseProvider
    extends
        $FunctionalProvider<AsyncValue<Expense?>, Expense?, FutureOr<Expense?>>
    with $FutureModifier<Expense?>, $FutureProvider<Expense?> {
  FutureExpenseProvider._({
    required FutureExpenseFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'futureExpenseProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$futureExpenseHash();

  @override
  String toString() {
    return r'futureExpenseProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Expense?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Expense?> create(Ref ref) {
    final argument = this.argument as String;
    return futureExpense(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is FutureExpenseProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$futureExpenseHash() => r'ec4d4fd8d1c104f65620a4a1c3802e3b1d9ffce4';

final class FutureExpenseFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Expense?>, String> {
  FutureExpenseFamily._()
    : super(
        retry: null,
        name: r'futureExpenseProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FutureExpenseProvider call(String expenseId) =>
      FutureExpenseProvider._(argument: expenseId, from: this);

  @override
  String toString() => r'futureExpenseProvider';
}

@ProviderFor(participantsByGroup)
final participantsByGroupProvider = ParticipantsByGroupFamily._();

final class ParticipantsByGroupProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Participant>>,
          List<Participant>,
          Stream<List<Participant>>
        >
    with
        $FutureModifier<List<Participant>>,
        $StreamProvider<List<Participant>> {
  ParticipantsByGroupProvider._({
    required ParticipantsByGroupFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'participantsByGroupProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$participantsByGroupHash();

  @override
  String toString() {
    return r'participantsByGroupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Participant>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Participant>> create(Ref ref) {
    final argument = this.argument as String;
    return participantsByGroup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ParticipantsByGroupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$participantsByGroupHash() =>
    r'84d5dce47426f47d5d9d314f2f374628b9d2de36';

final class ParticipantsByGroupFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Participant>>, String> {
  ParticipantsByGroupFamily._()
    : super(
        retry: null,
        name: r'participantsByGroupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ParticipantsByGroupProvider call(String groupId) =>
      ParticipantsByGroupProvider._(argument: groupId, from: this);

  @override
  String toString() => r'participantsByGroupProvider';
}

/// Active participants only (left_at == null). Use for new expenses and balance
/// so left/archived members do not count towards splits or settlements.

@ProviderFor(activeParticipantsByGroup)
final activeParticipantsByGroupProvider = ActiveParticipantsByGroupFamily._();

/// Active participants only (left_at == null). Use for new expenses and balance
/// so left/archived members do not count towards splits or settlements.

final class ActiveParticipantsByGroupProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Participant>>,
          List<Participant>,
          Stream<List<Participant>>
        >
    with
        $FutureModifier<List<Participant>>,
        $StreamProvider<List<Participant>> {
  /// Active participants only (left_at == null). Use for new expenses and balance
  /// so left/archived members do not count towards splits or settlements.
  ActiveParticipantsByGroupProvider._({
    required ActiveParticipantsByGroupFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activeParticipantsByGroupProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activeParticipantsByGroupHash();

  @override
  String toString() {
    return r'activeParticipantsByGroupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Participant>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Participant>> create(Ref ref) {
    final argument = this.argument as String;
    return activeParticipantsByGroup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveParticipantsByGroupProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activeParticipantsByGroupHash() =>
    r'0e8ecf6d01b95254d4add850b9a2068059306547';

/// Active participants only (left_at == null). Use for new expenses and balance
/// so left/archived members do not count towards splits or settlements.

final class ActiveParticipantsByGroupFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Participant>>, String> {
  ActiveParticipantsByGroupFamily._()
    : super(
        retry: null,
        name: r'activeParticipantsByGroupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Active participants only (left_at == null). Use for new expenses and balance
  /// so left/archived members do not count towards splits or settlements.

  ActiveParticipantsByGroupProvider call(String groupId) =>
      ActiveParticipantsByGroupProvider._(argument: groupId, from: this);

  @override
  String toString() => r'activeParticipantsByGroupProvider';
}

@ProviderFor(tagsByGroup)
final tagsByGroupProvider = TagsByGroupFamily._();

final class TagsByGroupProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ExpenseTag>>,
          List<ExpenseTag>,
          Stream<List<ExpenseTag>>
        >
    with $FutureModifier<List<ExpenseTag>>, $StreamProvider<List<ExpenseTag>> {
  TagsByGroupProvider._({
    required TagsByGroupFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'tagsByGroupProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$tagsByGroupHash();

  @override
  String toString() {
    return r'tagsByGroupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<ExpenseTag>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<ExpenseTag>> create(Ref ref) {
    final argument = this.argument as String;
    return tagsByGroup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is TagsByGroupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$tagsByGroupHash() => r'98cef034537c09982ab2e3ebf2b3c6ce4b56dc42';

final class TagsByGroupFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<ExpenseTag>>, String> {
  TagsByGroupFamily._()
    : super(
        retry: null,
        name: r'tagsByGroupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  TagsByGroupProvider call(String groupId) =>
      TagsByGroupProvider._(argument: groupId, from: this);

  @override
  String toString() => r'tagsByGroupProvider';
}
