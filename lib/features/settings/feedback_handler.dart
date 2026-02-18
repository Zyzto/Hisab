import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_config.dart';
import 'feedback_clipboard.dart';
import 'feedback_upload.dart';

/// Handles submission from the feedback package: builds issue body, optionally
/// uploads screenshot to Supabase Storage, opens GitHub issue URL, copies to
/// clipboard, and shows a snackbar.
Future<void> handleFeedback(
  BuildContext context, {
  required UserFeedback feedback,
}) async {
  final buffer = StringBuffer();
  buffer.write(feedback.text.trim().isEmpty ? '—' : feedback.text.trim());

  String? screenshotUrl;
  if (feedback.screenshot.isNotEmpty) {
    screenshotUrl = await uploadFeedbackScreenshot(feedback.screenshot);
  }

  if (screenshotUrl != null) {
    buffer.writeln();
    buffer.writeln();
    buffer.writeln('![Screenshot]($screenshotUrl)');
  } else if (feedback.screenshot.isNotEmpty) {
    buffer.writeln();
    buffer.writeln();
    buffer.writeln('(Screenshot was captured; please attach it manually if needed.)');
  }

  final body = buffer.toString();
  const title = 'Feedback';

  final screenshotBytes =
      feedback.screenshot.isNotEmpty ? feedback.screenshot : null;
  try {
    if (reportIssueUrl.isNotEmpty) {
      final uri = Uri.parse(reportIssueUrl).replace(
        queryParameters: <String, String>{'title': title, 'body': body},
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    await setFeedbackClipboard(body, screenshotBytes);
  } catch (_) {
    // Fallback to clipboard-only when launchUrl or copy fails (e.g. no handler).
    try {
      await setFeedbackClipboard(body, screenshotBytes);
    } catch (_) {
      // Ignore clipboard failure; user still sees snackbar.
    }
  }

  if (context.mounted) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          reportIssueUrl.isEmpty ? 'logs_copied_paste'.tr() : 'logs_copied'.tr(),
        ),
      ),
    );
  }
}
