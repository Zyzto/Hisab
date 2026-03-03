import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../utils/error_report_helper.dart';
import 'toast.dart';

/// Shared loading content for async/loading states.
/// Use for consistent loading UI (e.g. with [AsyncValueBuilder]).
// ignore: constant_identifier_names
const LoadingContent = Center(child: CircularProgressIndicator());

/// Shared error content for async/error states. Shows icon, optional title,
/// message, optional retry button, and Share/Report issue actions.
/// Use with [AsyncValue.when] error builder or anywhere a consistent error UI is needed.
/// Parents that build this with [message]/[details] should call [sendErrorTelemetryIfOnline]
/// once when showing the error if telemetry when online is desired.
class ErrorContentWidget extends StatelessWidget {
  const ErrorContentWidget({
    super.key,
    this.message,
    this.titleKey = 'generic_error',
    this.onRetry,
    this.details,
    this.stackTrace,
  });

  /// Optional detail message (e.g. error.toString()). When null, only title is shown.
  final String? message;

  /// Translation key for the title. Defaults to [generic_error].
  final String titleKey;

  /// When non-null, a retry button is shown.
  final VoidCallback? onRetry;

  /// Optional raw details for Share/Report payload (e.g. full error.toString()).
  final String? details;

  /// Optional stack trace for Report issue body.
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayMessage = message ?? titleKey.tr();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            titleKey.tr(),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 20),
              label: Text('retry'.tr()),
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => shareErrorReport(
                  context,
                  message: displayMessage,
                  details: details,
                  stackTrace: stackTrace,
                ),
                icon: const Icon(Icons.share, size: 20),
                label: Text('share'.tr()),
              ),
              FilledButton.tonalIcon(
                onPressed: () => openErrorReportGitHubIssue(
                  context,
                  message: displayMessage,
                  details: details,
                  stackTrace: stackTrace,
                  onCopied: () {
                    if (context.mounted) {
                      context.showSuccess('logs_copied_paste'.tr());
                    }
                  },
                ),
                icon: const Icon(Icons.bug_report_outlined, size: 20),
                label: Text('report_issue'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
