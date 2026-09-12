// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_currency_rate_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Currency conversion is intentionally unavailable in the offline build.
/// Stored display-currency preferences remain intact for future overlays.

@ProviderFor(displayCurrencyRate)
final displayCurrencyRateProvider = DisplayCurrencyRateFamily._();

/// Currency conversion is intentionally unavailable in the offline build.
/// Stored display-currency preferences remain intact for future overlays.

final class DisplayCurrencyRateProvider
    extends $FunctionalProvider<AsyncValue<double?>, double?, FutureOr<double?>>
    with $FutureModifier<double?>, $FutureProvider<double?> {
  /// Currency conversion is intentionally unavailable in the offline build.
  /// Stored display-currency preferences remain intact for future overlays.
  DisplayCurrencyRateProvider._({
    required DisplayCurrencyRateFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'displayCurrencyRateProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$displayCurrencyRateHash();

  @override
  String toString() {
    return r'displayCurrencyRateProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<double?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<double?> create(Ref ref) {
    final argument = this.argument as String;
    return displayCurrencyRate(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DisplayCurrencyRateProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$displayCurrencyRateHash() =>
    r'1597d4b415e035f0a502e601eb0d7fa3a45e07ad';

/// Currency conversion is intentionally unavailable in the offline build.
/// Stored display-currency preferences remain intact for future overlays.

final class DisplayCurrencyRateFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<double?>, String> {
  DisplayCurrencyRateFamily._()
    : super(
        retry: null,
        name: r'displayCurrencyRateProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Currency conversion is intentionally unavailable in the offline build.
  /// Stored display-currency preferences remain intact for future overlays.

  DisplayCurrencyRateProvider call(String key) =>
      DisplayCurrencyRateProvider._(argument: key, from: this);

  @override
  String toString() => r'displayCurrencyRateProvider';
}
