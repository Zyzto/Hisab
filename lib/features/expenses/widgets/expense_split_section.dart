import 'package:custom_sliding_segmented_control/custom_sliding_segmented_control.dart';
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';

import '../../../core/theme/accent_style.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/currency_helpers.dart';
import '../../../core/widgets/amount_text.dart';
import '../../../core/widgets/group_section_header.dart';
import '../../../core/widgets/participant_avatar.dart';
import '../../../core/widgets/user_text.dart';
import '../../../domain/domain.dart';
import '../constants/expense_form_constants.dart';

const double _kSplitRadius = 14;
const double _kPartsTrailingWidth = 168;
const double _kAmountsTrailingWidth = 120;
const double _kEqualTrailingWidth = 100;
const double _kMinTapHeight = 52;
const int _kPartsMin = 0;
const int _kPartsMax = 999;

/// Shared number look for equal amounts, share counts, share money, and exact fields.
TextStyle _splitNumberStyle(ThemeData theme, {Color? color}) {
  final base = theme.textTheme.bodyMedium;
  return (base ?? const TextStyle()).copyWith(
    fontSize: base?.fontSize ?? 14,
    fontWeight: FontWeight.w600,
    height: 1.0,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

InputDecoration _splitAmountDecoration(
  ThemeData theme, {
  String? prefixText,
  String? suffixText,
}) {
  final symbolStyle = _splitNumberStyle(
    theme,
    color: theme.colorScheme.onSurfaceVariant,
  );
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: theme.colorScheme.surfaceContainerHighest,
    prefixText: prefixText,
    suffixText: suffixText,
    prefixStyle: symbolStyle,
    suffixStyle: symbolStyle,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
    ),
  );
}

/// Split configuration: participants, include/exclude, custom parts or amounts.
class ExpenseSplitSection extends StatelessWidget {
  final List<Participant> participants;
  final List<int> sharesCents;
  final int amountCents;
  final String currencyCode;
  final SplitType splitType;
  final SplitType splitTypeSegmentInitial;
  final CustomSegmentedController<SplitType> splitTypeController;
  final Set<String> includedInSplitIds;
  final Map<String, String> customSplitValues;
  final Map<String, TextEditingController> splitEditControllers;
  final Map<String, FocusNode> splitFocusNodes;
  final TextEditingController? Function(Participant p) getOrCreateController;
  final FocusNode? Function(Participant p) getOrCreateFocusNode;
  final ValueChanged<SplitType> onSplitTypeChanged;
  final void Function(Participant p, bool included) onIncludeChanged;
  final void Function(
    Participant p,
    String value,
    List<Participant> includedList,
    TextEditingController? controller,
  )
  onAmountChanged;
  final void Function(Participant p, String value) onPartsChanged;
  final int Function() amountsSumCents;

  const ExpenseSplitSection({
    super.key,
    required this.participants,
    required this.sharesCents,
    required this.amountCents,
    required this.currencyCode,
    required this.splitType,
    required this.splitTypeSegmentInitial,
    required this.splitTypeController,
    required this.includedInSplitIds,
    required this.customSplitValues,
    required this.splitEditControllers,
    required this.splitFocusNodes,
    required this.getOrCreateController,
    required this.getOrCreateFocusNode,
    required this.onSplitTypeChanged,
    required this.onIncludeChanged,
    required this.onAmountChanged,
    required this.onPartsChanged,
    required this.amountsSumCents,
  });

  String _splitTypeLabel(SplitType type) {
    switch (type) {
      case SplitType.equal:
        return 'equal_short'.tr();
      case SplitType.parts:
        return 'parts_short'.tr();
      case SplitType.amounts:
        return 'amounts_short'.tr();
    }
  }

  (String symbol, bool onLeft) _currencySymbol() {
    final currency = CurrencyHelpers.fromCode(currencyCode);
    return (currency?.symbol ?? currencyCode, currency?.symbolOnLeft ?? true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final includedList = participants
        .where((p) => includedInSplitIds.contains(p.id))
        .toList();
    final isCustomSplit =
        splitType == SplitType.parts || splitType == SplitType.amounts;
    final (currencySymbol, symbolOnLeft) = _currencySymbol();

    final segmentChildren = <SplitType, Widget>{
      for (final type in SplitType.values)
        type: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            _splitTypeLabel(type),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: splitType == type
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
    };

    final segmentInitial = segmentChildren.containsKey(splitTypeSegmentInitial)
        ? splitTypeSegmentInitial
        : segmentChildren.keys.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 10),
          child: GroupSectionHeader(label: 'split'.tr()),
        ),
        CustomSlidingSegmentedControl<SplitType>(
          controller: splitTypeController,
          initialValue: segmentInitial,
          children: segmentChildren,
          height: 52,
          padding: 16,
          innerPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          thumbDecoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.1),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          isStretch: true,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          onValueChanged: onSplitTypeChanged,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: AccentSurfaces.flatPanel(
            colorScheme,
            radius: _kSplitRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(participants.length, (i) {
              final p = participants[i];
              final cents = i < sharesCents.length ? sharesCents[i] : 0;
              final included = includedInSplitIds.contains(p.id);
              final controller = getOrCreateController(p);
              final focusNode = getOrCreateFocusNode(p);

              final Widget trailing;
              if (isCustomSplit && included && controller != null) {
                if (splitType == SplitType.parts) {
                  trailing = _PartsStepper(
                    theme: theme,
                    partsText: customSplitValues[p.id] ?? controller.text,
                    moneyText: CurrencyFormatter.formatCents(
                      cents,
                      currencyCode,
                    ),
                    onDecrease: () {
                      final cur = int.tryParse(controller.text.trim()) ?? 1;
                      final next = (cur - 1).clamp(_kPartsMin, _kPartsMax);
                      final str = '$next';
                      controller.text = str;
                      controller.selection = TextSelection.collapsed(
                        offset: str.length,
                      );
                      onPartsChanged(p, str);
                    },
                    onIncrease: () {
                      final cur = int.tryParse(controller.text.trim()) ?? 0;
                      final next = (cur + 1).clamp(_kPartsMin, _kPartsMax);
                      final str = '$next';
                      controller.text = str;
                      controller.selection = TextSelection.collapsed(
                        offset: str.length,
                      );
                      onPartsChanged(p, str);
                    },
                  );
                } else {
                  // LTR keeps currency symbol on the correct side of digits in RTL UI.
                  trailing = SizedBox(
                    width: _kAmountsTrailingWidth,
                    height: _kMinTapHeight,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextField(
                        focusNode: focusNode,
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [decimalOnlyFormatter],
                        textAlign: TextAlign.end,
                        textAlignVertical: TextAlignVertical.center,
                        expands: true,
                        maxLines: null,
                        style: _splitNumberStyle(
                          theme,
                          color: colorScheme.onSurface,
                        ),
                        decoration: _splitAmountDecoration(
                          theme,
                          prefixText: symbolOnLeft ? currencySymbol : null,
                          suffixText: symbolOnLeft ? null : currencySymbol,
                        ),
                        onChanged: (v) {
                          onAmountChanged(p, v, includedList, controller);
                        },
                      ),
                    ),
                  );
                }
              } else {
                trailing = SizedBox(
                  width: _kEqualTrailingWidth,
                  height: _kMinTapHeight,
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AmountText(
                      CurrencyFormatter.formatCents(cents, currencyCode),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _splitNumberStyle(
                        theme,
                        color: included
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: SizedBox(
                  height: _kMinTapHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Checkbox(
                          value: included,
                          onChanged: (value) {
                            onIncludeChanged(p, value ?? false);
                          },
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Center(
                        child: ParticipantAvatar(
                          name: p.name,
                          avatarId: p.avatarId,
                          radius: 16,
                          backgroundColor: included
                              ? null
                              : colorScheme.surfaceContainerHighest,
                          foregroundColor: included
                              ? null
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(_kSplitRadius),
                          onTap: () => onIncludeChanged(p, !included),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: UserText(
                              p.name,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: included
                                    ? colorScheme.onSurface
                                    : colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      trailing,
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        if (splitType == SplitType.amounts && includedList.isNotEmpty) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final sumCents = amountsSumCents();
              final ok = sumCents == amountCents;
              final progress = amountCents <= 0
                  ? 0.0
                  : (sumCents / amountCents).clamp(0.0, 1.0);
              final statusColor = ok
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.error;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'total'.tr()}: ${(sumCents / 100).toStringAsFixed(2)} / ${(amountCents / 100).toStringAsFixed(2)}${ok ? '' : ' (${'amounts_must_equal_total'.tr()})'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      color: ok ? colorScheme.primary : colorScheme.error,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

class _PartsStepper extends StatelessWidget {
  final ThemeData theme;
  final String partsText;
  final String moneyText;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _PartsStepper({
    required this.theme,
    required this.partsText,
    required this.moneyText,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = theme.colorScheme;
    final numberStyle = _splitNumberStyle(theme, color: colorScheme.onSurface);

    // Keep − N + and money LTR so RTL UI does not flip to + N − / 0.00 $.
    // Explicit height — Material shrink-wraps otherwise and looks half-row tall.
    return SizedBox(
      width: _kPartsTrailingWidth,
      height: _kMinTapHeight,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            Material(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: _kMinTapHeight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PartsStepButton(
                      semanticLabel: 'decrease_part'.tr(),
                      icon: Icons.remove,
                      onPressed: onDecrease,
                    ),
                    SizedBox(
                      width: 32,
                      height: _kMinTapHeight,
                      child: Center(
                        child: Text(
                          partsText,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: numberStyle,
                        ),
                      ),
                    ),
                    _PartsStepButton(
                      semanticLabel: 'increase_part'.tr(),
                      icon: Icons.add,
                      onPressed: onIncrease,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: AmountText(
                  moneyText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: numberStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartsStepButton extends StatelessWidget {
  final String semanticLabel;
  final IconData icon;
  final VoidCallback onPressed;

  const _PartsStepButton({
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Tooltip(
        message: semanticLabel,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: _kMinTapHeight,
            child: Center(child: Icon(icon, size: 22)),
          ),
        ),
      ),
    );
  }
}
