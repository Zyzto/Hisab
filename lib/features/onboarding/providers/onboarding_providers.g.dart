// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether this build has a cloud backend, and so can offer online mode.

@ProviderFor(cloudAvailableOnboarding)
final cloudAvailableOnboardingProvider = CloudAvailableOnboardingProvider._();

/// Whether this build has a cloud backend, and so can offer online mode.

final class CloudAvailableOnboardingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether this build has a cloud backend, and so can offer online mode.
  CloudAvailableOnboardingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cloudAvailableOnboardingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cloudAvailableOnboardingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return cloudAvailableOnboarding(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$cloudAvailableOnboardingHash() =>
    r'a6f104c98f78094888c8e9f6bdd6ccce3fa519c5';
