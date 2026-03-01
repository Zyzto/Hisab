// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'display_currency_rate_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Key format: "groupCurrency|displayCurrency". When displayCurrency is empty or equals groupCurrency, returns null.

@ProviderFor(displayCurrencyRate)
final displayCurrencyRateProvider = DisplayCurrencyRateFamily._();

/// Key format: "groupCurrency|displayCurrency". When displayCurrency is empty or equals groupCurrency, returns null.

final class DisplayCurrencyRateProvider
    extends $FunctionalProvider<AsyncValue<double?>, double?, FutureOr<double?>>
    with $FutureModifier<double?>, $FutureProvider<double?> {
  /// Key format: "groupCurrency|displayCurrency". When displayCurrency is empty or equals groupCurrency, returns null.
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
    r'be29b20da41d849e46811294922f87973bf01870';

/// Key format: "groupCurrency|displayCurrency". When displayCurrency is empty or equals groupCurrency, returns null.

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

  /// Key format: "groupCurrency|displayCurrency". When displayCurrency is empty or equals groupCurrency, returns null.

  DisplayCurrencyRateProvider call(String key) =>
      DisplayCurrencyRateProvider._(argument: key, from: this);

  @override
  String toString() => r'displayCurrencyRateProvider';
}
