import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../layout/layout_breakpoints.dart';
import '../layout/responsive_sheet.dart';

const double _kSheetPadding = 16.0;
const double _kSheetActionsSpacing = 8.0;
const double _kSheetBodyActionsGap = 24.0;

/// Builds the shared sheet layout: optional title (in body), body, and action row.
/// When [showTitleInBody] is false, the title is not rendered here (caller shows
/// it in the responsive sheet top bar on tablet+).
Widget buildSheetShell(
  BuildContext ctx, {
  required String title,
  required Widget body,
  required List<Widget> actions,
  bool showTitleInBody = true,
}) {
  return SafeArea(
    child: SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).padding.bottom + _kSheetPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showTitleInBody)
              Padding(
                padding: const EdgeInsets.all(_kSheetPadding),
                child: Text(
                  title,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
            body,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: _kSheetBodyActionsGap),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _kSheetPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: _kSheetActionsSpacing),
                      actions[i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
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
  final isTablet = LayoutBreakpoints.isTabletOrWider(context);
  return showResponsiveSheet<bool>(
    context: context,
    title: title,
    maxHeight: MediaQuery.of(context).size.height * 0.75,
    isScrollControlled: true,
    centerInFullViewport: centerInFullViewport,
    child: Builder(
      builder: (ctx) => buildSheetShell(
        ctx,
        title: title,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kSheetPadding),
          child: Text(content),
        ),
        actions: [
          if (!isTablet)
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(cancelLabel ?? 'cancel'.tr()),
            ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
        showTitleInBody: !isTablet,
      ),
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
  bool obscureText = false,
  bool centerInFullViewport = true,
}) {
  final isTablet = LayoutBreakpoints.isTabletOrWider(context);
  final controller = TextEditingController(text: initialValue);
  final future = showResponsiveSheet<String?>(
    context: context,
    title: title,
    maxHeight: MediaQuery.of(context).size.height * 0.5,
    isScrollControlled: true,
    centerInFullViewport: centerInFullViewport,
    child: Builder(
      builder: (ctx) => buildSheetShell(
        ctx,
        title: title,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _kSheetPadding),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
            ),
            maxLines: maxLines,
            autofocus: true,
          ),
        ),
        actions: [
          if (!isTablet)
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: Text('cancel'.tr()),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('done'.tr()),
          ),
        ],
        showTitleInBody: !isTablet,
      ),
    ),
  );
  future.then((_) => controller.dispose());
  return future;
}
