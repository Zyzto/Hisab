// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'delete_my_data_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Service for Delete cloud data: preview and execute deletion on Supabase.

@ProviderFor(deleteMyDataService)
final deleteMyDataServiceProvider = DeleteMyDataServiceProvider._();

/// Service for Delete cloud data: preview and execute deletion on Supabase.

final class DeleteMyDataServiceProvider
    extends
        $FunctionalProvider<
          DeleteMyDataService,
          DeleteMyDataService,
          DeleteMyDataService
        >
    with $Provider<DeleteMyDataService> {
  /// Service for Delete cloud data: preview and execute deletion on Supabase.
  DeleteMyDataServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'deleteMyDataServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$deleteMyDataServiceHash();

  @$internal
  @override
  $ProviderElement<DeleteMyDataService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DeleteMyDataService create(Ref ref) {
    return deleteMyDataService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DeleteMyDataService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DeleteMyDataService>(value),
    );
  }
}

String _$deleteMyDataServiceHash() =>
    r'e388381c2747cd749780e55bc165e5aee809c522';
