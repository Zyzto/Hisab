import 'package:easy_localization/easy_localization.dart';

/// Shared form validators used across the app.
class FormValidators {
  FormValidators._();

  /// Returns a localized "required" error message if [value] is null or
  /// blank (after trim); otherwise returns null.
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) return 'required'.tr();
    return null;
  }
}
