// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The PowerSync database instance. Always available (local SQLite).
/// Initialized in main.dart and overridden in ProviderScope.

@ProviderFor(powerSyncDatabase)
final powerSyncDatabaseProvider = PowerSyncDatabaseProvider._();

/// The PowerSync database instance. Always available (local SQLite).
/// Initialized in main.dart and overridden in ProviderScope.

final class PowerSyncDatabaseProvider
    extends
        $FunctionalProvider<
          PowerSyncDatabase,
          PowerSyncDatabase,
          PowerSyncDatabase
        >
    with $Provider<PowerSyncDatabase> {
  /// The PowerSync database instance. Always available (local SQLite).
  /// Initialized in main.dart and overridden in ProviderScope.
  PowerSyncDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'powerSyncDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$powerSyncDatabaseHash();

  @$internal
  @override
  $ProviderElement<PowerSyncDatabase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PowerSyncDatabase create(Ref ref) {
    return powerSyncDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PowerSyncDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PowerSyncDatabase>(value),
    );
  }
}

String _$powerSyncDatabaseHash() => r'052a1c8d9f8f94272f5b9cb11fa402f2fcca1baa';

@ProviderFor(DataSyncService)
final dataSyncServiceProvider = DataSyncServiceProvider._();

final class DataSyncServiceProvider
    extends $NotifierProvider<DataSyncService, void> {
  DataSyncServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dataSyncServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dataSyncServiceHash();

  @$internal
  @override
  DataSyncService create() => DataSyncService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$dataSyncServiceHash() => r'9447fd3137ef0b493cd6d9492abf510584447076';

abstract class _$DataSyncService extends $Notifier<void> {
  void build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<void, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<void, void>,
              void,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
