// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'onboarding_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Whether online mode is available (Supabase configured via --dart-define).

@ProviderFor(supabaseConfigAvailableOnboarding)
final supabaseConfigAvailableOnboardingProvider =
    SupabaseConfigAvailableOnboardingProvider._();

/// Whether online mode is available (Supabase configured via --dart-define).

final class SupabaseConfigAvailableOnboardingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether online mode is available (Supabase configured via --dart-define).
  SupabaseConfigAvailableOnboardingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supabaseConfigAvailableOnboardingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() =>
      _$supabaseConfigAvailableOnboardingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return supabaseConfigAvailableOnboarding(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$supabaseConfigAvailableOnboardingHash() =>
    r'a30394b5fc0d0cae3a84849c30aff802400fa94d';
