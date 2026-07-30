import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

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
    this.leading,
  });

  final T value;
  final String label;
  final Widget? leading;
}

/// Simple single-select option sheet using [SheetOptionTile]s.
Future<T?> showOptionPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<SheetPickerOption<T>> options,
  T? selected,
  bool centerInFullViewport = true,
}) {
  final isTablet = LayoutBreakpoints.isTabletOrWider(context);
  return showResponsiveSheet<T>(
    context: context,
    title: title,
    maxHeight: MediaQuery.of(context).size.height * 0.75,
    isScrollControlled: true,
    centerInFullViewport: centerInFullViewport,
    child: Builder(
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).padding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isTablet)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: UserText(
                      title,
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                SheetOptionList(
                  padding: EdgeInsets.fromLTRB(16, isTablet ? 16 : 8, 16, 8),
                  children: [
                    for (final opt in options)
                      SheetOptionTile(
                        title: opt.label,
                        leading: opt.leading,
                        selected: selected != null && opt.value == selected,
                        onTap: () => Navigator.of(ctx).pop(opt.value),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

const double _kSheetPadding = 16.0;
const double _kSheetActionsSpacing = 8.0;
const double _kSheetBodyActionsGap = 20.0;

/// Builds the shared sheet layout: optional title (in body), body, and action row.
/// When [showTitleInBody] is false, the title is not rendered here (caller shows
/// it in the responsive sheet top bar on tablet+).
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
  return SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      heightFactor: 1,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            top: showTitleInBody ? 0 : _kSheetPadding,
            bottom: MediaQuery.of(ctx).padding.bottom + _kSheetPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showTitleInBody)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    _kSheetPadding,
                    _kSheetPadding,
                    _kSheetPadding,
                    8,
                  ),
                  child: UserText(
                    title,
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              body,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: _kSheetBodyActionsGap),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kSheetPadding,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (int i = 0; i < actions.length; i++) ...[
                        if (i > 0)
                          const SizedBox(width: _kSheetActionsSpacing),
                        Focus(
                          canRequestFocus: false,
                          skipTraversal: true,
                          descendantsAreFocusable: false,
                          child: actions[i],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _sheetBodyPanel(BuildContext context, {required Widget child}) {
  final cs = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: _kSheetPadding),
    child: DecoratedBox(
      decoration: AccentSurfaces.flatPanel(cs),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
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
        body: _sheetBodyPanel(
          ctx,
          child: UserText(
            content,
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        actions: [
          if (!isTablet)
            TextButton(
              onPressed: () {
                final navigator = Navigator.of(ctx, rootNavigator: true);
                if (navigator.canPop()) navigator.pop(false);
              },
              child: Text(cancelLabel ?? 'cancel'.tr()),
            ),
          _ConfirmSheetButton(
            label: confirmLabel,
            isDestructive: isDestructive,
            onConfirm: () {
              final navigator = Navigator.of(ctx, rootNavigator: true);
              if (navigator.canPop()) navigator.pop(true);
            },
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
  int? maxLength,
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
        body: _sheetBodyPanel(
          ctx,
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
              counterText: maxLength != null ? '' : null,
              isDense: true,
            ),
            maxLines: maxLines,
            maxLength: maxLength,
            autofocus: true,
          ),
        ),
        actions: [
          if (!isTablet)
            TextButton(
              onPressed: () {
                final navigator = Navigator.of(ctx, rootNavigator: true);
                if (navigator.canPop()) navigator.pop(null);
              },
              child: Text('cancel'.tr()),
            ),
          FilledButton(
            onPressed: () {
              final navigator = Navigator.of(ctx, rootNavigator: true);
              if (navigator.canPop()) navigator.pop(controller.text.trim());
            },
            child: Text('done'.tr()),
          ),
        ],
        showTitleInBody: !isTablet,
      ),
    ),
  );
  // Defer dispose until the sheet route is fully removed from the tree.
  // Disposing when the future completes can run while the TextField is still
  // in the tree (e.g. during close animation), causing "used after being disposed".
  // Use a time-based delay so exit animation and overlay updates are done (Android/integration).
  future.then((_) {
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      controller.dispose();
    });
  });
  return future;
}

/// Confirm button that uses [InkWell] with [canRequestFocus: false] so taps
/// reliably fire when the sheet is shown on top of other modals (same fix as
/// currency picker list row).
class _ConfirmSheetButton extends StatelessWidget {
  const _ConfirmSheetButton({
    required this.label,
    required this.isDestructive,
    required this.onConfirm,
  });

  final String label;
  final bool isDestructive;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = isDestructive
        ? colorScheme.error
        : colorScheme.primary;
    final foregroundColor = isDestructive
        ? colorScheme.onError
        : colorScheme.onPrimary;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        canRequestFocus: false,
        onTap: onConfirm,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
