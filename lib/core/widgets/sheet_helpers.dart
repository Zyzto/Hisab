import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

import '../constants/confirmation_durations.dart';
import '../layout/layout_breakpoints.dart';
import '../layout/responsive_sheet.dart';
import '../theme/accent_style.dart';
import 'sheet_option_tile.dart';
import 'user_text.dart';

/// One row for [showOptionPickerSheet].
class SheetPickerOption<T> {
  const SheetPickerOption({
    required this.value,
    required this.label,
    this.subtitle,
    this.leading,
    this.enabled = true,
  });

  final T value;
  final String label;
  final String? subtitle;
  final Widget? leading;
  final bool enabled;
}

/// Simple single-select option sheet using [SheetOptionTile]s.
Future<T?> showOptionPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetPickerOption<T>> options,
  T? selected,
  bool centerInFullViewport = true,
  Widget? header,
}) {
  return showResponsiveSheet<T>(
    context: context,
    title: LayoutBreakpoints.isTabletOrWider(context) ? title : null,
    maxHeight: MediaQuery.of(context).size.height * 0.75,
    isScrollControlled: true,
    centerInFullViewport: centerInFullViewport,
    child: SafaehTilePickerBody<T>(
      title: title,
      titleBuilder: (ctx, style) => UserText(title, style: style),
      header: header,
      selected: selected,
      options: [
        for (final opt in options)
          SafaehTileOption(
            value: opt.value,
            label: opt.label,
            subtitle: opt.subtitle,
            leading: opt.leading,
            enabled: opt.enabled,
          ),
      ],
      tileBuilder: (ctx, opt, isSelected) => SheetOptionTile(
        title: opt.label,
        subtitle: opt.subtitle,
        leading: opt.leading,
        enabled: opt.enabled,
        selected: isSelected,
        onTap: opt.enabled ? () => Navigator.of(ctx).pop(opt.value) : null,
      ),
    ),
  );
}

/// Builds the shared sheet layout: optional title (in body), body, and action row.
/// When [showTitleInBody] is false, the title is not rendered here (caller shows
/// it in the responsive sheet top bar on tablet+).
///
/// Applies [kSheetContentPadding]-aligned horizontal inset around [body] so
/// free-form content cannot sit flush on the panel edges.
///
/// Shrink-wraps to content height ([Align] + [heightFactor]) so short dialogs
/// do not stretch to the sheet [maxHeight] and leave a large empty gap above
/// the action row.
Widget buildSheetShell(
  BuildContext ctx, {
  required String title,
  required Widget body,
  required List<Widget> actions,
  bool showTitleInBody = true,
}) {
  return buildSafaehSheetShell(
    body: body,
    actions: actions,
    showTitleInBody: showTitleInBody,
    title: UserText(
      title,
      style: Theme.of(
        ctx,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

/// Shows a confirmation sheet in the same style as the language picker.
/// Returns true if confirmed, false if cancelled, null if dismissed.
Future<bool?> showConfirmSheet(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  bool timedDestructive = true,
  bool centerInFullViewport = true,
}) {
  if (isDestructive && timedDestructive) {
    return showTimedConfirmSheet(
      context,
      title: title,
      content: content,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: true,
      centerInFullViewport: centerInFullViewport,
    );
  }
  return showResponsiveSheet<bool>(
    context: context,
    title: LayoutBreakpoints.isTabletOrWider(context) ? title : null,
    maxHeight: MediaQuery.of(context).size.height * 0.75,
    isScrollControlled: true,
    centerInFullViewport: centerInFullViewport,
    child: SafaehConfirmSheet(
      title: title,
      content: content,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel ?? 'cancel'.tr(),
      isDestructive: isDestructive,
      titleBuilder: (ctx, style) => UserText(title, style: style),
      contentBuilder: (ctx, style) => UserText(content, style: style),
    ),
  );
}

/// Shows a confirmation sheet whose action is unavailable for a short delay.
///
/// This is the shared guard for irreversible actions. The timer is owned by
/// the sheet, so dismissing or navigating away cancels the action entirely.
Future<bool?> showTimedConfirmSheet(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  int seconds = destructiveConfirmationSeconds,
  bool centerInFullViewport = true,
}) {
  final isWide = LayoutBreakpoints.isTabletOrWider(context);
  return showResponsiveSheet<bool>(
    context: context,
    title: isWide ? title : null,
    maxHeight: MediaQuery.of(context).size.height * 0.75,
    isScrollControlled: true,
    centerInFullViewport: centerInFullViewport,
    child: TimedConfirmSheetContent(
      title: title,
      content: content,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      seconds: seconds,
      isDestructive: isDestructive,
    ),
  );
}

/// Body used by [showTimedConfirmSheet]. Kept public so feature pages can use
/// the same countdown without recreating slightly different dialog chrome.
class TimedConfirmSheetContent extends StatefulWidget {
  const TimedConfirmSheetContent({
    super.key,
    required this.title,
    required this.content,
    required this.confirmLabel,
    this.cancelLabel,
    this.seconds = destructiveConfirmationSeconds,
    this.isDestructive = false,
  });

  final String title;
  final String content;
  final String confirmLabel;
  final String? cancelLabel;
  final int seconds;
  final bool isDestructive;

  @override
  State<TimedConfirmSheetContent> createState() =>
      _TimedConfirmSheetContentState();
}

class _TimedConfirmSheetContentState extends State<TimedConfirmSheetContent> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds.clamp(0, 3600).toInt();
    if (_remaining > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_remaining <= 1) {
          _timer?.cancel();
          _timer = null;
          setState(() => _remaining = 0);
        } else {
          setState(() => _remaining--);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = LayoutBreakpoints.isTabletOrWider(context);
    final enabled = _remaining <= 0;
    final cancelLabel = widget.cancelLabel ?? 'cancel'.tr();

    return buildSheetShell(
      context,
      title: widget.title,
      showTitleInBody: !isWide,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DecoratedBox(
          decoration: AccentSurfaces.flatPanel(colorScheme),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UserText(
                  widget.content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                UserText(
                  enabled
                      ? 'delete_confirm_ready'.tr()
                      : 'delete_confirm_countdown'.tr(
                          namedArgs: {'seconds': '$_remaining'},
                        ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (!isWide)
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: UserText(cancelLabel),
          ),
        FilledButton(
          key: const ValueKey('safaeh_confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: widget.isDestructive ? colorScheme.error : null,
            disabledBackgroundColor: widget.isDestructive
                ? colorScheme.error.withValues(alpha: 0.3)
                : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: enabled ? () => Navigator.of(context).pop(true) : null,
          child: UserText(
            enabled
                ? widget.confirmLabel
                : '${widget.confirmLabel} ($_remaining\u2009s)',
          ),
        ),
      ],
    );
  }
}

/// Shows a text input sheet in the same style as the language picker.
/// Returns the trimmed string if Done was pressed, null if cancelled or dismissed.
Future<String?> showTextInputSheet(
  BuildContext context, {
  required String title,
  String? hint,
  String initialValue = '',
  int maxLines = 1,
  int? maxLength,
  bool obscureText = false,
  bool centerInFullViewport = true,
}) {
  return showResponsiveSheet<String?>(
    context: context,
    title: LayoutBreakpoints.isTabletOrWider(context) ? title : null,
    maxHeight: MediaQuery.of(context).size.height * 0.5,
    isScrollControlled: true,
    centerInFullViewport: centerInFullViewport,
    child: SafaehTextInputSheet(
      title: title,
      doneLabel: 'done'.tr(),
      hint: hint,
      initialValue: initialValue,
      maxLines: maxLines,
      maxLength: maxLength,
      obscureText: obscureText,
      cancelLabel: 'cancel'.tr(),
      titleBuilder: (ctx, style) => UserText(title, style: style),
    ),
  );
}
