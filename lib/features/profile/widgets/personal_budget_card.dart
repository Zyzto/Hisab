import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';

import '../../../core/theme/accent_style.dart';
import '../../../core/theme/theme_config.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/amount_with_secondary_display.dart';
import '../../../core/widgets/user_text.dart';
import '../../../domain/domain.dart';
import '../providers/profile_dashboard_provider.dart';

/// Budget progress card for a personal list (profile + group detail).
class PersonalBudgetCard extends ConsumerWidget {
  const PersonalBudgetCard({
    super.key,
    required this.group,
    required this.spentCents,
    this.budgetCents,
    this.onTap,
    this.showTitle = true,
  });

  final Group group;
  final int spentCents;
  final int? budgetCents;
  final VoidCallback? onTap;
  final bool showTitle;

  factory PersonalBudgetCard.fromRow(
    ProfilePersonalBudgetRow row, {
    Key? key,
    VoidCallback? onTap,
  }) {
    return PersonalBudgetCard(
      key: key,
      group: row.group,
      spentCents: row.spentCents,
      budgetCents: row.budgetCents,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currencyCode = group.currencyCode;
    final hasBudget = budgetCents != null && budgetCents! > 0;
    final overBudget = hasBudget && spentCents >= budgetCents!;
    final nearBudget =
        hasBudget && !overBudget && spentCents >= (budgetCents! * 0.8).round();
    final attention = overBudget
        ? ProfileBudgetAttention.over
        : (nearBudget
              ? ProfileBudgetAttention.near
              : ProfileBudgetAttention.none);
    final attentionColor = switch (attention) {
      ProfileBudgetAttention.over => colorScheme.error,
      ProfileBudgetAttention.near => colorScheme.tertiary,
      ProfileBudgetAttention.none => null,
    };
    final progress = hasBudget
        ? (spentCents / budgetCents!).clamp(0.0, 1.2)
        : 0.0;
    final subtle = context.subtleAccents;

    final BoxDecoration panelDecoration;
    if (subtle) {
      panelDecoration = AccentSurfaces.panel(
        colorScheme,
        subtle: true,
        radius: ThemeConfig.radiusL,
      );
    } else if (attentionColor != null) {
      panelDecoration = BoxDecoration(
        borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            attentionColor.withValues(alpha: 0.9),
            colorScheme.surfaceContainerLow,
          ],
        ),
        border: Border.all(color: attentionColor.withValues(alpha: 0.45)),
      );
    } else {
      panelDecoration = AccentSurfaces.panel(
        colorScheme,
        subtle: false,
        radius: ThemeConfig.radiusL,
      );
    }

    final child = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: panelDecoration,
      child: ProfileBudgetCard(
        title: showTitle
            ? UserText(
                group.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
        caption: Text('my_budget'.tr()),
        limit: Text(
          hasBudget
              ? CurrencyFormatter.formatCentsAsWholeUnits(
                  budgetCents!,
                  currencyCode,
                )
              : '—',
          key: const Key('personal_budget_amount'),
        ),
        spent: Row(
          children: [
            Text(
              '${'my_expenses'.tr()}: ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            AmountWithSecondaryDisplay(
              amountCents: spentCents,
              groupCurrencyCode: currencyCode,
              primaryStyle: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: attentionColor ?? colorScheme.onSurface,
              ),
            ),
          ],
        ),
        progress: progress,
        attention: attention,
        showProgress: hasBudget,
      ),
    );

    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
        child: child,
      ),
    );
  }
}
