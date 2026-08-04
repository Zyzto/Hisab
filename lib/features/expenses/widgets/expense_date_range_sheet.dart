import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/widgets/sheet_helpers.dart';
import 'month_gallery_calendar.dart';

/// Result of [showExpenseDateRangeSheet].
///
/// [range] is null when the user chose “all dates” (reset).
class ExpenseDateRangeSheetResult {
  const ExpenseDateRangeSheetResult(this.range);

  final DateTimeRange? range;
}

DateTime _dateOnly(DateTime d) => monthGalleryDateOnly(d);

bool _sameDay(DateTime a, DateTime b) => monthGallerySameDay(a, b);

DateTimeRange _clampRange(
  DateTimeRange range, {
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  var start = _dateOnly(range.start);
  var end = _dateOnly(range.end);
  if (start.isBefore(firstDate)) start = firstDate;
  if (end.isAfter(lastDate)) end = lastDate;
  if (end.isBefore(start)) end = start;
  return DateTimeRange(start: start, end: end);
}

/// Formats a filter chip / summary label for a date range (single day or span).
String formatExpenseDateRangeLabel(DateTimeRange range) {
  final start = _dateOnly(range.start);
  final end = _dateOnly(range.end);
  if (_sameDay(start, end)) return DateFormat.yMMMd().format(start);
  if (start.year == end.year) {
    return '${DateFormat.MMMd().format(start)} – ${DateFormat.MMMd().format(end)}';
  }
  return '${DateFormat.yMMMd().format(start)} – ${DateFormat.yMMMd().format(end)}';
}

/// Preset + calendar sheet for a single day or date range.
/// Returns null if dismissed without applying.
Future<ExpenseDateRangeSheetResult?> showExpenseDateRangeSheet(
  BuildContext context, {
  DateTimeRange? initial,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  final first = _dateOnly(firstDate);
  final last = _dateOnly(lastDate);
  final isTablet = LayoutBreakpoints.isTabletOrWider(context);
  return showResponsiveSheet<ExpenseDateRangeSheetResult>(
    context: context,
    title: 'expenses_date_range'.tr(),
    maxHeight: MediaQuery.of(context).size.height * (isTablet ? 0.85 : 0.92),
    maxWidth: isTablet ? 720 : null,
    isScrollControlled: true,
    centerInFullViewport: true,
    child: Builder(
      builder: (ctx) => _ExpenseDateRangeSheetBody(
        sheetContext: ctx,
        initial: initial == null
            ? null
            : _clampRange(initial, firstDate: first, lastDate: last),
        firstDate: first,
        lastDate: last,
        showTitleInBody: !isTablet,
      ),
    ),
  );
}

class _ExpenseDateRangeSheetBody extends StatefulWidget {
  const _ExpenseDateRangeSheetBody({
    required this.sheetContext,
    required this.initial,
    required this.firstDate,
    required this.lastDate,
    required this.showTitleInBody,
  });

  final BuildContext sheetContext;
  final DateTimeRange? initial;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool showTitleInBody;

  @override
  State<_ExpenseDateRangeSheetBody> createState() =>
      _ExpenseDateRangeSheetBodyState();
}

class _ExpenseDateRangeSheetBodyState extends State<_ExpenseDateRangeSheetBody> {
  DateTime? _start;
  DateTime? _end;
  late DateTime _visibleMonth;
  String? _activePresetId;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _start = _dateOnly(initial.start);
      _end = _dateOnly(initial.end);
      _visibleMonth = DateTime(_end!.year, _end!.month);
    } else {
      _visibleMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    }
  }

  DateTimeRange? get _pendingRange {
    if (_start == null) return null;
    return DateTimeRange(start: _start!, end: _end ?? _start!);
  }

  void _applyPreset(String id, DateTimeRange range) {
    final clamped = _clampRange(
      range,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
    );
    setState(() {
      _activePresetId = id;
      _start = _dateOnly(clamped.start);
      _end = _dateOnly(clamped.end);
      _visibleMonth = DateTime(_end!.year, _end!.month);
    });
  }

  void _reset() {
    setState(() {
      _activePresetId = 'all';
      _start = null;
      _end = null;
    });
  }

  void _onDayTap(DateTime day) {
    final d = _dateOnly(day);
    if (d.isBefore(widget.firstDate) || d.isAfter(widget.lastDate)) return;

    setState(() {
      _activePresetId = null;
      if (_start == null || _end != null) {
        _start = d;
        _end = null;
      } else if (d.isBefore(_start!)) {
        _end = _start;
        _start = d;
      } else {
        _end = d;
      }
    });
  }

  void _pop(ExpenseDateRangeSheetResult result) {
    final navigator = Navigator.of(widget.sheetContext, rootNavigator: true);
    if (navigator.canPop()) navigator.pop(result);
  }

  List<({String id, String label, DateTimeRange range})> _presets(DateTime now) {
    final today = _dateOnly(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeekStart = today.subtract(const Duration(days: 6));
    final lastMonthStart = DateTime(today.year, today.month - 1, 1);
    final lastMonthEnd = DateTime(today.year, today.month, 0);
    final currentQuarter = (today.month - 1) ~/ 3;
    final prevQuarter = currentQuarter == 0 ? 3 : currentQuarter - 1;
    final prevQuarterYear = currentQuarter == 0 ? today.year - 1 : today.year;
    final prevQuarterStartMonth = prevQuarter * 3 + 1;

    return [
      (
        id: 'today',
        label: 'today'.tr(),
        range: DateTimeRange(start: today, end: today),
      ),
      (
        id: 'yesterday',
        label: 'yesterday'.tr(),
        range: DateTimeRange(start: yesterday, end: yesterday),
      ),
      (
        id: 'last_week',
        label: 'expenses_date_last_week'.tr(),
        range: DateTimeRange(start: lastWeekStart, end: today),
      ),
      (
        id: 'last_month',
        label: 'expenses_date_last_month'.tr(),
        range: DateTimeRange(start: lastMonthStart, end: lastMonthEnd),
      ),
      (
        id: 'last_quarter',
        label: 'expenses_date_last_quarter'.tr(),
        range: DateTimeRange(
          start: DateTime(prevQuarterYear, prevQuarterStartMonth, 1),
          end: DateTime(prevQuarterYear, prevQuarterStartMonth + 3, 0),
        ),
      ),
    ];
  }

  Widget _presetList(
    List<({String id, String label, DateTimeRange range})> presets,
    ColorScheme cs,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final preset in presets)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _PresetTile(
              label: preset.label,
              selected: _activePresetId == preset.id,
              onTap: () => _applyPreset(preset.id, preset.range),
            ),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _reset,
          style: TextButton.styleFrom(
            foregroundColor: cs.primary,
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          child: Text('expenses_date_reset'.tr()),
        ),
      ],
    );
  }

  Widget _presetChips(
    List<({String id, String label, DateTimeRange range})> presets,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in presets)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilterChip(
                label: Text(preset.label),
                selected: _activePresetId == preset.id,
                onSelected: (_) => _applyPreset(preset.id, preset.range),
                showCheckmark: false,
              ),
            ),
          TextButton(
            onPressed: _reset,
            child: Text('expenses_date_reset'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 560;
    final presets = _presets(DateTime.now());
    final pending = _pendingRange;
    final summary = pending == null
        ? 'expenses_all_dates'.tr()
        : formatExpenseDateRangeLabel(pending);

    final calendar = MonthGalleryCalendar(
      visibleMonth: _visibleMonth,
      firstDate: widget.firstDate,
      lastDate: widget.lastDate,
      selection: MonthGalleryRangeSelection(start: _start, end: _end),
      onDayTap: _onDayTap,
      onMonthChanged: (month) => setState(() => _visibleMonth = month),
      footer: Text(
        'expenses_date_range_hint'.tr(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: cs.onSurfaceVariant,
        ),
      ),
    );

    return buildSheetShell(
      widget.sheetContext,
      title: 'expenses_date_range'.tr(),
      showTitleInBody: widget.showTitleInBody,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.date_range_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 148, child: _presetList(presets, cs)),
                const SizedBox(width: 12),
                Expanded(child: calendar),
              ],
            )
          else ...[
            _presetChips(presets),
            const SizedBox(height: 12),
            calendar,
          ],
        ],
      ),
      actions: [
        if (widget.showTitleInBody)
          TextButton(
            onPressed: () {
              final navigator =
                  Navigator.of(widget.sheetContext, rootNavigator: true);
              if (navigator.canPop()) navigator.pop();
            },
            child: Text('cancel'.tr()),
          ),
        FilledButton(
          onPressed: () {
            if (_activePresetId == 'all' || _start == null) {
              _pop(const ExpenseDateRangeSheetResult(null));
              return;
            }
            _pop(ExpenseDateRangeSheetResult(_pendingRange));
          },
          child: Text('done'.tr()),
        ),
      ],
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: selected
          ? cs.primaryContainer.withValues(alpha: 0.75)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
