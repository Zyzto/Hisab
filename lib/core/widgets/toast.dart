import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:safaeh/safaeh.dart';

import '../utils/error_report_helper.dart';
import '../utils/user_text.dart';
import 'user_text.dart';

/// Max graphemes to show in error toast title.
const int _errorToastMessageMaxGraphemes = 120;

/// Hisab's app adapter over Safaeh feedback. Use these extensions instead of
/// [ScaffoldMessenger.showSnackBar] for consistent styling and behavior.
extension ToastContext on BuildContext {
  /// Shows an informational toast with an optional [duration].
  void showToast(String message, {Duration? duration}) {
    showSafaehFeedback(
      message,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows a success toast (e.g. "Copied", "Saved").
  void showSuccess(String message, {Duration? duration}) {
    showSafaehFeedback(
      message,
      type: SafaehFeedbackType.success,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows an error toast (no actions).
  void showError(String message, {Duration? duration}) {
    showSafaehFeedback(
      message,
      type: SafaehFeedbackType.error,
      duration: duration ?? const Duration(seconds: 4),
    );
  }

  /// Shows an error toast with share and copy-diagnostics actions.
  /// Use when the user should be able to preserve or share the error locally.
  void showErrorWithActions(
    String message, {
    String? details,
    StackTrace? stackTrace,

    /// Short English diagnostic line (e.g. same as [Log.warning] text).
    String? summaryEnglish,
    Duration? duration,
  }) {
    if (!mounted) return;
    final uiLocaleTag = readUiLocaleTagForReport(this);
    final displayMessage = elideGraphemes(
      message,
      maxGraphemes: _errorToastMessageMaxGraphemes,
      trimInput: false,
    );
    final surfaceContext = this;
    showSafaehCustomFeedback(
      duration: duration ?? const Duration(seconds: 8),
      builder: (context, dismiss) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return SafaehFeedbackSurface(
          type: SafaehFeedbackType.error,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UserText(
                displayMessage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () async {
                      // Remove overlay before native share sheet so Android does not
                      // keep a stale hit target over the bottom of the screen.
                      dismiss();
                      try {
                        await shareErrorReport(
                          surfaceContext,
                          message: message,
                          details: details,
                          stackTrace: stackTrace,
                          summaryEnglish: summaryEnglish,
                          uiLocaleTag: uiLocaleTag,
                        );
                      } catch (e) {
                        Log.debug('Share from error toast failed', error: e);
                      }
                    },
                    child: Text('share'.tr()),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () async {
                      dismiss();
                      try {
                        await copyErrorReportToClipboard(
                          surfaceContext,
                          message: message,
                          details: details,
                          stackTrace: stackTrace,
                          summaryEnglish: summaryEnglish,
                          uiLocaleTag: uiLocaleTag,
                          onCopied: () {
                            if (surfaceContext.mounted) {
                              surfaceContext.showSuccess(
                                'logs_copied_paste'.tr(),
                              );
                            }
                          },
                        );
                      } catch (e) {
                        Log.debug(
                          'Report issue from error toast failed',
                          error: e,
                        );
                      }
                    },
                    child: Text('report_issue'.tr()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Info toast with a single primary action (e.g. screenshot → report prompt).
  void showPromptWithAction(
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration? duration,
  }) {
    if (!mounted) return;
    showSafaehCustomFeedback(
      duration: duration ?? const Duration(seconds: 8),
      builder: (context, dismiss) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        return SafaehFeedbackSurface(
          type: SafaehFeedbackType.info,
          icon: Icons.screenshot_outlined,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UserText(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  onPressed: () {
                    dismiss();
                    onAction();
                  },
                  child: Text(actionLabel),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows an informational toast with one explicit action. Auto-dismiss does
  /// not invoke the action, which is important for Undo windows: only tapping
  /// the button should cancel the pending operation.
  void showToastWithAction(
    String message, {
    required String actionLabel,
    required VoidCallback onAction,
    Duration? duration,
    IconData icon = Icons.undo,
  }) {
    showSafaehFeedbackWithAction(
      message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration ?? const Duration(seconds: 8),
      icon: icon,
    );
  }

  /// Dismisses all visible toasts. Use before showing a replacement status.
  void dismissAllToasts() {
    dismissSafaehFeedbacks();
  }
}
