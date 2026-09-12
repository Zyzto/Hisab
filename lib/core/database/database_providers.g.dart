// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The local SQLite database. It is initialized in main.dart and overridden
/// in the root ProviderScope.

@ProviderFor(powerSyncDatabase)
final powerSyncDatabaseProvider = PowerSyncDatabaseProvider._();

/// The local SQLite database. It is initialized in main.dart and overridden
/// in the root ProviderScope.

final class PowerSyncDatabaseProvider
    extends
        $FunctionalProvider<
          PowerSyncDatabase,
          PowerSyncDatabase,
          PowerSyncDatabase
        >
    with $Provider<PowerSyncDatabase> {
  /// The local SQLite database. It is initialized in main.dart and overridden
  /// in the root ProviderScope.
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
