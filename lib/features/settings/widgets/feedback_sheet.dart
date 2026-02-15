import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/theme/theme_config.dart';

/// Reusable feedback bottom sheet. Used by "Send feedback" in Settings and by
/// the screenshot-trigger flow.
class FeedbackSheet {
  FeedbackSheet._();

  /// Shows the feedback sheet. When [fromScreenshot] is true, a short hint
  /// is shown that the prompt was triggered by a screenshot.
  static Future<void> show(
    BuildContext context, {
    required bool fromScreenshot,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FeedbackSheetContent(fromScreenshot: fromScreenshot),
    );
  }
}

class _FeedbackSheetContent extends StatefulWidget {
  const _FeedbackSheetContent({required this.fromScreenshot});

  final bool fromScreenshot;

  @override
  State<_FeedbackSheetContent> createState() => _FeedbackSheetContentState();
}

class _FeedbackSheetContentState extends State<_FeedbackSheetContent> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    final message = _controller.text.trim();
    setState(() => _sending = true);

    final buffer = StringBuffer();
    if (widget.fromScreenshot) {
      buffer.writeln('(Triggered by screenshot)');
      buffer.writeln();
    }
    buffer.write(message.isEmpty ? 'Feedback' : message);

    final body = buffer.toString();

    try {
      if (reportIssueUrl.isNotEmpty) {
        final uri = Uri.parse(reportIssueUrl).replace(
          queryParameters: <String, String>{
            'title': 'Feedback',
            'body': body,
          },
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      await Clipboard.setData(ClipboardData(text: body));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: body));
    }

    if (!mounted) return;
    setState(() => _sending = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reportIssueUrl.isEmpty ? 'logs_copied_paste'.tr() : 'logs_copied'.tr(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cardTheme = theme.cardTheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: ThemeConfig.spacingM,
          vertical: ThemeConfig.spacingS,
        ),
        decoration: BoxDecoration(
          color: cardTheme.color ?? colorScheme.surface,
          borderRadius: BorderRadius.circular(ThemeConfig.cardBorderRadius),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.35,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                ThemeConfig.spacingL,
                ThemeConfig.spacingM,
                ThemeConfig.spacingL,
                ThemeConfig.spacingXL,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: ThemeConfig.spacingL),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'send_feedback'.tr(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.fromScreenshot) ...[
                    const SizedBox(height: ThemeConfig.spacingS),
                    Text(
                      'feedback_screenshot_hint'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: ThemeConfig.spacingL),
                  Flexible(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'send_feedback_hint'.tr(),
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 4,
                        minLines: 3,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ),
                  const SizedBox(height: ThemeConfig.spacingL),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: Text('cancel'.tr()),
                      ),
                      const SizedBox(width: ThemeConfig.spacingS),
                      FilledButton(
                        onPressed: _sending ? null : _submit,
                        child: _sending
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : Text('done'.tr()),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
