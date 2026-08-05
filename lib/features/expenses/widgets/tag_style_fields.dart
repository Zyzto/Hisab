import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/widgets/user_text.dart';
import '../category_icons.dart';

/// Live preview of a custom tag as it will appear on expenses.
///
/// Width follows the label (shrink-wrap), capped by [maxWidth] / a fraction of
/// the viewport so long names ellipsize instead of crowding footer actions.
class TagPreviewChip extends StatelessWidget {
  const TagPreviewChip({
    super.key,
    required this.iconName,
    required this.colorHex,
    this.label,
    this.maxWidth,
  });

  final String iconName;
  final String colorHex;

  /// Empty/null falls back to [tag_name].
  final String? label;

  /// Hard cap; defaults to ~45% of screen width (min 120, max 220).
  final double? maxWidth;

  static double defaultMaxWidth(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return math.min(220.0, math.max(120.0, w * 0.45));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor =
        parseTagColorHex(colorHex) ?? theme.colorScheme.primary;
    final onSelected = contrastingForeground(selectedColor);
    final iconData = selectableCategoryIcons[iconName] ?? Icons.label_outlined;
    final trimmed = label?.trim();
    final chipLabel = (trimmed != null && trimmed.isNotEmpty)
        ? trimmed
        : 'tag_name'.tr();
    final cap = maxWidth ?? defaultMaxWidth(context);

    return Semantics(
      label: chipLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: cap),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selectedColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selectedColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, size: 18, color: onSelected),
              const SizedBox(width: 6),
              Flexible(
                child: UserText(
                  chipLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: onSelected,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icon + color pickers for create/edit custom category sheets.
class TagStyleFields extends StatelessWidget {
  const TagStyleFields({
    super.key,
    required this.selectedIconName,
    required this.selectedColorHex,
    required this.onIconSelected,
    required this.onColorSelected,
    this.previewLabel,
    this.showPreview = true,
  });

  final String selectedIconName;
  final String selectedColorHex;
  final ValueChanged<String> onIconSelected;
  final ValueChanged<String> onColorSelected;

  /// Live name for the preview chip; empty/null falls back to [tag_name].
  final String? previewLabel;

  /// When false, the chip is omitted (e.g. pinned in [TagEditorSheetShell]).
  final bool showPreview;

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor =
        parseTagColorHex(selectedColorHex) ?? theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showPreview) ...[
          TagPreviewChip(
            label: previewLabel,
            iconName: selectedIconName,
            colorHex: selectedColorHex,
          ),
          const SizedBox(height: 16),
        ],
        Text('choose_color'.tr(), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final hex in selectableTagColorHexes)
              Builder(
                builder: (context) {
                  final color = parseTagColorHex(hex)!;
                  final selected =
                      selectedColorHex.toUpperCase() == hex.toUpperCase();
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: hex,
                    child: InkWell(
                      onTap: () {
                        _dismissKeyboard();
                        onColorSelected(hex);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.outline
                                    .withValues(alpha: 0.35),
                            width: selected ? 2.5 : 1,
                          ),
                        ),
                        child: selected
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: contrastingForeground(color),
                              )
                            : null,
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('choose_icon'.tr(), style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selectableCategoryIcons.entries.map((e) {
            final selected = selectedIconName == e.key;
            return Semantics(
              button: true,
              selected: selected,
              label: e.key.replaceAll('_', ' '),
              child: InkWell(
                onTap: () {
                  _dismissKeyboard();
                  onIconSelected(e.key);
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selected
                        ? selectedColor
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected
                          ? selectedColor
                          : theme.colorScheme.outline.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    e.value,
                    size: 28,
                    color: selected
                        ? contrastingForeground(selectedColor)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Create/edit tag layout with a sticky preview + action footer.
///
/// Title, name field, and style pickers scroll together so landscape + IME
/// (or a tall validation error) cannot RenderFlex-overflow the sheet. Preview
/// and Cancel/Done stay pinned at the bottom for one-thumb access.
class TagEditorSheetShell extends StatelessWidget {
  const TagEditorSheetShell({
    super.key,
    required this.title,
    required this.nameField,
    required this.styleFields,
    required this.preview,
    required this.actions,
  });

  final String title;
  final Widget nameField;
  final Widget styleFields;
  final Widget preview;
  final List<Widget> actions;

  static const double _padding = 20;
  static const double _actionsGap = 8;

  /// Minimum height that still fits footer + a sliver of scroll content.
  static const double _minShellHeight = 220;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final showTitle = !LayoutBreakpoints.isTabletOrWider(context);

    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenH = MediaQuery.sizeOf(context).height;
          // Prefer the sheet body max. Only fall back when unbounded (should
          // be rare); never invent a height larger than a finite parent max
          // (IME / landscape would overflow).
          final height = constraints.maxHeight.isFinite &&
                  constraints.maxHeight > 0
              ? constraints.maxHeight
              : math.max(_minShellHeight, screenH * 0.75);

          return SizedBox(
            height: height,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      _padding,
                      showTitle ? 0 : _padding,
                      _padding,
                      12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (showTitle)
                          Padding(
                            padding: const EdgeInsets.only(
                              top: _padding,
                              bottom: 8,
                            ),
                            child: UserText(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        nameField,
                        const SizedBox(height: 16),
                        styleFields,
                      ],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    border: Border(
                      top: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      _padding,
                      10,
                      _padding,
                      // Host clears the IME; keep footer tight above keyboard.
                      MediaQuery.viewInsetsOf(context).bottom > 0 ? 8 : _padding,
                    ),
                    // Preview at start; actions anchored at end (LTR right /
                    // RTL left) — same trailing edge as floating dialog chrome.
                    child: Row(
                      children: [
                        Flexible(fit: FlexFit.loose, child: preview),
                        if (actions.isNotEmpty) ...[
                          const Spacer(),
                          const SizedBox(width: 12),
                          for (int i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(width: _actionsGap),
                            Focus(
                              canRequestFocus: false,
                              skipTraversal: true,
                              descendantsAreFocusable: false,
                              child: actions[i],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
