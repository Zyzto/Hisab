// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'balance_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Computed provider for group balances and settlements. Caches computation
/// and recomputes when group, participants, or expenses change.

@ProviderFor(groupBalance)
final groupBalanceProvider = GroupBalanceFamily._();

/// Computed provider for group balances and settlements. Caches computation
/// and recomputes when group, participants, or expenses change.

final class GroupBalanceProvider
    extends
        $FunctionalProvider<
          AsyncValue<GroupBalanceResult?>,
          AsyncValue<GroupBalanceResult?>,
          AsyncValue<GroupBalanceResult?>
        >
    with $Provider<AsyncValue<GroupBalanceResult?>> {
  /// Computed provider for group balances and settlements. Caches computation
  /// and recomputes when group, participants, or expenses change.
  GroupBalanceProvider._({
    required GroupBalanceFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'groupBalanceProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$groupBalanceHash();

  @override
  String toString() {
    return r'groupBalanceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AsyncValue<GroupBalanceResult?>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<GroupBalanceResult?> create(Ref ref) {
    final argument = this.argument as String;
    return groupBalance(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<GroupBalanceResult?> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<GroupBalanceResult?>>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GroupBalanceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$groupBalanceHash() => r'66828f609c2591d125635fe39e5730a36c9b4434';

/// Computed provider for group balances and settlements. Caches computation
/// and recomputes when group, participants, or expenses change.

final class GroupBalanceFamily extends $Family
    with $FunctionalFamilyOverride<AsyncValue<GroupBalanceResult?>, String> {
  GroupBalanceFamily._()
    : super(
        retry: null,
        name: r'groupBalanceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Computed provider for group balances and settlements. Caches computation
  /// and recomputes when group, participants, or expenses change.

  GroupBalanceProvider call(String groupId) =>
      GroupBalanceProvider._(argument: groupId, from: this);

  @override
  String toString() => r'groupBalanceProvider';
}
