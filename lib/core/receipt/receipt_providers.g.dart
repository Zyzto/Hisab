// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receipt_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reusable TextRecognizer for receipt OCR. Cached per provider lifetime.
/// Returns null on web (ML Kit not supported). Automatically disposed when provider is disposed.

@ProviderFor(textRecognizer)
final textRecognizerProvider = TextRecognizerProvider._();

/// Reusable TextRecognizer for receipt OCR. Cached per provider lifetime.
/// Returns null on web (ML Kit not supported). Automatically disposed when provider is disposed.

final class TextRecognizerProvider
    extends
        $FunctionalProvider<TextRecognizer?, TextRecognizer?, TextRecognizer?>
    with $Provider<TextRecognizer?> {
  /// Reusable TextRecognizer for receipt OCR. Cached per provider lifetime.
  /// Returns null on web (ML Kit not supported). Automatically disposed when provider is disposed.
  TextRecognizerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'textRecognizerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$textRecognizerHash();

  @$internal
  @override
  $ProviderElement<TextRecognizer?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TextRecognizer? create(Ref ref) {
    return textRecognizer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TextRecognizer? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TextRecognizer?>(value),
    );
  }
}

String _$textRecognizerHash() => r'd801ba62419e0dc671e0411248d29da80b698e7d';
