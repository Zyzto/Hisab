import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Shared error content for async/error states. Shows icon, optional title,
/// message, and optional retry button. Use with [AsyncValue.when] error builder
/// or anywhere a consistent error UI is needed.
class ErrorContentWidget extends StatelessWidget {
  const ErrorContentWidget({
    super.key,
    this.message,
    this.titleKey = 'generic_error',
    this.onRetry,
  });

  /// Optional detail message (e.g. error.toString()). When null, only title is shown.
  final String? message;

  /// Translation key for the title. Defaults to [generic_error].
  final String titleKey;

  /// When non-null, a retry button is shown.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        ],
      ),
    );
  }
}
