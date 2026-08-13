import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/layout/layout_breakpoints.dart';
import '../../../core/layout/responsive_sheet.dart';
import '../../../core/widgets/sheet_helpers.dart';
import 'month_gallery_calendar.dart';

/// Shows a combined date and time picker as a responsive sheet.
/// Returns the selected [DateTime] (local) on OK, or null if cancelled.
/// [use24h] when true forces 24-hour time; when false forces 12-hour AM/PM; when null uses [MediaQuery.alwaysUse24HourFormatOf].
Future<DateTime?> showDateTimePickerDialog(
  BuildContext context, {
  required DateTime initial,
  bool? use24h,
  DateTime? maxDate,
}) async {
  final controller = _DateTimePickerTopBarController();
  final isTabletOrWider = LayoutBreakpoints.isTabletOrWider(context);
  final effectiveMaxDate = maxDate ?? DateTime.now();
  return showResponsiveSheet<DateTime>(
    context: context,
    title: 'date_and_time'.tr(),
    tabletTopBarAction: isTabletOrWider
        ? FilledButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              controller.setToNow();
            },
            child: Text('today'.tr()),
          )
        : null,
    maxHeight: MediaQuery.of(context).size.height * 0.85,
    isScrollControlled: true,
    centerInFullViewport: true,
    child: Builder(
      builder: (ctx) => _DateTimePickerSheetContent(
        initial: initial,
        use24h: use24h,
        maxDate: effectiveMaxDate,
        topBarController: controller,
        sheetContext: ctx,
      ),
    ),
  );
}

class _DateTimePickerTopBarController {
  VoidCallback? _setToNow;

  void bindSetToNow(VoidCallback callback) {
    _setToNow = callback;
  }

  void unbindSetToNow() {
    _setToNow = null;
  }

  void setToNow() {
    _setToNow?.call();
  }
}

/// Sheet content: summary, presets, swipeable calendar, time wheels, Cancel/OK.
class _DateTimePickerSheetContent extends StatefulWidget {
  const _DateTimePickerSheetContent({
    required this.initial,
    this.use24h,
    required this.maxDate,
    required this.topBarController,
    required this.sheetContext,
  });

  final DateTime initial;
  final bool? use24h;
  final DateTime maxDate;
  final _DateTimePickerTopBarController topBarController;
  final BuildContext sheetContext;

  @override
  State<_DateTimePickerSheetContent> createState() =>
      _DateTimePickerSheetContentState();
}

class _DateTimePickerSheetContentState
    extends State<_DateTimePickerSheetContent> {
  late DateTime _selectedDate;
  late DateTime _firstDateOnly;
  late DateTime _maxDateOnly;
  late DateTime _visibleMonth;

  /// Hour in 24h (0-23). Used for both 24h and 12h; in 12h we derive display from this.
  late int _hour24;
  late int _minute;
  bool _isAm = true;
  String? _activePresetId;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    final maxDate = widget.maxDate;
    _maxDateOnly = monthGalleryDateOnly(maxDate);
    final initialDateOnly = monthGalleryDateOnly(i);
    _selectedDate = initialDateOnly.isAfter(_maxDateOnly)
        ? _maxDateOnly
        : initialDateOnly;

    final fiveYearsAgo = DateTime(
      _maxDateOnly.year - 5,
      _maxDateOnly.month,
      _maxDateOnly.day,
    );
    final initialMonth = DateTime(_selectedDate.year, _selectedDate.month);
    final boundMonth = DateTime(fiveYearsAgo.year, fiveYearsAgo.month);
    _firstDateOnly = initialMonth.isBefore(boundMonth)
        ? initialMonth
        : boundMonth;

    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _hour24 = i.hour;
    _minute = i.minute;
    _isAm = i.hour < 12;
    widget.topBarController.bindSetToNow(_setToNow);
  }

  @override
  void dispose() {
    widget.topBarController.unbindSetToNow();
    super.dispose();
  }

  void _setToNow() {
    final now = DateTime.now();
    setState(() {
      _activePresetId = 'today';
      _selectedDate = monthGalleryDateOnly(now);
      _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
      _hour24 = now.hour;
      _minute = now.minute;
      _isAm = now.hour < 12;
    });
  }

  void _setToYesterday() {
    final yesterday = monthGalleryDateOnly(
      DateTime.now(),
    ).subtract(const Duration(days: 1));
    final day = yesterday.isBefore(_firstDateOnly)
        ? _firstDateOnly
        : (yesterday.isAfter(_maxDateOnly) ? _maxDateOnly : yesterday);
    setState(() {
      _activePresetId = 'yesterday';
      _selectedDate = day;
      _visibleMonth = DateTime(day.year, day.month);
    });
  }

  void _onDayTap(DateTime day) {
    final d = monthGalleryDateOnly(day);
    if (d.isBefore(_firstDateOnly) || d.isAfter(_maxDateOnly)) return;
    setState(() {
      _activePresetId = null;
      _selectedDate = d;
      _visibleMonth = DateTime(d.year, d.month);
    });
  }

  /// 12h display value: 12 for 0 or 12, 1-11 for 1-11 and 13-23.
  int get _hour12Value =>
      _hour24 == 0 ? 12 : (_hour24 <= 12 ? _hour24 : _hour24 - 12);

  /// Converts 12h display (1-12) + AM/PM to 24h (0-23).
  static int _hour24From12h(int hour12, bool isAm) {
    if (hour12 == 12) return isAm ? 0 : 12;
    return isAm ? hour12 : hour12 + 12;
  }

  DateTime get _combined => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    _hour24,
    _minute,
  );

  String _summaryLabel(bool use24h) {
    final format = use24h
        ? DateFormat.yMMMd().add_Hm()
        : DateFormat.yMMMd().add_jm();
    return format.format(_combined);
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.sheetContext;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final use24h = widget.use24h ?? MediaQuery.alwaysUse24HourFormatOf(context);
    final isTabletOrWider = LayoutBreakpoints.isTabletOrWider(context);

    return buildSheetShell(
      ctx,
      title: 'date_and_time'.tr(),
      showTitleInBody: !isTabletOrWider,
      body: Column(
        mainAxisSize: MainAxisSize.min,
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
                Icon(Icons.event_rounded, color: cs.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      _summaryLabel(use24h),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: Text('today'.tr()),
                  selected: _activePresetId == 'today',
                  showCheckmark: false,
                  onSelected: (_) {
                    HapticFeedback.lightImpact();
                    _setToNow();
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('yesterday'.tr()),
                  selected: _activePresetId == 'yesterday',
                  showCheckmark: false,
                  onSelected: (_) {
                    HapticFeedback.lightImpact();
                    _setToYesterday();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MonthGalleryCalendar(
            visibleMonth: _visibleMonth,
            firstDate: _firstDateOnly,
            lastDate: _maxDateOnly,
            selection: MonthGallerySingleSelection(_selectedDate),
            onDayTap: _onDayTap,
            onMonthChanged: (month) => setState(() => _visibleMonth = month),
          ),
          const SizedBox(height: 16),
          _TimePickerPanel(
            use24h: use24h,
            hour24: _hour24,
            hour12Value: _hour12Value,
            minute: _minute,
            isAm: _isAm,
            onHourChanged: (v) => setState(() {
              _activePresetId = null;
              if (use24h) {
                _hour24 = v;
              } else {
                _hour24 = _hour24From12h(v, _isAm);
              }
            }),
            onMinuteChanged: (v) => setState(() {
              _activePresetId = null;
              _minute = v;
            }),
            onPeriodChanged: (isAm) => setState(() {
              _activePresetId = null;
              _isAm = isAm;
              _hour24 = _hour24From12h(_hour12Value, _isAm);
            }),
          ),
        ],
      ),
      actions: [
        if (!isTabletOrWider)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('cancel'.tr()),
          ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(_combined),
          child: Text('ok'.tr()),
        ),
      ],
    );
  }
}

/// Unified hour / minute (/ AM·PM) wheels in one panel with a shared selection band.
class _TimePickerPanel extends StatelessWidget {
  const _TimePickerPanel({
    required this.use24h,
    required this.hour24,
    required this.hour12Value,
    required this.minute,
    required this.isAm,
    required this.onHourChanged,
    required this.onMinuteChanged,
    required this.onPeriodChanged,
  });

  final bool use24h;
  final int hour24;
  final int hour12Value;
  final int minute;
  final bool isAm;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;
  final ValueChanged<bool> onPeriodChanged;

  static const double _itemExtent = 40;
  static const double _panelHeight = 140;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final timeValue = () {
      final t = DateTime(2000, 1, 1, hour24, minute);
      return use24h ? DateFormat.Hm().format(t) : DateFormat.jm().format(t);
    }();

    final captionStyle = theme.textTheme.labelSmall?.copyWith(
      color: cs.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    const colonSlotWidth = 20.0;

    Widget columnCaption(String label) => Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: captionStyle,
          ),
        );

    // Keep hour:minute order in RTL locales; captions stay aligned to columns.
    return Semantics(
      label: 'time'.tr(),
      value: timeValue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 18,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'time'.tr(),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    columnCaption('hour'.tr()),
                    const SizedBox(width: colonSlotWidth),
                    columnCaption('minute'.tr()),
                    if (!use24h) columnCaption('period'.tr()),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  height: _panelHeight,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 12,
                        right: 12,
                        top: (_panelHeight - _itemExtent) / 2,
                        height: _itemExtent,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeColumn<int>(
                              items: use24h
                                  ? List.generate(24, (i) => i)
                                  : List.generate(12, (i) => i == 0 ? 12 : i),
                              value: use24h ? hour24 : hour12Value,
                              onChanged: onHourChanged,
                              format: (v) => use24h
                                  ? v.toString().padLeft(2, '0')
                                  : '$v',
                              itemExtent: _itemExtent,
                              semanticLabel: 'hour'.tr(),
                            ),
                          ),
                          IgnorePointer(
                            child: SizedBox(
                              width: colonSlotWidth,
                              child: Text(
                                ':',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _TimeColumn<int>(
                              items: List.generate(60, (i) => i),
                              value: minute,
                              onChanged: onMinuteChanged,
                              format: (v) => v.toString().padLeft(2, '0'),
                              itemExtent: _itemExtent,
                              semanticLabel: 'minute'.tr(),
                            ),
                          ),
                          if (!use24h)
                            Expanded(
                              child: _TimeColumn<DayPeriod>(
                                items: const [DayPeriod.am, DayPeriod.pm],
                                value: isAm ? DayPeriod.am : DayPeriod.pm,
                                onChanged: (v) =>
                                    onPeriodChanged(v == DayPeriod.am),
                                format: (v) {
                                  final isAr =
                                      context.locale.languageCode == 'ar';
                                  if (isAr) {
                                    return v == DayPeriod.am ? 'ص' : 'م';
                                  }
                                  return v == DayPeriod.am ? 'AM' : 'PM';
                                },
                                itemExtent: _itemExtent,
                                semanticLabel: 'period'.tr(),
                              ),
                            ),
                        ],
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  cs.surfaceContainerHighest,
                                  cs.surfaceContainerHighest
                                      .withValues(alpha: 0),
                                  cs.surfaceContainerHighest
                                      .withValues(alpha: 0),
                                  cs.surfaceContainerHighest,
                                ],
                                stops: const [0, 0.28, 0.72, 1],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeColumn<T> extends StatefulWidget {
  final List<T> items;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) format;
  final double itemExtent;
  final String? semanticLabel;

  const _TimeColumn({
    required this.items,
    required this.value,
    required this.onChanged,
    required this.format,
    required this.itemExtent,
    this.semanticLabel,
  });

  @override
  State<_TimeColumn<T>> createState() => _TimeColumnState<T>();
}

class _TimeColumnState<T> extends State<_TimeColumn<T>> {
  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    final index = widget.items
        .indexOf(widget.value)
        .clamp(0, widget.items.length - 1);
    _controller = FixedExtentScrollController(initialItem: index);
  }

  @override
  void didUpdateWidget(covariant _TimeColumn<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final newIndex = widget.items
          .indexOf(widget.value)
          .clamp(0, widget.items.length - 1);
      if (_controller.selectedItem != newIndex) {
        // Defer so we don't trigger onSelectedItemChanged (and parent setState) during build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_controller.selectedItem != newIndex) {
            _controller.jumpToItem(newIndex);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = ListWheelScrollView.useDelegate(
      controller: _controller,
      itemExtent: widget.itemExtent,
      diameterRatio: 1.6,
      perspective: 0.002,
      overAndUnderCenterOpacity: 0.35,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: (i) {
        HapticFeedback.selectionClick();
        widget.onChanged(widget.items[i]);
      },
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: widget.items.length,
        builder: (context, index) {
          final item = widget.items[index];
          final selected = item == widget.value;
          return Center(
            child: Text(
              widget.format(item),
              style: theme.textTheme.titleLarge?.copyWith(
                color: selected
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          );
        },
      ),
    );
    if (widget.semanticLabel != null) {
      return Semantics(
        label: widget.semanticLabel,
        value: widget.format(widget.value),
        readOnly: true,
        child: child,
      );
    }
    return child;
  }
}
