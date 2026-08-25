import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:safaeh/safaeh.dart';

import '../layout/responsive_sheet.dart';
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
    title: title,
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
  bool centerInFullViewport = true,
}) {
  return showResponsiveSheet<bool>(
    context: context,
    title: title,
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
    title: title,
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
