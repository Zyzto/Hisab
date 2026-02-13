// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier that triggers GoRouter refresh when locale changes.
/// Ensures navigation labels and all visible content update in realtime.

@ProviderFor(localeRefreshNotifier)
final localeRefreshProvider = LocaleRefreshNotifierProvider._();

/// Notifier that triggers GoRouter refresh when locale changes.
/// Ensures navigation labels and all visible content update in realtime.

final class LocaleRefreshNotifierProvider
    extends
        $FunctionalProvider<
          ValueNotifier<String>,
          ValueNotifier<String>,
          ValueNotifier<String>
        >
    with $Provider<ValueNotifier<String>> {
  /// Notifier that triggers GoRouter refresh when locale changes.
  /// Ensures navigation labels and all visible content update in realtime.
  LocaleRefreshNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localeRefreshProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localeRefreshNotifierHash();

  @$internal
  @override
  $ProviderElement<ValueNotifier<String>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ValueNotifier<String> create(Ref ref) {
    return localeRefreshNotifier(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ValueNotifier<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ValueNotifier<String>>(value),
    );
  }
}

String _$localeRefreshNotifierHash() =>
    r'424857f00b7cebc42d68a206a95113dfedc0d5ca';

@ProviderFor(router)
final routerProvider = RouterProvider._();

final class RouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  RouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'routerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$routerHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return router(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$routerHash() => r'd02306eb903bd641b8e6a46d33ad30385d294709';
