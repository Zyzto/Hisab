import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../utils/error_report_helper.dart';

/// Max characters to show in error toast title.
const int _errorToastMessageMaxLen = 120;

/// Unified toast API over [toastification]. Use these extensions instead of
/// [ScaffoldMessenger.showSnackBar] for consistent styling and behavior.
extension ToastContext on BuildContext {
  /// Shows a toast with optional [duration] and [type]. Default: 4s, info.
  void showToast(
    String message, {
    Duration? duration,
    ToastificationType? type,
  }) {
    if (!mounted) return;
    toastification.show(
      context: this,
      title: Text(message),
      type: type ?? ToastificationType.info,
      style: ToastificationStyle.flat,
      autoCloseDuration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows a success toast (e.g. "Copied", "Saved").
  void showSuccess(String message, {Duration? duration}) {
    showToast(message, duration: duration, type: ToastificationType.success);
  }

  /// Shows an error toast (no actions).
  void showError(String message, {Duration? duration}) {
    showToast(message, duration: duration, type: ToastificationType.error);
  }

  /// Shows an error toast with Share and Report issue actions.
  /// Use when the user should be able to share or report the error.
  void showErrorWithActions(
    String message, {
    String? details,
    StackTrace? stackTrace,
    Duration? duration,
  }) {
    if (!mounted) return;
    final displayMessage = message.length > _errorToastMessageMaxLen
        ? '${message.substring(0, _errorToastMessageMaxLen)}…'
        : message;
    toastification.showCustom(
      context: this,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: duration ?? const Duration(seconds: 8),
      builder: (context, holder) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return Material(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 24,
                      color: colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        displayMessage,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        shareErrorReport(
                          context,
                          message: message,
                          details: details,
                          stackTrace: stackTrace,
                        );
                        toastification.dismiss(holder);
                      },
                      child: Text('share'.tr()),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        openErrorReportGitHubIssue(
                          context,
                          message: message,
                          details: details,
                          stackTrace: stackTrace,
                          onCopied: () {
                            if (context.mounted) {
                              context.showSuccess('logs_copied_paste'.tr());
                            }
                          },
                        );
                        toastification.dismiss(holder);
                      },
                      child: Text('report_issue'.tr()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Dismisses all visible toasts. Use before showing a replacement (e.g. sync status).
  void dismissAllToasts() {
    if (!mounted) return;
    toastification.dismissAll(delayForAnimation: true);
  }
}
