import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/user_text.dart';

/// One slice in a standardized breakdown donut chart.
class BreakdownPieSlice {
  const BreakdownPieSlice({
    required this.id,
    required this.label,
    required this.amountCents,
    required this.color,
    this.icon,
    this.count,
    this.canOpen = true,
  });

  final String id;
  final String label;
  final int amountCents;
  final Color color;
  final IconData? icon;
  final int? count;

  /// When false (e.g. aggregated "Other"), second tap does not open a list.
  final bool canOpen;
}

/// Shared donut chart used by profile + group analytics.
///
/// Interaction:
/// - 1st tap on a slice → select (center shows amount)
/// - 2nd tap on the **same** selected slice → [onOpenSlice] (if [canOpen])
/// - tap the center (hole) while a slice is selected → [onOpenSlice] (if [canOpen])
/// - tap another slice → select that slice
/// - tap empty pie area / outside chart → deselect
/// - tap center with nothing selected, or a non-openable slice → deselect
///
/// [centerOverride] lets a parent show a legend row’s amount in the hole while
/// [selectedId] highlights a different slice (e.g. aggregated "Other").
class BreakdownPieChart extends StatefulWidget {
  const BreakdownPieChart({
    super.key,
    required this.slices,
    required this.currencyCode,
    this.title,
    this.emptyLabel,
    this.onOpenSlice,
    this.showLegend = true,
    this.legend,
    this.height = 210,
    this.selectedId,
    this.onSelectionChanged,
    this.centerOverride,
  });

  final List<BreakdownPieSlice> slices;
  final String currencyCode;
  final String? title;
  final String? emptyLabel;

  /// Called on second tap of an already-selected openable slice.
  final ValueChanged<BreakdownPieSlice>? onOpenSlice;

  /// Built-in legend under the chart. Ignored when [legend] is non-null.
  final bool showLegend;

  /// Fully custom legend (e.g. analytics exclude toggles).
  final Widget? legend;

  final double height;

  /// When [onSelectionChanged] is set, selection is controlled by the parent.
  final String? selectedId;
  final ValueChanged<String?>? onSelectionChanged;

  /// Center amount when it should differ from the highlighted [selectedId].
  final BreakdownPieSlice? centerOverride;

  bool get _isControlled => onSelectionChanged != null;

  @override
  State<BreakdownPieChart> createState() => BreakdownPieChartState();
}

class BreakdownPieChartState extends State<BreakdownPieChart> {
  String? _selectedId;

  String? get selectedId =>
      widget._isControlled ? widget.selectedId : _selectedId;

  void clearSelection() => _setSelected(null);

  /// Programmatic tap (e.g. custom legend rows).
  void tapSliceById(String id) {
    for (final slice in widget.slices) {
      if (slice.id == id) {
        _handleSliceTap(slice);
        return;
      }
    }
  }

  BreakdownPieSlice? get _selected {
    final id = selectedId;
    if (id == null) return null;
    for (final s in widget.slices) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _setSelected(String? id) {
    if (widget._isControlled) {
      widget.onSelectionChanged!(id);
      return;
    }
    if (_selectedId == id) return;
    setState(() => _selectedId = id);
  }

  void _handleSliceTap(BreakdownPieSlice slice) {
    if (selectedId == slice.id) {
      if (slice.canOpen && widget.onOpenSlice != null) {
        widget.onOpenSlice!(slice);
      } else {
        // Non-openable slice (e.g. Other): second tap clears selection.
        _deselect();
      }
      return;
    }
    _setSelected(slice.id);
  }

  void _deselect() => _setSelected(null);

  @override
  void didUpdateWidget(covariant BreakdownPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget._isControlled) return;
    if (_selectedId == null) return;
    final stillThere = widget.slices.any((s) => s.id == _selectedId);
    if (!stillThere) {
      _selectedId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final slices = widget.slices
        .where((s) => s.amountCents > 0)
        .toList(growable: false);
    final total = slices.fold<int>(0, (sum, s) => sum + s.amountCents.abs());

    if (slices.isEmpty || total <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          widget.emptyLabel ?? 'analytics_empty_chart'.tr(),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }

    final selected = _selected;
    final center = widget.centerOverride ?? selected;
    // Uncontrolled only: drop stale ids removed from [slices].
    // Controlled parents may keep a legend selection for rows rolled into
    // "Other" — clearing here made Show more → tap category/person a no-op.
    if (!widget._isControlled &&
        selectedId != null &&
        selected == null &&
        widget.centerOverride == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) clearSelection();
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartSize =
                  constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth
                  : constraints.maxHeight;
              // Scale hole to chart size so the center overlay never covers slices.
              final centerRadius = (chartSize * 0.22).clamp(36.0, 54.0);
              // Text box stays inside the visual hole; hit target can be a bit larger.
              final holeTextSize = (centerRadius * 1.55).clamp(56.0, 96.0);
              final holeHit = (centerRadius * 1.7).clamp(64.0, 100.0);
              final sectionRadius = (chartSize * 0.20).clamp(34.0, 46.0);
              final hasSelection =
                  selectedId != null || widget.centerOverride != null;
              final centerAmount = CurrencyFormatter.formatCompactCents(
                (center?.amountCents ?? total).abs(),
                widget.currencyCode,
              );

              return RepaintBoundary(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                  PieChart(
                    PieChartData(
                      centerSpaceRadius: centerRadius,
                      sectionsSpace: 2.5,
                      startDegreeOffset: -90,
                      pieTouchData: PieTouchData(
                        // Keep touch for slice selection (primary UX); bar/line
                        // charts use UiPerf.preferCheapCharts for tooltips.
                        enabled: true,
                        // Use tap-down: fl_chart often clears touchedSection on
                        // tap-up, and a remembered index made outside taps open
                        // the already-selected slice's expense list.
                        touchCallback: (event, response) {
                          if (event is! FlTapDownEvent) return;
                          if (!event.isInterestedForInteractions) return;
                          final index =
                              response?.touchedSection?.touchedSectionIndex;
                          if (index == null ||
                              index < 0 ||
                              index >= slices.length) {
                            _deselect();
                            return;
                          }
                          _handleSliceTap(slices[index]);
                        },
                      ),
                      sections: [
                        for (final slice in slices)
                          _section(
                            context,
                            slice,
                            total,
                            selected: slice.id == selectedId,
                            hasSelection: hasSelection,
                            radius: sectionRadius,
                          ),
                      ],
                    ),
                  ),
                  // Center hole only — keep smaller than the ring so slices stay tappable.
                  SizedBox(
                    width: holeHit,
                    height: holeHit,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          final center = widget.centerOverride ?? _selected;
                          if (center != null &&
                              center.canOpen &&
                              widget.onOpenSlice != null) {
                            widget.onOpenSlice!(center);
                            return;
                          }
                          _deselect();
                        },
                        child: Center(
                          child: SizedBox(
                            width: holeTextSize,
                            height: holeTextSize * 0.45,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                centerAmount,
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                  letterSpacing: -0.5,
                                  color: center?.color ?? cs.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (hasSelection)
                    PositionedDirectional(
                      end: 0,
                      bottom: 0,
                      child: IconButton(
                        key: const ValueKey('breakdown_pie_clear_selection'),
                        tooltip: 'analytics_pie_clear_selection'.tr(),
                        visualDensity: VisualDensity.compact,
                        onPressed: _deselect,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (widget.legend != null)
          widget.legend!
        else if (widget.showLegend) ...[
          const SizedBox(height: 12),
          for (final slice in slices)
            _DefaultLegendRow(
              slice: slice,
              total: total,
              currencyCode: widget.currencyCode,
              selected: slice.id == selectedId,
              onTap: () => _handleSliceTap(slice),
            ),
        ],
      ],
    );
  }

  PieChartSectionData _section(
    BuildContext context,
    BreakdownPieSlice slice,
    int total, {
    required bool selected,
    required bool hasSelection,
    required double radius,
  }) {
    final value = slice.amountCents.abs().toDouble();
    final pct = total <= 0 ? 0.0 : (value / total) * 100;
    // Keep a constant radius — exploding the selected slice (radius/border
    // changes) causes jagged gaps with fl_chart + sectionsSpace.
    final color = !hasSelection || selected
        ? slice.color
        : slice.color.withValues(alpha: 0.38);
    return PieChartSectionData(
      value: value <= 0 ? 0.0001 : value,
      color: color,
      radius: radius,
      title: pct >= 9 ? '${pct.toStringAsFixed(0)}%' : '',
      titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Colors.white.withValues(alpha: !hasSelection || selected ? 1 : 0.7),
        fontWeight: FontWeight.w800,
        fontSize: selected ? 12 : 11,
        shadows: const [
          Shadow(
            color: Color(0x99000000),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      borderSide: BorderSide.none,
    );
  }
}

class _DefaultLegendRow extends StatelessWidget {
  const _DefaultLegendRow({
    required this.slice,
    required this.total,
    required this.currencyCode,
    required this.selected,
    required this.onTap,
  });

  final BreakdownPieSlice slice;
  final int total;
  final String currencyCode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final pct = total <= 0
        ? 0
        : ((slice.amountCents.abs() / total) * 100).round();
    final onIcon = ThemeData.estimateBrightnessForColor(slice.color) ==
            Brightness.dark
        ? Colors.white
        : const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: selected
            ? slice.color.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: slice.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    slice.icon ?? Icons.circle,
                    size: 16,
                    color: onIcon,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: UserText(
                    slice.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '$pct%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  CurrencyFormatter.formatCents(
                    slice.amountCents.abs(),
                    currencyCode,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
