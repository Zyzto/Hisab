import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/theme/accent_style.dart';
import '../../../core/theme/theme_config.dart';
import '../../../domain/domain.dart';

/// SharedPreferences key: user has dismissed the Balance settle explainer.
const String balanceSettleExplainerSeenKey = 'balance_settle_explainer_seen';

bool shouldShowSettleExplainer({
  required bool seen,
  required bool readOnlyMode,
  required bool isPersonal,
}) {
  if (seen || readOnlyMode || isPersonal) return false;
  return true;
}

Future<bool> isSettleExplainerSeen() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(balanceSettleExplainerSeenKey) ?? false;
}

Future<void> markSettleExplainerSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(balanceSettleExplainerSeenKey, true);
}

String settlementMethodLabel(SettlementMethod method) {
  switch (method) {
    case SettlementMethod.pairwise:
      return 'settlement_method_pairwise'.tr();
    case SettlementMethod.greedy:
      return 'settlement_method_greedy'.tr();
    case SettlementMethod.consolidated:
      return 'settlement_method_consolidated'.tr();
    case SettlementMethod.treasurer:
      return 'settlement_method_treasurer'.tr();
  }
}

String settlementMethodOutcome(SettlementMethod method) {
  switch (method) {
    case SettlementMethod.pairwise:
      return 'settlement_method_pairwise_desc'.tr();
    case SettlementMethod.greedy:
      return 'settlement_method_greedy_desc'.tr();
    case SettlementMethod.consolidated:
      return 'settlement_method_consolidated_desc'.tr();
    case SettlementMethod.treasurer:
      return 'settlement_method_treasurer_desc'.tr();
  }
}

String settlementMethodGuide(SettlementMethod method) {
  switch (method) {
    case SettlementMethod.pairwise:
      return 'settlement_method_pairwise_guide'.tr();
    case SettlementMethod.greedy:
      return 'settlement_method_greedy_guide'.tr();
    case SettlementMethod.consolidated:
      return 'settlement_method_consolidated_guide'.tr();
    case SettlementMethod.treasurer:
      return 'settlement_method_treasurer_guide'.tr();
  }
}

String settlementMethodExample(SettlementMethod method) {
  switch (method) {
    case SettlementMethod.pairwise:
      return 'settlement_method_pairwise_example'.tr();
    case SettlementMethod.greedy:
      return 'settlement_method_greedy_example'.tr();
    case SettlementMethod.consolidated:
      return 'settlement_method_consolidated_example'.tr();
    case SettlementMethod.treasurer:
      return 'settlement_method_treasurer_example'.tr();
  }
}

IconData settlementMethodIcon(SettlementMethod method) {
  switch (method) {
    case SettlementMethod.pairwise:
      return Icons.people_outline_rounded;
    case SettlementMethod.greedy:
      return Icons.bolt_outlined;
    case SettlementMethod.consolidated:
      return Icons.receipt_long_outlined;
    case SettlementMethod.treasurer:
      return Icons.account_balance_outlined;
  }
}

/// True when settle suggestions may reshuffle counterparties after a settle payment.
bool settlementMethodMayReshuffle(SettlementMethod method) =>
    method == SettlementMethod.greedy;

/// Opens the shared settle-up explainer (Balance first visit / ? / guide info).
Future<void> showSettleUpExplainerSheet(
  BuildContext context, {
  bool markSeenOnDismiss = false,
}) async {
  await showResponsiveSheet<void>(
    context: context,
    title: 'settle_up_explainer_title'.tr(),
    maxHeight: MediaQuery.of(context).size.height * 0.75,
    isScrollControlled: true,
    centerInFullViewport: true,
    child: Builder(
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.of(ctx).padding.bottom + ThemeConfig.spacingM,
            ),
            child: SettleUpExplainerBody(
              onGotIt: () async {
                if (markSeenOnDismiss) {
                  await markSettleExplainerSeen();
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ),
        ),
      ),
    ),
  );
  if (markSeenOnDismiss) {
    await markSettleExplainerSeen();
  }
}

/// Three-beat explainer body shared by Balance and settings/create.
class SettleUpExplainerBody extends StatelessWidget {
  final VoidCallback? onGotIt;

  const SettleUpExplainerBody({super.key, this.onGotIt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final steps = <(IconData, String)>[
      (Icons.account_balance_wallet_outlined, 'settle_up_explainer_balance'.tr()),
      (Icons.swap_horiz_rounded, 'settle_up_explainer_suggestions'.tr()),
      (Icons.touch_app_outlined, 'settle_up_explainer_one_at_a_time'.tr()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!LayoutBreakpoints.isTabletOrWider(context)) ...[
          Text(
            'settle_up_explainer_title'.tr(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(steps[i].$1, size: 20, color: colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  steps[i].$2,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
                ),
              ),
            ],
          ),
        ],
        if (onGotIt != null) ...[
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onGotIt,
            child: Text('settle_up_explainer_got_it'.tr()),
          ),
        ],
      ],
    );
  }
}

/// Settlement method picker used by group create and settings.
Future<SettlementMethod?> showSettlementMethodPickerSheet(
  BuildContext context, {
  required SettlementMethod selected,
}) {
  final theme = Theme.of(context);
  return showResponsiveSheet<SettlementMethod>(
    context: context,
    title: 'settlement_method'.tr(),
    maxHeight: MediaQuery.of(context).size.height * 0.85,
    isScrollControlled: true,
    centerInFullViewport: true,
    child: Builder(
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).padding.bottom + ThemeConfig.spacingM,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!LayoutBreakpoints.isTabletOrWider(context))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'settlement_method'.tr(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (final method in SettlementMethod.values) ...[
                        _SettlementMethodOption(
                          method: method,
                          selected: method == selected,
                          emphasizeLiveChip:
                              method == SettlementMethod.greedy,
                          onTap: () => Navigator.pop(ctx, method),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'settlement_picker_footer'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SettlementMethodOption extends StatelessWidget {
  final SettlementMethod method;
  final bool selected;
  final bool emphasizeLiveChip;
  final VoidCallback onTap;

  const _SettlementMethodOption({
    required this.method,
    required this.selected,
    required this.emphasizeLiveChip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final subtle = context.subtleAccents;

    return Material(
      color: selected
          ? AccentSurfaces.emphasizedFill(cs, subtle: subtle)
          : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AccentSurfaces.emphasizedBorder(cs, subtle: subtle)
                  : cs.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  settlementMethodIcon(method),
                  size: 22,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settlementMethodLabel(method),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        settlementMethodOutcome(method),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                      if (emphasizeLiveChip) ...[
                        const SizedBox(height: 8),
                        const _LivePlanChip(emphasized: true),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: cs.primary, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LivePlanChip extends StatelessWidget {
  final bool emphasized;

  const _LivePlanChip({this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: emphasized
            ? cs.tertiaryContainer.withValues(alpha: 0.85)
            : cs.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'settlement_live_plan_chip_reshuffle'.tr(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: emphasized ? cs.onTertiaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Compact guide under the selected method on create/settings.
class SettlementMethodGuideCard extends StatelessWidget {
  final SettlementMethod method;
  final bool showExample;
  final bool showInfoButton;

  const SettlementMethodGuideCard({
    super.key,
    required this.method,
    this.showExample = false,
    this.showInfoButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: AccentSurfaces.flatPanel(colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                settlementMethodIcon(method),
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  settlementMethodLabel(method),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showInfoButton)
                IconButton(
                  tooltip: 'settle_up_how_it_works'.tr(),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showSettleUpExplainerSheet(context),
                  icon: const Icon(Icons.help_outline_rounded, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            settlementMethodGuide(method),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          if (showExample) ...[
            const SizedBox(height: 8),
            Text(
              settlementMethodExample(method),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.9),
                height: 1.35,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (settlementMethodMayReshuffle(method)) ...[
            const SizedBox(height: 10),
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: _LivePlanChip(emphasized: true),
            ),
            const SizedBox(height: 8),
            Text(
              'settlement_guide_live_line_reshuffle'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tappable summary row that opens [showSettlementMethodPickerSheet].
class SettlementMethodPickerButton extends StatelessWidget {
  final SettlementMethod method;
  final ValueChanged<SettlementMethod>? onChanged;
  final bool enabled;

  const SettlementMethodPickerButton({
    super.key = const Key('settlement_method_picker_button'),
    required this.method,
    this.onChanged,
    this.enabled = true,
  });

  Future<void> _open(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final chosen = await showSettlementMethodPickerSheet(
      context,
      selected: method,
    );
    if (chosen != null && chosen != method) {
      onChanged?.call(chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '${'settlement_method'.tr()}: ${settlementMethodLabel(method)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? () => _open(context) : null,
          borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
            ),
            child: Row(
              children: [
                Icon(
                  settlementMethodIcon(method),
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settlementMethodLabel(method),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        settlementMethodOutcome(method),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
