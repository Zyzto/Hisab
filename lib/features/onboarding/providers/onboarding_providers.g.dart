// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// When true, online mode is available (Auth0 and Convex both configured).

@ProviderFor(auth0ConfigAvailable)
final auth0ConfigAvailableProvider = Auth0ConfigAvailableProvider._();

/// When true, online mode is available (Auth0 and Convex both configured).

final class Auth0ConfigAvailableProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// When true, online mode is available (Auth0 and Convex both configured).
  Auth0ConfigAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'auth0ConfigAvailableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$auth0ConfigAvailableHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return auth0ConfigAvailable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$auth0ConfigAvailableHash() =>
    r'382e3a90d8cf95e13843c5827b1ccee3f055df0b';
