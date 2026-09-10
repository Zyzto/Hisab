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

/// Orders participants as a directory tree while retaining their explicit
/// [Participant.order] within each branch.  The participant stream normally
/// already has a stable order, but doing this here keeps the split UI correct
/// when a sync delivers children before their parent (or when an old row has
/// a missing parent reference).
List<Participant> _treeOrderedParticipants(List<Participant> participants) {
  if (participants.length < 2) return participants;

  final inputIndex = <String, int>{};
  final byId = <String, Participant>{};
  for (var i = 0; i < participants.length; i++) {
    final participant = participants[i];
    inputIndex[participant.id] = i;
    byId[participant.id] = participant;
  }

  final childrenByParent = <String, List<Participant>>{};
  final roots = <Participant>[];
  for (final participant in participants) {
    final parentId = participant.parentParticipantId;
    if (parentId == null ||
        parentId == participant.id ||
        !byId.containsKey(parentId)) {
      roots.add(participant);
    } else {
      childrenByParent.putIfAbsent(parentId, () => []).add(participant);
    }
  }

  int compareParticipants(Participant a, Participant b) {
    final order = a.order.compareTo(b.order);
    return order != 0
        ? order
        : (inputIndex[a.id] ?? 0).compareTo(inputIndex[b.id] ?? 0);
  }

  roots.sort(compareParticipants);
  for (final children in childrenByParent.values) {
    children.sort(compareParticipants);
  }

  final ordered = <Participant>[];
  final visited = <String>{};
  void visit(Participant participant) {
    if (!visited.add(participant.id)) return;
    ordered.add(participant);
    for (final child
        in childrenByParent[participant.id] ?? const <Participant>[]) {
      visit(child);
    }
  }

  for (final root in roots) {
    visit(root);
  }
  // A cycle has no root.  Keep those rows visible rather than dropping them;
  // the repository validates cycles, but this is safer for stale local data.
  for (final participant in participants) {
    visit(participant);
  }
  return ordered;
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
  final bool householdEnabled;
  final Map<String, int> householdUnitCounts;

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
    this.householdEnabled = false,
    this.householdUnitCounts = const {},
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
    final childrenByParent = <String, List<String>>{};
    for (final p in participants) {
      final parent = p.parentParticipantId;
      if (parent != null) {
        childrenByParent.putIfAbsent(parent, () => []).add(p.id);
      }
    }
    final depthById = <String, int>{};
    final participantById = <String, Participant>{
      for (final participant in participants) participant.id: participant,
    };
    for (final p in participants) {
      var depth = 0;
      var parent = p.parentParticipantId;
      final seen = <String>{};
      while (parent != null && seen.add(parent)) {
        depth++;
        parent = participantById[parent]?.parentParticipantId;
      }
      depthById[p.id] = depth;
    }
    List<String> descendantsOf(String id) {
      final result = <String>[];
      void visit(String parent) {
        for (final child in childrenByParent[parent] ?? const <String>[]) {
          result.add(child);
          visit(child);
        }
      }

      visit(id);
      return result;
    }

    final isCustomSplit =
        splitType == SplitType.parts || splitType == SplitType.amounts;
    final (currencySymbol, symbolOnLeft) = _currencySymbol();
    final rowParticipants = householdEnabled
        ? _treeOrderedParticipants(participants)
        : participants;
    final shareByParticipantId = <String, int>{};
    for (var i = 0; i < participants.length && i < sharesCents.length; i++) {
      shareByParticipantId[participants[i].id] = sharesCents[i];
    }

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
        if (householdEnabled) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'household_counting_enabled_hint'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          decoration: AccentSurfaces.flatPanel(
            colorScheme,
            radius: _kSplitRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: List.generate(rowParticipants.length, (i) {
              final p = rowParticipants[i];
              final unitCount = householdUnitCounts[p.id] ?? 1;
              final cents = shareByParticipantId[p.id] ?? 0;
              final included = includedInSplitIds.contains(p.id);
              final branchIds = <String>[p.id, ...descendantsOf(p.id)];
              final branchIsIncluded = branchIds.every(
                includedInSplitIds.contains,
              );
              final branchHasIncluded = branchIds.any(
                includedInSplitIds.contains,
              );
              final hasChildren = childrenByParent[p.id]?.isNotEmpty == true;
              final branchUnitCount = branchIds.fold<int>(
                0,
                (sum, id) => sum + (householdUnitCounts[id] ?? 1),
              );
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
                padding: EdgeInsetsDirectional.only(
                  start:
                      12 + (householdEnabled ? (depthById[p.id] ?? 0) * 18 : 0),
                  end: 12,
                  top: 4,
                  bottom: 4,
                ),
                child: SizedBox(
                  height: _kMinTapHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Checkbox(
                          value: hasChildren
                              ? (branchIsIncluded
                                    ? true
                                    : (branchHasIncluded ? null : false))
                              : included,
                          tristate: hasChildren,
                          onChanged: (value) {
                            // An indeterminate family row becomes selected on
                            // the first tap, which is the least surprising
                            // way to recover a partially selected branch.
                            final next = value ?? true;
                            if (hasChildren) {
                              for (final id in branchIds) {
                                final branchParticipant = participantById[id];
                                if (branchParticipant != null) {
                                  onIncludeChanged(branchParticipant, next);
                                }
                              }
                            } else {
                              onIncludeChanged(p, next);
                            }
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
                          onTap: () {
                            final next = hasChildren
                                ? !branchIsIncluded
                                : !included;
                            if (hasChildren) {
                              for (final id in branchIds) {
                                final branchParticipant = participantById[id];
                                if (branchParticipant != null) {
                                  onIncludeChanged(branchParticipant, next);
                                }
                              }
                            } else {
                              onIncludeChanged(p, next);
                            }
                          },
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                UserText(
                                  p.name,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: included
                                        ? colorScheme.onSurface
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (householdEnabled &&
                                    childrenByParent[p.id]?.isNotEmpty == true)
                                  Text(
                                    branchIsIncluded
                                        ? '${'household_total'.tr()} · ${'household_people_count'.tr(namedArgs: {'count': '$branchUnitCount'})}'
                                        : 'named_dependents'.tr(),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                if (householdEnabled && unitCount > 1)
                                  Text(
                                    'household_split_explanation'.tr(
                                      namedArgs: {'count': '$unitCount'},
                                    ),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
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
