import 'package:easy_localization/easy_localization.dart';

/// Shared form validators aligned with Supabase CHECK constraints.
class FormValidators {
  FormValidators._();

  /// Matches `groups.name` CHECK (length 1–200).
  static const int groupNameMax = 200;

  /// Matches `participants.name` CHECK (length 1–100).
  static const int participantNameMax = 100;

  /// Matches `expenses.title` CHECK (length 1–500).
  static const int expenseTitleMax = 500;

  /// Matches `expense_tags.label` CHECK (length 1–100).
  static const int expenseTagLabelMax = 100;

  /// Soft cap for optional invite labels (no DB CHECK; keep payloads sane).
  static const int inviteLabelMax = 100;

  /// Returns a localized "required" error if [value] is null or blank.
  static String? required(String? value) {
    if (value == null || value.trim().isEmpty) return 'required'.tr();
    return null;
  }

  /// Rejects values longer than [max] (after trim for the length check).
  static String? maxLength(String? value, int max) {
    if (value == null) return null;
    if (value.trim().length > max) {
      return 'field_too_long'.tr(namedArgs: {'max': '$max'});
    }
    return null;
  }

  /// Required + max length (trim-aware).
  static String? requiredMaxLength(String? value, int max) {
    final req = required(value);
    if (req != null) return req;
    return maxLength(value, max);
  }

  static String? groupName(String? value) =>
      requiredMaxLength(value, groupNameMax);

  static String? participantName(String? value) =>
      requiredMaxLength(value, participantNameMax);

  static String? expenseTitle(String? value) =>
      requiredMaxLength(value, expenseTitleMax);

  static String? expenseTagLabel(String? value) =>
      requiredMaxLength(value, expenseTagLabelMax);

  /// Required, parseable number, and strictly greater than zero.
  static String? positiveAmount(String? value) {
    final req = required(value);
    if (req != null) return req;
    final n = double.tryParse(value!.trim());
    if (n == null) return 'invalid_number'.tr();
    if (n <= 0) return 'amount_positive'.tr();
    return null;
  }
}
