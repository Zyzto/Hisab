// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_member_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(myRoleInGroup)
final myRoleInGroupProvider = MyRoleInGroupFamily._();

final class MyRoleInGroupProvider
    extends
        $FunctionalProvider<
          AsyncValue<GroupRole?>,
          GroupRole?,
          FutureOr<GroupRole?>
        >
    with $FutureModifier<GroupRole?>, $FutureProvider<GroupRole?> {
  MyRoleInGroupProvider._({
    required MyRoleInGroupFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'myRoleInGroupProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$myRoleInGroupHash();

  @override
  String toString() {
    return r'myRoleInGroupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<GroupRole?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<GroupRole?> create(Ref ref) {
    final argument = this.argument as String;
    return myRoleInGroup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MyRoleInGroupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$myRoleInGroupHash() => r'fb1c5e51464868f2f70009a89546d44b60b04633';

final class MyRoleInGroupFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<GroupRole?>, String> {
  MyRoleInGroupFamily._()
    : super(
        retry: null,
        name: r'myRoleInGroupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MyRoleInGroupProvider call(String groupId) =>
      MyRoleInGroupProvider._(argument: groupId, from: this);

  @override
  String toString() => r'myRoleInGroupProvider';
}

@ProviderFor(myMemberInGroup)
final myMemberInGroupProvider = MyMemberInGroupFamily._();

final class MyMemberInGroupProvider
    extends
        $FunctionalProvider<
          AsyncValue<GroupMember?>,
          GroupMember?,
          FutureOr<GroupMember?>
        >
    with $FutureModifier<GroupMember?>, $FutureProvider<GroupMember?> {
  MyMemberInGroupProvider._({
    required MyMemberInGroupFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'myMemberInGroupProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$myMemberInGroupHash();

  @override
  String toString() {
    return r'myMemberInGroupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<GroupMember?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<GroupMember?> create(Ref ref) {
    final argument = this.argument as String;
    return myMemberInGroup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MyMemberInGroupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$myMemberInGroupHash() => r'a39d25c54f3218ad3865e33fe178cc7f9262eb65';

final class MyMemberInGroupFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<GroupMember?>, String> {
  MyMemberInGroupFamily._()
    : super(
        retry: null,
        name: r'myMemberInGroupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MyMemberInGroupProvider call(String groupId) =>
      MyMemberInGroupProvider._(argument: groupId, from: this);

  @override
  String toString() => r'myMemberInGroupProvider';
}

@ProviderFor(membersByGroup)
final membersByGroupProvider = MembersByGroupFamily._();

final class MembersByGroupProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<GroupMember>>,
          List<GroupMember>,
          Stream<List<GroupMember>>
        >
    with
        $FutureModifier<List<GroupMember>>,
        $StreamProvider<List<GroupMember>> {
  MembersByGroupProvider._({
    required MembersByGroupFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'membersByGroupProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$membersByGroupHash();

  @override
  String toString() {
    return r'membersByGroupProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<GroupMember>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<GroupMember>> create(Ref ref) {
    final argument = this.argument as String;
    return membersByGroup(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MembersByGroupProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$membersByGroupHash() => r'f521395a239d04615748ebb7de122e61a3c1dda0';

final class MembersByGroupFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<GroupMember>>, String> {
  MembersByGroupFamily._()
    : super(
        retry: null,
        name: r'membersByGroupProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MembersByGroupProvider call(String groupId) =>
      MembersByGroupProvider._(argument: groupId, from: this);

  @override
  String toString() => r'membersByGroupProvider';
}
