import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// How [MonthGalleryCalendar] paints day selection.
sealed class MonthGallerySelection {
  const MonthGallerySelection();
}

/// Single selected day (expense create/edit).
class MonthGallerySingleSelection extends MonthGallerySelection {
  const MonthGallerySingleSelection(this.selected);

  final DateTime? selected;
}

/// Inclusive date range (expenses list filter).
class MonthGalleryRangeSelection extends MonthGallerySelection {
  const MonthGalleryRangeSelection({this.start, this.end});

  final DateTime? start;
  final DateTime? end;
}

DateTime monthGalleryDateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool monthGallerySameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Swipeable month gallery with Monday-first grid.
class MonthGalleryCalendar extends StatefulWidget {
  const MonthGalleryCalendar({
    super.key,
    required this.visibleMonth,
    required this.firstDate,
    required this.lastDate,
    required this.selection,
    required this.onDayTap,
    required this.onMonthChanged,
    this.footer,
  });

  final DateTime visibleMonth;
  final DateTime firstDate;
  final DateTime lastDate;
  final MonthGallerySelection selection;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onMonthChanged;

  /// Optional text/widget under the day grid (e.g. range hint).
  final Widget? footer;

  @override
  State<MonthGalleryCalendar> createState() => _MonthGalleryCalendarState();
}

class _MonthGalleryCalendarState extends State<MonthGalleryCalendar> {
  static const double _rowHeight = 40;
  static const int _maxRows = 6;

  late PageController _pageController;
  late List<DateTime> _months;
  late int _pageIndex;
  bool _syncingFromParent = false;

  static List<DateTime> _monthsBetween(DateTime first, DateTime last) {
    final months = <DateTime>[];
    var cursor = DateTime(first.year, first.month);
    final end = DateTime(last.year, last.month);
    while (!cursor.isAfter(end)) {
      months.add(cursor);
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return months.isEmpty ? [DateTime(first.year, first.month)] : months;
  }

  int _indexFor(DateTime month) {
    final i = _months.indexWhere(
      (m) => m.year == month.year && m.month == month.month,
    );
    return i < 0 ? 0 : i;
  }

  bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  @override
  void initState() {
    super.initState();
    _months = _monthsBetween(widget.firstDate, widget.lastDate);
    _pageIndex = _indexFor(widget.visibleMonth);
    _pageController = PageController(initialPage: _pageIndex);
  }

  @override
  void didUpdateWidget(covariant MonthGalleryCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameMonth(oldWidget.firstDate, widget.firstDate) ||
        !_sameMonth(oldWidget.lastDate, widget.lastDate)) {
      _months = _monthsBetween(widget.firstDate, widget.lastDate);
    }
    final next = _indexFor(widget.visibleMonth);
    if (next == _pageIndex) return;
    _pageIndex = next;
    _syncingFromParent = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) {
        _syncingFromParent = false;
        return;
      }
      _pageController
          .animateToPage(
            next,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(() => _syncingFromParent = false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _months.length) return;
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final month = _months[_pageIndex.clamp(0, _months.length - 1)];
    final monthLabel = DateFormat.yMMMM().format(month);
    final canPrev = _pageIndex > 0;
    final canNext = _pageIndex < _months.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                monthLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
              onPressed: canPrev ? () => _goToPage(_pageIndex - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
              onPressed: canNext ? () => _goToPage(_pageIndex + 1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    DateFormat.E().format(DateTime(2024, 1, 1 + i)),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: _rowHeight * _maxRows,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _months.length,
            physics: const BouncingScrollPhysics(
              parent: PageScrollPhysics(),
            ),
            onPageChanged: (index) {
              setState(() => _pageIndex = index);
              if (!_syncingFromParent) {
                widget.onMonthChanged(_months[index]);
              }
            },
            itemBuilder: (context, index) {
              final pageMonth = _months[index];
              return _MonthDaysGrid(
                year: pageMonth.year,
                month: pageMonth.month,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                selection: widget.selection,
                onDayTap: widget.onDayTap,
                rowHeight: _rowHeight,
                maxRows: _maxRows,
              );
            },
          ),
        ),
        if (widget.footer != null) ...[
          const SizedBox(height: 8),
          widget.footer!,
        ],
      ],
    );
  }
}

class _MonthDaysGrid extends StatelessWidget {
  const _MonthDaysGrid({
    required this.year,
    required this.month,
    required this.firstDate,
    required this.lastDate,
    required this.selection,
    required this.onDayTap,
    required this.rowHeight,
    required this.maxRows,
  });

  final int year;
  final int month;
  final DateTime firstDate;
  final DateTime lastDate;
  final MonthGallerySelection selection;
  final ValueChanged<DateTime> onDayTap;
  final double rowHeight;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final monthStart = DateTime(year, month);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leading = (monthStart.weekday - DateTime.monday) % 7;

    return Column(
      children: [
        for (var row = 0; row < maxRows; row++)
          SizedBox(
            height: rowHeight,
            child: Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _DayCell(
                      dayNum: row * 7 + col - leading + 1,
                      daysInMonth: daysInMonth,
                      year: year,
                      month: month,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      selection: selection,
                      onDayTap: onDayTap,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.dayNum,
    required this.daysInMonth,
    required this.year,
    required this.month,
    required this.firstDate,
    required this.lastDate,
    required this.selection,
    required this.onDayTap,
  });

  final int dayNum;
  final int daysInMonth;
  final int year;
  final int month;
  final DateTime firstDate;
  final DateTime lastDate;
  final MonthGallerySelection selection;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final day = DateTime(year, month, dayNum);
    final enabled = !day.isBefore(firstDate) && !day.isAfter(lastDate);

    final bool isEndpoint;
    final bool inRange;
    switch (selection) {
      case MonthGallerySingleSelection(:final selected):
        isEndpoint = selected != null && monthGallerySameDay(day, selected);
        inRange = false;
      case MonthGalleryRangeSelection(:final start, :final end):
        final rangeStart = start;
        final rangeEnd = end ?? start;
        final isStart =
            rangeStart != null && monthGallerySameDay(day, rangeStart);
        final isEnd = rangeEnd != null && monthGallerySameDay(day, rangeEnd);
        isEndpoint = isStart || isEnd;
        inRange = rangeStart != null &&
            rangeEnd != null &&
            !day.isBefore(rangeStart) &&
            !day.isAfter(rangeEnd);
    }

    final bg = isEndpoint
        ? cs.primary
        : inRange
            ? cs.primary.withValues(alpha: 0.18)
            : null;
    final fg = !enabled
        ? cs.onSurface.withValues(alpha: 0.28)
        : isEndpoint
            ? cs.onPrimary
            : cs.onSurface;

    final BorderRadius radius;
    if (selection case MonthGalleryRangeSelection(:final start, :final end)) {
      final rangeStart = start;
      final rangeEnd = end ?? start;
      final isStart =
          rangeStart != null && monthGallerySameDay(day, rangeStart);
      final isEnd = rangeEnd != null && monthGallerySameDay(day, rangeEnd);
      if (isStart && isEnd) {
        radius = BorderRadius.circular(20);
      } else if (isStart) {
        radius = const BorderRadius.horizontal(left: Radius.circular(20));
      } else if (isEnd) {
        radius = const BorderRadius.horizontal(right: Radius.circular(20));
      } else {
        radius = BorderRadius.circular(8);
      }
    } else {
      radius = BorderRadius.circular(20);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: bg ?? Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? () => onDayTap(day) : null,
          child: Center(
            child: Text(
              '$dayNum',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: fg,
                fontWeight: isEndpoint ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
