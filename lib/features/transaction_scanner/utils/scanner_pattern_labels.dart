import 'package:easy_localization/easy_localization.dart';

/// Localized display name for a scanner pattern.
/// Built-in patterns may be stored as translation keys or legacy English labels.
String scannerPatternDisplayName(String name) {
  switch (name) {
    case 'scanner_pattern_bank_en':
    case 'Bank SMS (EN)':
      return 'scanner_pattern_bank_en'.tr();
    case 'scanner_pattern_bank_ar':
    case 'Bank SMS (AR)':
      return 'scanner_pattern_bank_ar'.tr();
    case 'scanner_pattern_generic_amount':
    case 'Generic Amount':
      return 'scanner_pattern_generic_amount'.tr();
    case 'scanner_pattern_taught':
    case 'Taught from sample':
      return 'scanner_pattern_taught'.tr();
    default:
      return name;
  }
}
