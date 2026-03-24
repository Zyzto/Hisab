import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/constrained_content.dart';
import '../../../core/layout/content_aligned_app_bar.dart';
import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/navigation/route_paths.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_content.dart';
import '../providers/group_analytics_provider.dart';

class _ModalSelectOption<T> {
  const _ModalSelectOption({required this.value, required this.label});

  final T value;
  final String label;
}

Future<T?> _showModalSelectSheet<T>({
  required BuildContext context,
  required String title,
  required T selectedValue,
  required List<_ModalSelectOption<T>> options,
}) {
  final isTablet = LayoutBreakpoints.isTabletOrWider(context);
  return showResponsiveSheet<T>(
    context: context,
    title: title,
    maxHeight: MediaQuery.of(context).size.height * 0.75,
    isScrollControlled: true,
    centerInFullViewport: true,
    child: Builder(
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).padding.bottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isTablet)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      title,
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                ...options.map((option) {
                  final isSelected = option.value == selectedValue;
                  return ListTile(
                    title: Text(option.label),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(ctx).colorScheme.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(ctx, rootNavigator: true).pop(option.value),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

extension on AnalyticsTrendChartMode {
  String get labelKey {
    switch (this) {
      case AnalyticsTrendChartMode.totalBar:
        return 'analytics_chart_mode_total_bar';
      case AnalyticsTrendChartMode.totalLine:
        return 'analytics_chart_mode_total_line';
      case AnalyticsTrendChartMode.userComparison:
        return 'analytics_chart_mode_users_line';
      case AnalyticsTrendChartMode.categoryComparison:
        return 'analytics_chart_mode_categories_combined';
    }
  }
}

extension on AnalyticsCategoryChartMode {
  String get labelKey {
    switch (this) {
      case AnalyticsCategoryChartMode.bars:
        return 'analytics_chart_mode_bar';
      case AnalyticsCategoryChartMode.pie:
        return 'analytics_chart_mode_pie';
    }
  }
}

class GroupAnalyticsPage extends ConsumerStatefulWidget {
  const GroupAnalyticsPage({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupAnalyticsPage> createState() => _GroupAnalyticsPageState();
}

class _GroupAnalyticsPageState extends ConsumerState<GroupAnalyticsPage> {
  AnalyticsRangePreset _range = AnalyticsRangePreset.days90;
  String? _participantId;
  String? _tagId;

  @override
  Widget build(BuildContext context) {
    final uiState = ref.watch(groupAnalyticsUiStateByGroupProvider(widget.groupId));
    final query = GroupAnalyticsQuery(
      groupId: widget.groupId,
      range: _range,
      participantId: _participantId,
      tagId: _tagId,
    );
    final analyticsAsync = ref.watch(groupAnalyticsDataProvider(query));

    return LayoutBuilder(
      builder: (context, layoutConstraints) {
        return Scaffold(
          appBar: ContentAlignedAppBar(
            contentAreaWidth: layoutConstraints.maxWidth,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(RoutePaths.groupDetail(widget.groupId));
                }
              },
            ),
            title: Text('analytics'.tr()),
          ),
          body: ConstrainedContent(
            child: analyticsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(
                child: ErrorContentWidget(
                  message: e.toString(),
                  details: e.toString(),
                  stackTrace: st,
                ),
              ),
              data: (data) {
                if (data == null) {
                  return Center(child: Text('group_not_found'.tr()));
                }
                return _buildContent(context, data, uiState);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    GroupAnalyticsData data,
    GroupAnalyticsUiState uiState,
  ) {
    final theme = Theme.of(context);
    final currency = data.group.currencyCode;
    final hasData = data.filteredExpenses.isNotEmpty;
    final uiNotifier = ref.read(groupAnalyticsUiStateProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _buildFilters(context, data),
        const SizedBox(height: 12),
        if (!hasData)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.insights_outlined,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'analytics_empty'.tr(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else ...[
          _TrendChartCard(
            title: 'analytics_trend_title'.tr(),
            subtitle: _trendSubtitle(_range, data.trendGranularity),
            mode: uiState.trendChartMode,
            onModeChanged: (mode) =>
                uiNotifier.setTrendChartMode(widget.groupId, mode),
            isPersonal: data.group.isPersonal,
            points: data.trendPoints,
            participantSeries: data.participantTrendSeries,
            categorySeries: data.categoryTrendSeries,
            currencyCode: currency,
          ),
          const SizedBox(height: 12),
        ],
        _KpiGrid(
          total: CurrencyFormatter.formatCents(data.totalAmountCents, currency),
          mine: CurrencyFormatter.formatCents(data.myAmountCents, currency),
          avgPerDay: CurrencyFormatter.formatCents(
            data.averagePerDayCents,
            currency,
          ),
          txCount: data.transactionCount.toString(),
          isPersonal: data.group.isPersonal,
        ),
        if (hasData) ...[
          const SizedBox(height: 12),
          _BreakdownBarsCard(
            title: 'analytics_category_title'.tr(),
            emptyLabel: 'analytics_empty_chart'.tr(),
            rows: data.byTag.take(6).toList(),
            currencyCode: currency,
            translateUntagged: true,
            allowPieMode: true,
            mode: uiState.categoryChartMode,
            onModeChanged: (mode) =>
                uiNotifier.setCategoryChartMode(widget.groupId, mode),
            excludedCategoryIds: uiState.excludedCategoryIds,
            onToggleCategory: (categoryId) =>
                uiNotifier.toggleExcludedCategory(widget.groupId, categoryId),
            onOpenCategoryExpenses: (categoryId, categoryLabel) =>
                _showCategoryExpensesSheet(
                  context,
                  data,
                  categoryId: categoryId,
                  categoryLabel: categoryLabel,
                ),
          ),
          if (!data.group.isPersonal) ...[
            const SizedBox(height: 12),
            _BreakdownBarsCard(
              title: 'analytics_by_person_title'.tr(),
              emptyLabel: 'analytics_empty_chart'.tr(),
              rows: data.byParticipant.take(6).toList(),
              currencyCode: currency,
            ),
          ],
        ],
      ],
    );
  }

  String _trendSubtitle(AnalyticsRangePreset range, TrendGranularity granularity) {
    switch (range) {
      case AnalyticsRangePreset.days30:
        return 'analytics_range_30d'.tr();
      case AnalyticsRangePreset.days90:
        return 'analytics_range_90d'.tr();
      case AnalyticsRangePreset.all:
        return '${'analytics_range_all'.tr()} • ${_granularityLabel(granularity)}';
    }
  }

  String _granularityLabel(TrendGranularity granularity) {
    switch (granularity) {
      case TrendGranularity.daily:
        return 'analytics_granularity_daily'.tr();
      case TrendGranularity.weekly:
        return 'analytics_granularity_weekly'.tr();
      case TrendGranularity.monthly:
        return 'analytics_granularity_monthly'.tr();
    }
  }

  Widget _buildFilters(BuildContext context, GroupAnalyticsData data) {
    final participants = data.participants.where((p) => p.leftAt == null).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final allTagOptions = <_DropdownOption>[const _DropdownOption(id: '', label: '')];
    final uniqueTagIds = <String>{};
    for (final expense in data.filteredExpenses) {
      final tag = expense.tag;
      if (tag != null && tag.isNotEmpty) uniqueTagIds.add(tag);
    }
    for (final tagId in uniqueTagIds) {
      allTagOptions.add(
        _DropdownOption(id: tagId, label: resolveTagLabel(tagId, data.tags)),
      );
    }
    allTagOptions.sort(
      (a, b) => _translateCategoryLike(
        a.label,
      ).toLowerCase().compareTo(_translateCategoryLike(b.label).toLowerCase()),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'analytics_filters'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text('analytics_range_30d'.tr()),
                  selected: _range == AnalyticsRangePreset.days30,
                  onSelected: (_) => setState(() => _range = AnalyticsRangePreset.days30),
                ),
                ChoiceChip(
                  label: Text('analytics_range_90d'.tr()),
                  selected: _range == AnalyticsRangePreset.days90,
                  onSelected: (_) => setState(() => _range = AnalyticsRangePreset.days90),
                ),
                ChoiceChip(
                  label: Text('analytics_range_all'.tr()),
                  selected: _range == AnalyticsRangePreset.all,
                  onSelected: (_) => setState(() => _range = AnalyticsRangePreset.all),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!data.group.isPersonal)
              Row(
                children: [
                  Expanded(
                    child: _FilterDropdown(
                      label: 'analytics_filter_member'.tr(),
                      value: _participantId ?? '',
                      items: [
                        _DropdownMenuItemData(
                          value: '',
                          label: 'analytics_filter_all_members'.tr(),
                        ),
                        ...participants.map(
                          (p) => _DropdownMenuItemData(value: p.id, label: p.name),
                        ),
                      ],
                      onChanged: (v) => setState(() => _participantId = v.isEmpty ? null : v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FilterDropdown(
                      label: 'analytics_filter_category'.tr(),
                      value: _tagId ?? '',
                      items: [
                        _DropdownMenuItemData(
                          value: '',
                          label: 'analytics_filter_all_categories'.tr(),
                        ),
                        ...allTagOptions
                            .where((o) => o.id.isNotEmpty)
                            .map(
                              (o) => _DropdownMenuItemData(
                                value: o.id,
                                label: _translateCategoryLike(o.label),
                              ),
                            ),
                      ],
                      onChanged: (v) => setState(() => _tagId = v.isEmpty ? null : v),
                    ),
                  ),
                ],
              )
            else
              _FilterDropdown(
                label: 'analytics_filter_category'.tr(),
                value: _tagId ?? '',
                items: [
                  _DropdownMenuItemData(
                    value: '',
                    label: 'analytics_filter_all_categories'.tr(),
                  ),
                  ...allTagOptions
                      .where((o) => o.id.isNotEmpty)
                      .map(
                        (o) => _DropdownMenuItemData(
                          value: o.id,
                          label: _translateCategoryLike(o.label),
                        ),
                      ),
                ],
                onChanged: (v) => setState(() => _tagId = v.isEmpty ? null : v),
              ),
          ],
        ),
      ),
    );
  }

  String _translateCategoryLike(String rawLabel) {
    if (rawLabel == 'untagged') return 'analytics_untagged'.tr();
    if (rawLabel.startsWith('category_')) return rawLabel.tr();
    return rawLabel;
  }

  Future<void> _showCategoryExpensesSheet(
    BuildContext context,
    GroupAnalyticsData data, {
    required String categoryId,
    required String categoryLabel,
  }) async {
    final expenses = data.filteredExpenses.where((expense) {
      final normalizedTag = (expense.tag == null || expense.tag!.isEmpty)
          ? 'untagged'
          : expense.tag!;
      return normalizedTag == categoryId;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final participantNames = {
      for (final participant in data.participants) participant.id: participant.name,
    };

    await showResponsiveSheet<void>(
      context: context,
      title: 'analytics_category_expenses_title'.tr(
        namedArgs: {'category': _translateCategoryLike(categoryLabel)},
      ),
      maxHeight: MediaQuery.of(context).size.height * 0.8,
      isScrollControlled: true,
      centerInFullViewport: true,
      child: SafeArea(
        child: expenses.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Text(
                  'analytics_category_expenses_empty'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: expenses.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, index) {
                  final expense = expenses[index];
                  final payerName = participantNames[expense.payerParticipantId] ??
                      expense.payerParticipantId;
                  final amount = CurrencyFormatter.formatCents(
                    expense.amountCents,
                    data.group.currencyCode,
                  );
                  return ListTile(
                    title: Text(
                      expense.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$payerName • ${DateFormat.yMMMd().format(expense.date)}',
                    ),
                    trailing: Text(
                      amount,
                      style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.total,
    required this.mine,
    required this.avgPerDay,
    required this.txCount,
    required this.isPersonal,
  });

  final String total;
  final String mine;
  final String avgPerDay;
  final String txCount;
  final bool isPersonal;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _KpiCard(label: 'analytics_kpi_total'.tr(), value: total),
        _KpiCard(
          label: isPersonal ? 'analytics_kpi_my_spend_personal'.tr() : 'analytics_kpi_my_spend'.tr(),
          value: mine,
        ),
        _KpiCard(label: 'analytics_kpi_avg_day'.tr(), value: avgPerDay),
        _KpiCard(label: 'analytics_kpi_transactions'.tr(), value: txCount),
      ],
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendChartCard extends StatelessWidget {
  const _TrendChartCard({
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.onModeChanged,
    required this.isPersonal,
    required this.points,
    required this.participantSeries,
    required this.categorySeries,
    required this.currencyCode,
  });

  final String title;
  final String subtitle;
  final AnalyticsTrendChartMode mode;
  final ValueChanged<AnalyticsTrendChartMode> onModeChanged;
  final bool isPersonal;
  final List<TrendPoint> points;
  final List<TrendSeries> participantSeries;
  final List<TrendSeries> categorySeries;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeMode = _resolveMode(mode);
    final availableModes = _availableModes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    final selected =
                        await _showModalSelectSheet<AnalyticsTrendChartMode>(
                      context: context,
                      title: 'analytics_chart_mode_menu'.tr(),
                      selectedValue: activeMode,
                      options: availableModes
                          .map(
                            (mode) => _ModalSelectOption<AnalyticsTrendChartMode>(
                              value: mode,
                              label: mode.labelKey.tr(),
                            ),
                          )
                          .toList(),
                    );
                    if (selected != null) onModeChanged(selected);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          activeMode.labelKey.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          softWrap: false,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 18),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _modeHint(activeMode).tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            _buildChartContent(context, theme, activeMode),
          ],
        ),
      ),
    );
  }

  static const _seriesPalette = <Color>[
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFEA580C),
    Color(0xFF7C3AED),
  ];

  List<AnalyticsTrendChartMode> get _availableModes => isPersonal
      ? const [
          AnalyticsTrendChartMode.totalBar,
          AnalyticsTrendChartMode.totalLine,
          AnalyticsTrendChartMode.categoryComparison,
        ]
      : AnalyticsTrendChartMode.values;

  AnalyticsTrendChartMode _resolveMode(AnalyticsTrendChartMode candidate) {
    if (_availableModes.contains(candidate)) return candidate;
    return _availableModes.first;
  }

  Widget _buildChartContent(
    BuildContext context,
    ThemeData theme,
    AnalyticsTrendChartMode activeMode,
  ) {
    switch (activeMode) {
      case AnalyticsTrendChartMode.totalBar:
        return _buildBarTrend(theme);
      case AnalyticsTrendChartMode.totalLine:
        return _buildLineChart(
          context: context,
          series: [
            _LineSeries(
              label: 'analytics_chart_mode_total_line'.tr(),
              points: points,
              color: theme.colorScheme.primary,
            ),
          ],
          showLegend: false,
        );
      case AnalyticsTrendChartMode.userComparison:
        final visibleSeries = participantSeries
            .where((series) => series.points.any((point) => point.amountCents != 0))
            .toList();
        if (visibleSeries.isEmpty) {
          return _emptyChart(context);
        }
        return _buildLineChart(
          context: context,
          series: visibleSeries.asMap().entries.map((entry) {
            final index = entry.key;
            final series = entry.value;
            return _LineSeries(
              label: series.label,
              points: series.points,
              color: _seriesPalette[index % _seriesPalette.length],
            );
          }).toList(),
        );
      case AnalyticsTrendChartMode.categoryComparison:
        final visibleSeries = categorySeries
            .where((series) => series.points.any((point) => point.amountCents != 0))
            .toList();
        if (visibleSeries.isEmpty) {
          return _emptyChart(context);
        }
        return _buildCombinedCategoryChart(context, visibleSeries);
    }
  }

  Widget _buildBarTrend(ThemeData theme) {
    final visiblePoints = points;
    if (visiblePoints.isEmpty) return const SizedBox(height: 164);
    final yBounds = _boundsForAmounts(
      visiblePoints.map((point) => point.amountCents.toDouble()).toList(),
    );
    final step = _xLabelStep(visiblePoints.length);

    return SizedBox(
      height: 164,
      child: BarChart(
        BarChartData(
          minY: yBounds.min,
          maxY: yBounds.max,
          baselineY: 0,
          alignment: BarChartAlignment.spaceAround,
          groupsSpace: 4,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: theme.colorScheme.outlineVariant),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: step.toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (!_shouldShowXAxisLabel(
                    index: index,
                    total: visiblePoints.length,
                    step: step,
                  )) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    fitInside: SideTitleFitInsideData.fromTitleMeta(
                      meta,
                      distanceFromEdge: 8,
                    ),
                    child: Text(
                      _bucketLabel(visiblePoints[index].start),
                      style: theme.textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: const BarTouchData(enabled: true),
          barGroups: visiblePoints.asMap().entries.map((entry) {
            final index = entry.key;
            final point = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: point.amountCents.toDouble(),
                  width: 8,
                  borderRadius: BorderRadius.circular(3),
                  color: point.amountCents < 0
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.primary,
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLineChart({
    required BuildContext context,
    required List<_LineSeries> series,
    bool showLegend = true,
  }) {
    if (points.isEmpty || series.isEmpty) return _emptyChart(context);
    final yBounds = _boundsForSeries(series);
    final referencePoints = series.first.points;
    final step = _xLabelStep(referencePoints.length);

    return Column(
      children: [
        if (showLegend) ...[
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: series
                .map(
                  (line) => _LegendChip(color: line.color, label: _displayLabel(line.label)),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: yBounds.min,
              maxY: yBounds.max,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                enabled: true,
                getTouchedSpotIndicator: (barData, spotIndexes) => spotIndexes
                    .map(
                      (_) => const TouchedSpotIndicatorData(
                        FlLine(color: Colors.transparent, strokeWidth: 0),
                        FlDotData(show: false),
                      ),
                    )
                    .toList(),
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (touchedSpot) =>
                      Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.88),
                  tooltipBorderRadius: BorderRadius.circular(10),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  tooltipBorder: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  tooltipMargin: 16,
                  showOnTopOfTheChartBoxArea: false,
                  tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                  tooltipHorizontalOffset: 0,
                  maxContentWidth: 170,
                  fitInsideHorizontally: false,
                  fitInsideVertically: false,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.asMap().entries.map((entry) {
                      final itemIndex = entry.key;
                      final spot = entry.value;
                      final pointIndex = spot.x.toInt();
                      if (pointIndex < 0 || pointIndex >= referencePoints.length) {
                        return null;
                      }
                      final seriesLabel = _displayLabel(series[spot.barIndex].label);
                      final value = CurrencyFormatter.formatCents(
                        spot.y.round(),
                        currencyCode,
                      );
                      final datePrefix = itemIndex == 0
                          ? '${DateFormat.yMMMd().format(referencePoints[pointIndex].start)}\n'
                          : '';
                      return LineTooltipItem(
                        '$datePrefix$seriesLabel: $value',
                        Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: step.toDouble(),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (!_shouldShowXAxisLabel(
                        index: index,
                        total: referencePoints.length,
                        step: step,
                      )) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(
                          meta,
                          distanceFromEdge: 8,
                        ),
                        child: Text(
                          _bucketLabel(referencePoints[index].start),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: series
                  .map(
                    (line) => LineChartBarData(
                      spots: line.points
                          .asMap()
                          .entries
                          .map(
                            (entry) => FlSpot(
                              entry.key.toDouble(),
                              entry.value.amountCents.toDouble(),
                            ),
                          )
                          .toList(),
                      color: line.color,
                      isCurved: true,
                      preventCurveOverShooting: true,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCombinedCategoryChart(BuildContext context, List<TrendSeries> series) {
    if (series.isEmpty || series.first.points.isEmpty) return _emptyChart(context);
    final pointCount = series.first.points.length;
    final step = _xLabelStep(pointCount);
    final maxY = _maxStackedAmount(series);

    final groups = <BarChartGroupData>[];
    for (int i = 0; i < pointCount; i++) {
      final stackItems = <BarChartRodStackItem>[];
      double cursor = 0;
      for (int seriesIndex = 0; seriesIndex < series.length; seriesIndex++) {
        final amount = series[seriesIndex].points[i].amountCents.toDouble();
        if (amount <= 0) continue;
        final next = cursor + amount;
        stackItems.add(
          BarChartRodStackItem(
            cursor,
            next,
            _seriesPalette[seriesIndex % _seriesPalette.length],
          ),
        );
        cursor = next;
      }
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: cursor <= 0 ? 0.1 : cursor,
              rodStackItems: stackItems,
              width: 13,
              borderRadius: BorderRadius.circular(4),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          children: series
              .asMap()
              .entries
              .map(
                (entry) => _LegendChip(
                  color: _seriesPalette[entry.key % _seriesPalette.length],
                  label: _displayLabel(entry.value.label),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY * 1.2,
              alignment: BarChartAlignment.spaceAround,
              groupsSpace: 6,
              barTouchData: const BarTouchData(enabled: true),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: step.toDouble(),
                    reservedSize: 26,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (!_shouldShowXAxisLabel(
                        index: index,
                        total: pointCount,
                        step: step,
                      )) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(
                          meta,
                          distanceFromEdge: 8,
                        ),
                        child: Text(
                          _bucketLabel(series.first.points[index].start),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: groups,
            ),
          ),
        ),
      ],
    );
  }

  Widget _emptyChart(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'analytics_empty_chart'.tr(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  String _modeHint(AnalyticsTrendChartMode mode) {
    switch (mode) {
      case AnalyticsTrendChartMode.totalBar:
        return 'analytics_chart_mode_total_bar_hint';
      case AnalyticsTrendChartMode.totalLine:
        return 'analytics_chart_mode_total_line_hint';
      case AnalyticsTrendChartMode.userComparison:
        return 'analytics_chart_mode_users_line_hint';
      case AnalyticsTrendChartMode.categoryComparison:
        return 'analytics_chart_mode_categories_combined_hint';
    }
  }

  String _bucketLabel(DateTime start) {
    return DateFormat.MMMd().format(start);
  }

  String _displayLabel(String rawLabel) {
    if (rawLabel == 'untagged') return 'analytics_untagged'.tr();
    if (rawLabel.startsWith('category_')) return rawLabel.tr();
    return rawLabel;
  }

  int _xLabelStep(int count) {
    if (count <= 1) return 1;
    return math.max(1, (count / 4).ceil());
  }

  bool _shouldShowXAxisLabel({
    required int index,
    required int total,
    required int step,
  }) {
    if (index < 0 || index >= total) return false;
    final last = total - 1;
    final isLast = index == last;
    final followsStep = index % step == 0;
    if (!isLast && !followsStep) return false;

    // Avoid edge overlap: if a step label is too close to the final label,
    // keep only the final one.
    if (!isLast && (last - index) < step) return false;
    return true;
  }

  _ChartBounds _boundsForSeries(List<_LineSeries> series) {
    final values = <double>[];
    for (final line in series) {
      for (final point in line.points) {
        values.add(point.amountCents.toDouble());
      }
    }
    return _boundsForAmounts(values);
  }

  _ChartBounds _boundsForAmounts(List<double> values) {
    if (values.isEmpty) return const _ChartBounds(min: -1, max: 1);
    double minValue = values.first;
    double maxValue = values.first;
    for (final value in values) {
      if (value < minValue) minValue = value;
      if (value > maxValue) maxValue = value;
    }
    minValue = math.min(minValue, 0);
    maxValue = math.max(maxValue, 0);
    final span = (maxValue - minValue).abs();
    final padding = math.max(1, span * 0.12);
    return _ChartBounds(min: minValue - padding, max: maxValue + padding);
  }

  double _maxStackedAmount(List<TrendSeries> series) {
    final pointCount = series.first.points.length;
    int maxValue = 0;
    for (int i = 0; i < pointCount; i++) {
      int sum = 0;
      for (final line in series) {
        sum += line.points[i].amountCents;
      }
      maxValue = math.max(maxValue, sum);
    }
    return maxValue <= 0 ? 1 : maxValue.toDouble();
  }

}

class _LineSeries {
  const _LineSeries({required this.label, required this.points, required this.color});

  final String label;
  final List<TrendPoint> points;
  final Color color;
}

class _ChartBounds {
  const _ChartBounds({required this.min, required this.max});

  final double min;
  final double max;
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    );
  }
}

class _BreakdownBarsCard extends StatelessWidget {
  const _BreakdownBarsCard({
    required this.title,
    required this.emptyLabel,
    required this.rows,
    required this.currencyCode,
    this.translateUntagged = false,
    this.allowPieMode = false,
    this.mode = AnalyticsCategoryChartMode.pie,
    this.onModeChanged,
    this.excludedCategoryIds = const <String>{},
    this.onToggleCategory,
    this.onOpenCategoryExpenses,
  });

  final String title;
  final String emptyLabel;
  final List<AmountBreakdownItem> rows;
  final String currencyCode;
  final bool translateUntagged;
  final bool allowPieMode;
  final AnalyticsCategoryChartMode mode;
  final ValueChanged<AnalyticsCategoryChartMode>? onModeChanged;
  final Set<String> excludedCategoryIds;
  final ValueChanged<String>? onToggleCategory;
  final void Function(String categoryId, String categoryLabel)?
      onOpenCategoryExpenses;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxAmount = rows.isEmpty
        ? 1
        : rows.map((r) => r.amountCents.abs()).reduce(math.max).clamp(1, 1 << 30);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleSmall),
                ),
                if (allowPieMode && onModeChanged != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      final selected =
                          await _showModalSelectSheet<AnalyticsCategoryChartMode>(
                        context: context,
                        title: 'analytics_category_chart_mode_menu'.tr(),
                        selectedValue: mode,
                        options: [
                          _ModalSelectOption<AnalyticsCategoryChartMode>(
                            value: AnalyticsCategoryChartMode.bars,
                            label: AnalyticsCategoryChartMode.bars.labelKey.tr(),
                          ),
                          _ModalSelectOption<AnalyticsCategoryChartMode>(
                            value: AnalyticsCategoryChartMode.pie,
                            label: AnalyticsCategoryChartMode.pie.labelKey.tr(),
                          ),
                        ],
                      );
                      if (selected != null) onModeChanged!(selected);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            mode.labelKey.tr(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down, size: 18),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              Text(
                emptyLabel,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else if (allowPieMode && mode == AnalyticsCategoryChartMode.pie)
              _buildPieChart(context, rows)
            else
              ...rows.map((row) {
                final label = _resolvedRowLabel(row);
                final progress = row.amountCents.abs() / maxAmount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            CurrencyFormatter.formatCents(
                              row.amountCents,
                              currencyCode,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  String _resolvedRowLabel(AmountBreakdownItem row) {
    if (translateUntagged && row.id == 'untagged') {
      return 'analytics_untagged'.tr();
    }
    if (row.label.startsWith('category_')) return row.label.tr();
    return row.label;
  }

  Widget _buildPieChart(BuildContext context, List<AmountBreakdownItem> rows) {
    final palette = <Color>[
      const Color(0xFF2563EB),
      const Color(0xFF059669),
      const Color(0xFFEA580C),
      const Color(0xFF7C3AED),
      const Color(0xFF0EA5E9),
      const Color(0xFFEF4444),
    ];
    final allRows = rows;
    final visibleRows = allRows
        .where((row) => !excludedCategoryIds.contains(row.id))
        .toList();
    final total = visibleRows.fold<int>(0, (sum, row) => sum + row.amountCents.abs());
    if (total <= 0) {
      return Text(
        emptyLabel,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PieChart(
            PieChartData(
              centerSpaceRadius: 34,
              sectionsSpace: 2,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent) return;
                  final touched = response?.touchedSection;
                  final index = touched?.touchedSectionIndex;
                  if (index == null || index < 0 || index >= visibleRows.length) return;
                  final selectedRow = visibleRows[index];
                  onOpenCategoryExpenses?.call(
                    selectedRow.id,
                    selectedRow.label,
                  );
                },
              ),
              sections: visibleRows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                final value = row.amountCents.abs().toDouble();
                final pct = (value / total) * 100;
                final showOutsidePct = pct > 0 && pct < 8;
                return PieChartSectionData(
                  value: value,
                  color: palette[index % palette.length],
                  radius: 42,
                  title: showOutsidePct ? '' : (pct >= 8 ? '${pct.toStringAsFixed(0)}%' : ''),
                  titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(
                        color: Color(0x99000000),
                        offset: Offset(0, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                  badgePositionPercentageOffset: 1.22,
                  badgeWidget: showOutsidePct
                      ? GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              onOpenCategoryExpenses?.call(row.id, row.label),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 1.6,
                                height: 12,
                                color: palette[index % palette.length],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${pct.toStringAsFixed(0)}%',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...allRows.asMap().entries.map((entry) {
          final index = entry.key;
          final row = entry.value;
          final isExcluded = excludedCategoryIds.contains(row.id);
          final label = _resolvedRowLabel(row);
          final value = CurrencyFormatter.formatCents(
            row.amountCents,
            currencyCode,
          );
          return Opacity(
            opacity: isExcluded ? 0.45 : 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onToggleCategory == null
                  ? null
                  : () => onToggleCategory!.call(row.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: palette[index % palette.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                          decoration: isExcluded ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isExcluded)
                      Icon(
                        Icons.visibility_off_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    if (isExcluded) const SizedBox(width: 6),
                    Text(
                      value,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (excludedCategoryIds.isNotEmpty && onToggleCategory != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () {
                for (final id in excludedCategoryIds) {
                  onToggleCategory!.call(id);
                }
              },
              icon: const Icon(Icons.refresh),
              label: Text('analytics_show_all_categories'.tr()),
            ),
          ),
      ],
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<_DropdownMenuItemData> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canOpen = items.length > 1;
    final selected = items.where((item) => item.value == value).firstOrNull;
    final selectedLabel = selected?.label ?? '';

    return Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: canOpen ? 1 : 0.72,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canOpen
              ? () async {
            final selectedValue = await _showModalSelectSheet<String>(
              context: context,
              title: label,
              selectedValue: value,
              options: items
                  .map(
                    (item) => _ModalSelectOption<String>(
                      value: item.value,
                      label: item.label,
                    ),
                  )
                  .toList(),
            );
            if (selectedValue != null) onChanged(selectedValue);
              }
              : null,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              filled: true,
              fillColor: canOpen
                  ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.08),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: canOpen
                      ? theme.colorScheme.outlineVariant
                      : theme.colorScheme.outline.withValues(alpha: 0.45),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.colorScheme.primary),
              ),
              isDense: true,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: canOpen
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  canOpen ? Icons.expand_more_rounded : Icons.lock_outline_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DropdownMenuItemData {
  const _DropdownMenuItemData({required this.value, required this.label});

  final String value;
  final String label;
}

class _DropdownOption {
  const _DropdownOption({required this.id, required this.label});

  final String id;
  final String label;
}
