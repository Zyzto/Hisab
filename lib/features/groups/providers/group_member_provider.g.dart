// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_member_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(myMemberInGroup)
final myMemberInGroupProvider = MyMemberInGroupFamily._();

final class MyMemberInGroupProvider
    extends
        $FunctionalProvider<
          AsyncValue<GroupMember?>,
          GroupMember?,
          Stream<GroupMember?>
        >
    with $FutureModifier<GroupMember?>, $StreamProvider<GroupMember?> {
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
  $StreamProviderElement<GroupMember?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<GroupMember?> create(Ref ref) {
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

String _$myMemberInGroupHash() => r'537094b4d8eadf5a6551995e1049828619fa3134';

final class MyMemberInGroupFamily extends $Family
    with $FunctionalFamilyOverride<Stream<GroupMember?>, String> {
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

@ProviderFor(myRoleInGroup)
final myRoleInGroupProvider = MyRoleInGroupFamily._();

final class MyRoleInGroupProvider
    extends
        $FunctionalProvider<
          AsyncValue<GroupRole?>,
          GroupRole?,
          Stream<GroupRole?>
        >
    with $FutureModifier<GroupRole?>, $StreamProvider<GroupRole?> {
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
  $StreamProviderElement<GroupRole?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<GroupRole?> create(Ref ref) {
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

String _$myRoleInGroupHash() => r'9abfa4e248389ced029bb623a87ef63eb5532e17';

final class MyRoleInGroupFamily extends $Family
    with $FunctionalFamilyOverride<Stream<GroupRole?>, String> {
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
