import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../domain/domain.dart';
import '../constants/expense_form_constants.dart';

const double _kSplitRadius = 4;

InputDecoration _splitInputDecoration(ThemeData theme) {
  return InputDecoration(
    isDense: true,
    filled: true,
    fillColor: theme.colorScheme.surfaceContainerHighest,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_kSplitRadius),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_kSplitRadius),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_kSplitRadius),
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
  final Set<String> includedInSplitIds;
  final Map<String, String> customSplitValues;
  final Map<String, TextEditingController> splitEditControllers;
  final Map<String, FocusNode> splitFocusNodes;
  final TextEditingController? Function(Participant p) getOrCreateController;
  final FocusNode? Function(Participant p) getOrCreateFocusNode;
  final VoidCallback onSplitTypeTap;
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
    required this.includedInSplitIds,
    required this.customSplitValues,
    required this.splitEditControllers,
    required this.splitFocusNodes,
    required this.getOrCreateController,
    required this.getOrCreateFocusNode,
    required this.onSplitTypeTap,
    required this.onIncludeChanged,
    required this.onAmountChanged,
    required this.onPartsChanged,
    required this.amountsSumCents,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final includedList = participants
        .where((p) => includedInSplitIds.contains(p.id))
        .toList();
    final isCustomSplit =
        splitType == SplitType.parts || splitType == SplitType.amounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                'split'.tr(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onSplitTypeTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          splitType == SplitType.equal
                              ? 'equal'.tr()
                              : splitType == SplitType.parts
                              ? 'parts'.tr()
                              : 'amounts'.tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(_kSplitRadius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kSplitRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: participants.length,
                itemBuilder: (context, i) {
                  final p = participants[i];
                  final cents = i < sharesCents.length ? sharesCents[i] : 0;
                  final included = includedInSplitIds.contains(p.id);
                  final controller = getOrCreateController(p);
                  final focusNode = getOrCreateFocusNode(p);

                  const double kSplitInputWidth = 88;
                  const double kSplitAmountWidth = 100;
                  const double kMinTapHeight = 48;

                  Widget trailing;
                  if (isCustomSplit && included && controller != null) {
                    trailing = Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => focusNode?.requestFocus(),
                        borderRadius: BorderRadius.circular(_kSplitRadius),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: kMinTapHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    _kSplitRadius,
                                  ),
                                  child: SizedBox(
                                    width: kSplitInputWidth,
                                    height: kMinTapHeight - 12,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: TextField(
                                        focusNode: focusNode,
                                        controller: controller,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                              decimal:
                                                  splitType ==
                                                  SplitType.amounts,
                                            ),
                                        inputFormatters:
                                            splitType == SplitType.amounts
                                            ? [decimalOnlyFormatter]
                                            : [
                                                FilteringTextInputFormatter
                                                    .digitsOnly,
                                              ],
                                        textAlign: TextAlign.center,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                              height: 1.0,
                                            ),
                                        decoration: _splitInputDecoration(
                                          theme,
                                        ),
                                        onChanged: (v) {
                                          if (splitType == SplitType.amounts) {
                                            onAmountChanged(
                                              p,
                                              v,
                                              includedList,
                                              controller,
                                            );
                                          } else {
                                            onPartsChanged(p, v);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: kSplitAmountWidth,
                                  child: Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: Text(
                                      CurrencyFormatter.formatCents(
                                        cents,
                                        currencyCode,
                                      ),
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  } else {
                    trailing = SizedBox(
                      width: kSplitAmountWidth,
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          CurrencyFormatter.formatCents(cents, currencyCode),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: included
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }

                  return CheckboxListTile(
                    value: included,
                    onChanged: (value) {
                      onIncludeChanged(p, value ?? false);
                    },
                    title: Text(
                      p.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: included
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    secondary: trailing,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    dense: true,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        if (splitType == SplitType.amounts && includedList.isNotEmpty) ...[
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final sumCents = amountsSumCents();
              final ok = sumCents == amountCents;
              return Text(
                '${'total'.tr()}: ${(sumCents / 100).toStringAsFixed(2)} / ${(amountCents / 100).toStringAsFixed(2)}${ok ? '' : ' (${'amounts_must_equal_total'.tr()})'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ok
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
