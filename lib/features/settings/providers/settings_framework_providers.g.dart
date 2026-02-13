// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_framework_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-owned provider for [SettingsProviders]. Override in main with the result of [initializeHisabSettings].
/// Use this in UI (e.g. settings page) to avoid depending on the framework's provider symbol.

@ProviderFor(hisabSettingsProviders)
final hisabSettingsProvidersProvider = HisabSettingsProvidersProvider._();

/// App-owned provider for [SettingsProviders]. Override in main with the result of [initializeHisabSettings].
/// Use this in UI (e.g. settings page) to avoid depending on the framework's provider symbol.

final class HisabSettingsProvidersProvider
    extends
        $FunctionalProvider<
          SettingsProviders?,
          SettingsProviders?,
          SettingsProviders?
        >
    with $Provider<SettingsProviders?> {
  /// App-owned provider for [SettingsProviders]. Override in main with the result of [initializeHisabSettings].
  /// Use this in UI (e.g. settings page) to avoid depending on the framework's provider symbol.
  HisabSettingsProvidersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hisabSettingsProvidersProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hisabSettingsProvidersHash();

  @$internal
  @override
  $ProviderElement<SettingsProviders?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SettingsProviders? create(Ref ref) {
    return hisabSettingsProviders(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SettingsProviders? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SettingsProviders?>(value),
    );
  }
}

String _$hisabSettingsProvidersHash() =>
    r'dda64f95490bc8e73116dfc4b674c47cd8bfefb0';

@ProviderFor(onboardingCompleted)
final onboardingCompletedProvider = OnboardingCompletedProvider._();

final class OnboardingCompletedProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  OnboardingCompletedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'onboardingCompletedProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$onboardingCompletedHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return onboardingCompleted(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$onboardingCompletedHash() =>
    r'2b1c03b667c5c731cecfaf7616d08e1f6d4be699';

@ProviderFor(localOnly)
final localOnlyProvider = LocalOnlyProvider._();

final class LocalOnlyProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  LocalOnlyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localOnlyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localOnlyHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return localOnly(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$localOnlyHash() => r'593d279a7cb81d4a3cdd1104e8ea7439ced5990c';

/// When true, app uses only local storage. When config is missing, effectively true.

@ProviderFor(effectiveLocalOnly)
final effectiveLocalOnlyProvider = EffectiveLocalOnlyProvider._();

/// When true, app uses only local storage. When config is missing, effectively true.

final class EffectiveLocalOnlyProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// When true, app uses only local storage. When config is missing, effectively true.
  EffectiveLocalOnlyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'effectiveLocalOnlyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$effectiveLocalOnlyHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return effectiveLocalOnly(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$effectiveLocalOnlyHash() =>
    r'094d91f85897f4bcffe7e2dd68d0a1d3eacb390d';

@ProviderFor(receiptOcrEnabled)
final receiptOcrEnabledProvider = ReceiptOcrEnabledProvider._();

final class ReceiptOcrEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  ReceiptOcrEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'receiptOcrEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$receiptOcrEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return receiptOcrEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$receiptOcrEnabledHash() => r'a9af4c8b97e97de65b8f8aa3ff83095818700982';

@ProviderFor(receiptAiEnabled)
final receiptAiEnabledProvider = ReceiptAiEnabledProvider._();

final class ReceiptAiEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  ReceiptAiEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'receiptAiEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$receiptAiEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return receiptAiEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$receiptAiEnabledHash() => r'9033b46e2c15fa5467a119849e27b7b6b5e71d8b';

@ProviderFor(receiptAiProvider)
final receiptAiProviderProvider = ReceiptAiProviderProvider._();

final class ReceiptAiProviderProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  ReceiptAiProviderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'receiptAiProviderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$receiptAiProviderHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return receiptAiProvider(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$receiptAiProviderHash() => r'4ad2f49840d7266e15ccceef59b606287e3f81b7';

@ProviderFor(geminiApiKey)
final geminiApiKeyProvider = GeminiApiKeyProvider._();

final class GeminiApiKeyProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  GeminiApiKeyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'geminiApiKeyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$geminiApiKeyHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return geminiApiKey(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$geminiApiKeyHash() => r'197314ed56e2a5ea5cf8572f6bf5ac232aa63644';

@ProviderFor(openaiApiKey)
final openaiApiKeyProvider = OpenaiApiKeyProvider._();

final class OpenaiApiKeyProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  OpenaiApiKeyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'openaiApiKeyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$openaiApiKeyHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return openaiApiKey(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$openaiApiKeyHash() => r'9e80deccbe891639df1748997134aff5cd3213a9';

@ProviderFor(themeMode)
final themeModeProvider = ThemeModeProvider._();

final class ThemeModeProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  ThemeModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return themeMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$themeModeHash() => r'667cf4a837745c594e2c5a0d7647113817220a52';

@ProviderFor(themeColor)
final themeColorProvider = ThemeColorProvider._();

final class ThemeColorProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  ThemeColorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeColorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeColorHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return themeColor(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$themeColorHash() => r'd8de53787da6f4df3d07c8e9a820442f47544809';

@ProviderFor(language)
final languageProvider = LanguageProvider._();

final class LanguageProvider extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  LanguageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'languageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$languageHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return language(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$languageHash() => r'05ad185bfb07d659823019923fe5b9475dc962b7';

@ProviderFor(favoriteCurrencies)
final favoriteCurrenciesProvider = FavoriteCurrenciesProvider._();

final class FavoriteCurrenciesProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  FavoriteCurrenciesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'favoriteCurrenciesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$favoriteCurrenciesHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return favoriteCurrencies(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$favoriteCurrenciesHash() =>
    r'9306918f4bdde5c7aaa548a24133f65222b74e67';

@ProviderFor(fontSizeScale)
final fontSizeScaleProvider = FontSizeScaleProvider._();

final class FontSizeScaleProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  FontSizeScaleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fontSizeScaleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fontSizeScaleHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return fontSizeScale(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$fontSizeScaleHash() => r'8a20204a46a361746e07cba5a1f0c6c1b3187e6f';

@ProviderFor(authUserProfile)
final authUserProfileProvider = AuthUserProfileProvider._();

final class AuthUserProfileProvider
    extends
        $FunctionalProvider<
          AsyncValue<AuthUserProfile?>,
          AuthUserProfile?,
          FutureOr<AuthUserProfile?>
        >
    with $FutureModifier<AuthUserProfile?>, $FutureProvider<AuthUserProfile?> {
  AuthUserProfileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authUserProfileProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authUserProfileHash();

  @$internal
  @override
  $FutureProviderElement<AuthUserProfile?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AuthUserProfile?> create(Ref ref) {
    return authUserProfile(ref);
  }
}

String _$authUserProfileHash() => r'62c592fd7f30df515f6cdb134ae7adc1f8ca29e2';

@ProviderFor(telemetryEnabled)
final telemetryEnabledProvider = TelemetryEnabledProvider._();

final class TelemetryEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  TelemetryEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'telemetryEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$telemetryEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return telemetryEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$telemetryEnabledHash() => r'a6a0a33d9a26855661d54d6f71e68d5ec7cab33c';
