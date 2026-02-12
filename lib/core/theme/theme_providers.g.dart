// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Theme data provider. Rebuilds only when themeMode, themeColor, or fontSizeScale change.

@ProviderFor(appThemes)
final appThemesProvider = AppThemesProvider._();

/// Theme data provider. Rebuilds only when themeMode, themeColor, or fontSizeScale change.

final class AppThemesProvider
    extends $FunctionalProvider<AppThemes, AppThemes, AppThemes>
    with $Provider<AppThemes> {
  /// Theme data provider. Rebuilds only when themeMode, themeColor, or fontSizeScale change.
  AppThemesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appThemesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appThemesHash();

  @$internal
  @override
  $ProviderElement<AppThemes> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppThemes create(Ref ref) {
    return appThemes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppThemes value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppThemes>(value),
    );
  }
}

String _$appThemesHash() => r'992c8a25b528a72636ab86fb7451cfc9821a2f73';

/// ThemeMode for MaterialApp. Separate so locale changes don't trigger theme rebuild.

@ProviderFor(appThemeMode)
final appThemeModeProvider = AppThemeModeProvider._();

/// ThemeMode for MaterialApp. Separate so locale changes don't trigger theme rebuild.

final class AppThemeModeProvider
    extends $FunctionalProvider<ThemeMode, ThemeMode, ThemeMode>
    with $Provider<ThemeMode> {
  /// ThemeMode for MaterialApp. Separate so locale changes don't trigger theme rebuild.
  AppThemeModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appThemeModeProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appThemeModeHash();

  @$internal
  @override
  $ProviderElement<ThemeMode> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeMode create(Ref ref) {
    return appThemeMode(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$appThemeModeHash() => r'f435a34ab857188f650d303b8bbd5422cf69b44e';
