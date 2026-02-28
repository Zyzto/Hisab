import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/utils/log_level_colors.dart';

/// A full-screen logs viewer dialog with terminal-style layout,
/// color-coded log levels, and scrollable content.
class LogsViewerDialog extends StatefulWidget {
  const LogsViewerDialog({
    super.key,
    required this.content,
    required this.onCopy,
    required this.onClear,
    required this.onReportIssue,
    required this.onClose,
  });

  final String content;
  final Future<void> Function() onCopy;
  final Future<void> Function() onClear;
  final Future<void> Function() onReportIssue;
  final VoidCallback onClose;

  @override
  State<LogsViewerDialog> createState() => _LogsViewerDialogState();
}

class _LogsViewerDialogState extends State<LogsViewerDialog> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showTitleInBody = !LayoutBreakpoints.isTabletOrWider(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitleInBody) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
            child: Row(
              children: [
                Icon(
                  Icons.terminal,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'view_logs'.tr(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        // Log content
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LogLevelColors.containerBackground(theme),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    scrollDirection: Axis.vertical,
                    child: SelectionArea(
                      child: _LogContent(
                        content: widget.content,
                        theme: theme,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        // Actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => widget.onCopy(),
                icon: const Icon(Icons.copy, size: 18),
                label: Text('copy_logs'.tr()),
              ),
              TextButton.icon(
                onPressed: () => widget.onClear(),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text('clear_logs'.tr()),
              ),
              TextButton.icon(
                onPressed: () => widget.onReportIssue(),
                icon: const Icon(Icons.bug_report_outlined, size: 18),
                label: Text('report_issue'.tr()),
              ),
              FilledButton(
                onPressed: widget.onClose,
                child: Text('done'.tr()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LogContent extends StatelessWidget {
  const _LogContent({
    required this.content,
    required this.theme,
  });

  final String content;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final textSpans = <InlineSpan>[];

    for (final line in lines) {
      final levelColor = LogLevelColors.levelColorForLine(line, theme.brightness);
      textSpans.add(
        TextSpan(
          text: '$line\n',
          style: TextStyle(
            fontFamily: 'monospace',
            fontFamilyFallback: const [
              'Menlo',
              'Consolas',
              'Monaco',
              'Courier',
            ],
            fontSize: 12,
            height: 1.5,
            color: levelColor ?? theme.colorScheme.onSurface,
          ),
        ),
      );
    }

    return Text.rich(
      TextSpan(children: textSpans),
      style: const TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: ['Menlo', 'Consolas', 'Monaco', 'Courier'],
        fontSize: 12,
        height: 1.5,
      ),
    );
  }

}
