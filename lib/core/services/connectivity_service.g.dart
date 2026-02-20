// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'connectivity_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether the device currently has network connectivity.
/// In Local-Only mode this still reflects real connectivity
/// but is unused by repositories.

@ProviderFor(ConnectivityNotifier)
final connectivityProvider = ConnectivityNotifierProvider._();

/// Whether the device currently has network connectivity.
/// In Local-Only mode this still reflects real connectivity
/// but is unused by repositories.
final class ConnectivityNotifierProvider
    extends $NotifierProvider<ConnectivityNotifier, bool> {
  /// Whether the device currently has network connectivity.
  /// In Local-Only mode this still reflects real connectivity
  /// but is unused by repositories.
  ConnectivityNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectivityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectivityNotifierHash();

  @$internal
  @override
  ConnectivityNotifier create() => ConnectivityNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$connectivityNotifierHash() =>
    r'75c5d2bdad09a86e9c10b71e2491bfd633a7b2b8';

/// Whether the device currently has network connectivity.
/// In Local-Only mode this still reflects real connectivity
/// but is unused by repositories.

abstract class _$ConnectivityNotifier extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Whether the app can currently reach Supabase for writes.
/// Returns `true` if:
///   - The user is in Local-Only mode (no restrictions), OR
///   - The user is in Online mode AND has network connectivity.

@ProviderFor(canWriteOnline)
final canWriteOnlineProvider = CanWriteOnlineProvider._();

/// Whether the app can currently reach Supabase for writes.
/// Returns `true` if:
///   - The user is in Local-Only mode (no restrictions), OR
///   - The user is in Online mode AND has network connectivity.

final class CanWriteOnlineProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether the app can currently reach Supabase for writes.
  /// Returns `true` if:
  ///   - The user is in Local-Only mode (no restrictions), OR
  ///   - The user is in Online mode AND has network connectivity.
  CanWriteOnlineProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'canWriteOnlineProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$canWriteOnlineHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return canWriteOnline(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$canWriteOnlineHash() => r'363e760d94e9834c579cbebc7603ad8cd4e4d8dd';

/// High-level sync status for the UI status icon.

@ProviderFor(SyncStatusNotifier)
final syncStatusProvider = SyncStatusNotifierProvider._();

/// High-level sync status for the UI status icon.
final class SyncStatusNotifierProvider
    extends $NotifierProvider<SyncStatusNotifier, SyncStatus> {
  /// High-level sync status for the UI status icon.
  SyncStatusNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncStatusProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncStatusNotifierHash();

  @$internal
  @override
  SyncStatusNotifier create() => SyncStatusNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncStatus>(value),
    );
  }
}

String _$syncStatusNotifierHash() =>
    r'f97f094c92e0b5e5f6e098b84758400ab8785ac8';

/// High-level sync status for the UI status icon.

abstract class _$SyncStatusNotifier extends $Notifier<SyncStatus> {
  SyncStatus build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<SyncStatus, SyncStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SyncStatus, SyncStatus>,
              SyncStatus,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}

/// Sync status shown in UI; respects [debugSyncStatusOverrideProvider] when set.

@ProviderFor(syncStatusForDisplay)
final syncStatusForDisplayProvider = SyncStatusForDisplayProvider._();

/// Sync status shown in UI; respects [debugSyncStatusOverrideProvider] when set.

final class SyncStatusForDisplayProvider
    extends $FunctionalProvider<SyncStatus, SyncStatus, SyncStatus>
    with $Provider<SyncStatus> {
  /// Sync status shown in UI; respects [debugSyncStatusOverrideProvider] when set.
  SyncStatusForDisplayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'syncStatusForDisplayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$syncStatusForDisplayHash();

  @$internal
  @override
  $ProviderElement<SyncStatus> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SyncStatus create(Ref ref) {
    return syncStatusForDisplay(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SyncStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SyncStatus>(value),
    );
  }
}

String _$syncStatusForDisplayHash() =>
    r'c6c4a6284cc9574d745325ccd8d44dcf2bee7f9d';
