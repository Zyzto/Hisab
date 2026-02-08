// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_framework_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

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
