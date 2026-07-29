import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/route_paths.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/group_section_header.dart';
import '../../groups/providers/group_analytics_provider.dart';
import '../providers/profile_activity_provider.dart';
import '../providers/profile_my_expenses_provider.dart';
import 'profile_category_pie_chart.dart';
import 'profile_expense_tile.dart';

const _profileExpensePreviewLimit = 10;

/// Analytics (my shares) + recent expense preview for the profile dashboard.
class ProfileActivitySection extends ConsumerWidget {
  const ProfileActivitySection({
    super.key,
    this.analyticsSectionKey,
    this.expensesSectionKey,
  });

  final Key? analyticsSectionKey;
  final Key? expensesSectionKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(profileAnalyticsRangeProvider);
    final activityAsync = ref.watch(profileActivityProvider);
    final expensesAsync = ref.watch(profileMyExpensesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: analyticsSectionKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: GroupSectionHeader(label: 'profile_my_analytics'.tr()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('analytics_range_30d'.tr()),
                selected: range == AnalyticsRangePreset.days30,
                showCheckmark: false,
                onSelected: (_) => ref
                    .read(profileAnalyticsRangeProvider.notifier)
                    .state = AnalyticsRangePreset.days30,
              ),
              ChoiceChip(
                label: Text('analytics_range_90d'.tr()),
                selected: range == AnalyticsRangePreset.days90,
                showCheckmark: false,
                onSelected: (_) => ref
                    .read(profileAnalyticsRangeProvider.notifier)
                    .state = AnalyticsRangePreset.days90,
              ),
              ChoiceChip(
                label: Text('analytics_range_all'.tr()),
                selected: range == AnalyticsRangePreset.all,
                showCheckmark: false,
                onSelected: (_) => ref
                    .read(profileAnalyticsRangeProvider.notifier)
                    .state = AnalyticsRangePreset.all,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        activityAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$e'),
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AnalyticsKpis(analytics: data.analytics),
              if (data.analytics.byTag.isNotEmpty) ...[
                const SizedBox(height: 4),
                ProfileCategoryPieChart(
                  byTag: data.analytics.byTag,
                  displayCurrencyCode: data.analytics.displayCurrencyCode,
                  rangeExpenses: data.expenses,
                ),
              ],
            ],
          ),
        ),
        KeyedSubtree(
          key: expensesSectionKey,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: GroupSectionHeader(label: 'profile_my_expenses'.tr()),
          ),
        ),
        expensesAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('$e'),
          ),
          data: (expenses) {
            final preview = expenses.take(_profileExpensePreviewLimit).toList();
            if (preview.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'profile_my_expenses_empty'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...preview.map((item) => ProfileExpenseTile(item: item)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        context.push(RoutePaths.profileExpenses),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: Text(
                      expenses.length > _profileExpensePreviewLimit
                          ? 'profile_see_all_expenses'.tr(
                              namedArgs: {'count': '${expenses.length}'},
                            )
                          : 'profile_see_all_expenses_short'.tr(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AnalyticsKpis extends StatelessWidget {
  const _AnalyticsKpis({required this.analytics});

  final ProfileAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final code = analytics.displayCurrencyCode;
    final spendLabel = CurrencyFormatter.formatCents(
      analytics.mySpendCents.abs(),
      code,
    );
    final avgLabel = CurrencyFormatter.formatCents(
      analytics.averagePerDayCents.abs(),
      code,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _KpiCard(
                  label: 'analytics_kpi_my_spend'.tr(),
                  value: analytics.mySpendCents < 0 ? '−$spendLabel' : spendLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiCard(
                  label: 'analytics_kpi_avg_day'.tr(),
                  value: avgLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KpiCard(
                  label: 'analytics_kpi_transactions'.tr(),
                  value: '${analytics.transactionCount}',
                ),
              ),
            ],
          ),
          if (analytics.isPartial) ...[
            const SizedBox(height: 8),
            Text(
              'profile_analytics_partial'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
