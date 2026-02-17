import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/theme/theme_config.dart';
import 'screenshot_preview.dart';

/// Feedback type for the issue title/body.
enum FeedbackType {
  bug,
  suggestion,
  other,
}

/// Reusable feedback bottom sheet. Used by "Send feedback" in Settings and by
/// the screenshot-trigger flow.
class FeedbackSheet {
  FeedbackSheet._();

  /// Shows the feedback sheet. When [fromScreenshot] is true, a short hint
  /// is shown. When [screenshotPath] is non-null and the file exists, a
  /// thumbnail is shown and the body includes a note to attach the screenshot.
  static Future<void> show(
    BuildContext context, {
    required bool fromScreenshot,
    String? screenshotPath,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _FeedbackSheetContent(
        fromScreenshot: fromScreenshot,
        screenshotPath: screenshotPath,
      ),
    );
  }
}

class _FeedbackSheetContent extends StatefulWidget {
  const _FeedbackSheetContent({
    required this.fromScreenshot,
    this.screenshotPath,
  });

  final bool fromScreenshot;
  final String? screenshotPath;

  @override
  State<_FeedbackSheetContent> createState() => _FeedbackSheetContentState();
}

class _FeedbackSheetContentState extends State<_FeedbackSheetContent> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  bool _sending = false;
  FeedbackType _feedbackType = FeedbackType.other;

  bool get _hasScreenshotFile {
    if (widget.screenshotPath == null) return false;
    return screenshotFileExists(widget.screenshotPath!);
  }

  @override
  void dispose() {
    _controller.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    final message = _controller.text.trim();
    final contact = _contactController.text.trim();
    setState(() => _sending = true);

    final buffer = StringBuffer();
    final typeLabel = switch (_feedbackType) {
      FeedbackType.bug => '[Bug]',
      FeedbackType.suggestion => '[Suggestion]',
      FeedbackType.other => '[Feedback]',
    };
    buffer.writeln(typeLabel);
    buffer.writeln();
    if (widget.fromScreenshot) {
      buffer.writeln('(Triggered by screenshot)');
      buffer.writeln();
    }
    if (_hasScreenshotFile) {
      buffer.writeln('feedback_screenshot_attach_note'.tr());
      buffer.writeln();
    }
    buffer.writeln(message.isEmpty ? '—' : message);
    if (contact.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Contact: $contact');
    }

    final body = buffer.toString();
    final typeName = typeLabel.replaceAll(RegExp(r'[\[\]]'), '');
    final title = _feedbackType == FeedbackType.other
        ? 'Feedback'
        : 'Feedback $typeName';

    try {
      if (reportIssueUrl.isNotEmpty) {
        final uri = Uri.parse(reportIssueUrl).replace(
          queryParameters: <String, String>{
            'title': title,
            'body': body,
          },
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      await Clipboard.setData(ClipboardData(text: body));
    } catch (_) {
      try {
        await Clipboard.setData(ClipboardData(text: body));
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _sending = false);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          reportIssueUrl.isEmpty
              ? 'logs_copied_paste'.tr()
              : 'logs_copied'.tr(),
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
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
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
                  Text(
                    'feedback_type_label'.tr(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: ThemeConfig.spacingS),
                  Wrap(
                    spacing: ThemeConfig.spacingS,
                    runSpacing: ThemeConfig.spacingXS,
                    children: [
                      _TypeChip(
                        label: 'feedback_type_bug'.tr(),
                        selected: _feedbackType == FeedbackType.bug,
                        onTap: () => setState(() => _feedbackType = FeedbackType.bug),
                      ),
                      _TypeChip(
                        label: 'feedback_type_suggestion'.tr(),
                        selected: _feedbackType == FeedbackType.suggestion,
                        onTap: () =>
                            setState(() => _feedbackType = FeedbackType.suggestion),
                      ),
                      _TypeChip(
                        label: 'feedback_type_other'.tr(),
                        selected: _feedbackType == FeedbackType.other,
                        onTap: () => setState(() => _feedbackType = FeedbackType.other),
                      ),
                    ],
                  ),
                  const SizedBox(height: ThemeConfig.spacingL),
                  if (_hasScreenshotFile) ...[
                    Text(
                      'feedback_screenshot_preview'.tr(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: ThemeConfig.spacingS),
                    buildScreenshotThumbnail(widget.screenshotPath!),
                    const SizedBox(height: ThemeConfig.spacingL),
                  ],
                  Text(
                    'feedback_message_label'.tr(),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: ThemeConfig.spacingS),
                  TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'send_feedback_hint'.tr(),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(ThemeConfig.inputBorderRadius),
                      ),
                      alignLabelWithHint: true,
                      filled: true,
                    ),
                    maxLines: 4,
                    minLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: ThemeConfig.spacingM),
                  TextField(
                    controller: _contactController,
                    decoration: InputDecoration(
                      hintText: 'feedback_contact_hint'.tr(),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(ThemeConfig.inputBorderRadius),
                      ),
                      alignLabelWithHint: true,
                      filled: true,
                    ),
                    maxLines: 1,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
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

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
    );
  }
}
