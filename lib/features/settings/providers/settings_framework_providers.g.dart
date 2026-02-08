// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_framework_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(localOnly)
const localOnlyProvider = LocalOnlyProvider._();

final class LocalOnlyProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  const LocalOnlyProvider._()
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
