import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/utils/error_report_helper.dart';
import '../../core/widgets/toast.dart';

/// Handles submission from BetterFeedback via the shared English bug-report path.
Future<void> handleFeedback(
  BuildContext context, {
  required UserFeedback feedback,
}) async {
  final message = feedback.text.trim().isEmpty ? '—' : feedback.text.trim();
  final screenshotPng = feedback.screenshot.isNotEmpty
      ? feedback.screenshot
      : null;

  final copiedAsPrimary = await submitUserBugReport(
    context,
    message: message,
    screenshotPng: screenshotPng,
    summaryEnglish: 'User feedback',
  );

  if (context.mounted) {
    context.showSuccess(
      copiedAsPrimary ? 'logs_copied_paste'.tr() : 'logs_copied'.tr(),
    );
  }
}
