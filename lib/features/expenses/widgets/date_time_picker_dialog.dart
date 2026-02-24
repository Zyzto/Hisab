import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shows a combined date and time picker dialog.
/// Returns the selected [DateTime] (local) on OK, or null if cancelled.
/// [use24h] when true forces 24-hour time; when false forces 12-hour AM/PM; when null uses [MediaQuery.alwaysUse24HourFormatOf].
Future<DateTime?> showDateTimePickerDialog(
  BuildContext context, {
  required DateTime initial,
  bool? use24h,
}) async {
  return showDialog<DateTime>(
    context: context,
    builder: (ctx) => _DateTimePickerDialog(initial: initial, use24h: use24h),
  );
}

/// Single dialog: calendar on top, time selector below, Cancel/OK. No Start/End tabs.
class _DateTimePickerDialog extends StatefulWidget {
  final DateTime initial;
  final bool? use24h;

  const _DateTimePickerDialog({required this.initial, this.use24h});

  @override
  State<_DateTimePickerDialog> createState() => _DateTimePickerDialogState();
}

class _DateTimePickerDialogState extends State<_DateTimePickerDialog> {
  late DateTime _selectedDate;
  /// Hour in 24h (0-23). Used for both 24h and 12h; in 12h we derive display from this.
  late int _hour24;
  late int _minute;
  bool _isAm = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initial.year,
      widget.initial.month,
      widget.initial.day,
    );
    _hour24 = widget.initial.hour;
    _minute = widget.initial.minute;
    _isAm = widget.initial.hour < 12;
  }

  /// 12h display value: 12 for 0 or 12, 1-11 for 1-11 and 13-23.
  int get _hour12Value =>
      _hour24 == 0 ? 12 : (_hour24 <= 12 ? _hour24 : _hour24 - 12);

  /// Converts 12h display (1-12) + AM/PM to 24h (0-23).
  static int _hour24From12h(int hour12, bool isAm) {
    if (hour12 == 12) return isAm ? 0 : 12;
    return isAm ? hour12 : hour12 + 12;
  }

  @override
  Widget build(BuildContext context) {
    final use24h = widget.use24h ?? MediaQuery.alwaysUse24HourFormatOf(context);
    return AlertDialog(
      title: Text('date_and_time'.tr()),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CalendarDatePicker(
                key: ValueKey('${_selectedDate.year}-${_selectedDate.month}'),
                initialDate: _selectedDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                currentDate: _selectedDate,
                onDateChanged: (d) => setState(() => _selectedDate = d),
              ),
              Semantics(
                label: 'time'.tr(),
                value: () {
                  final t = DateTime(2000, 1, 1, _hour24, _minute);
                  return use24h
                      ? DateFormat.Hm().format(t)
                      : DateFormat.jm().format(t);
                }(),
                readOnly: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TimeColumn<int>(
                          items: use24h
                              ? List.generate(24, (i) => i)
                              : List.generate(12, (i) => i == 0 ? 12 : i),
                          value: use24h ? _hour24 : _hour12Value,
                          onChanged: (v) => setState(() {
                            if (use24h) {
                              _hour24 = v;
                            } else {
                              _hour24 = _DateTimePickerDialogState._hour24From12h(
                                  v, _isAm);
                            }
                          }),
                          format: (v) => '$v',
                          semanticLabel: 'hour'.tr(),
                        ),
                        const SizedBox(width: 8),
                        _TimeColumn<int>(
                          items: List.generate(60, (i) => i),
                          value: _minute,
                          onChanged: (v) => setState(() => _minute = v),
                          format: (v) => v.toString().padLeft(2, '0'),
                          semanticLabel: 'minute'.tr(),
                        ),
                        if (!use24h) ...[
                          const SizedBox(width: 8),
                          _TimeColumn<DayPeriod>(
                            items: const [DayPeriod.am, DayPeriod.pm],
                            value: _isAm ? DayPeriod.am : DayPeriod.pm,
                            onChanged: (v) =>
                                setState(() => _isAm = v == DayPeriod.am),
                            format: (v) => v == DayPeriod.am ? 'AM' : 'PM',
                            semanticLabel: 'period'.tr(),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  final now = DateTime.now();
                  setState(() {
                    _selectedDate = DateTime(now.year, now.month, now.day);
                    _hour24 = now.hour;
                    _minute = now.minute;
                    _isAm = now.hour < 12;
                  });
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.today_outlined, size: 18),
                label: Text('today'.tr()),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('cancel'.tr()),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      DateTime(
                        _selectedDate.year,
                        _selectedDate.month,
                        _selectedDate.day,
                        _hour24,
                        _minute,
                      ),
                    );
                  },
                  child: Text('ok'.tr()),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeColumn<T> extends StatefulWidget {
  final List<T> items;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) format;
  final String? semanticLabel;

  const _TimeColumn({
    required this.items,
    required this.value,
    required this.onChanged,
    required this.format,
    this.semanticLabel,
  });

  @override
  State<_TimeColumn<T>> createState() => _TimeColumnState<T>();
}

class _TimeColumnState<T> extends State<_TimeColumn<T>> {
  static const double _itemExtent = 36;
  static const double _columnWidth = 60;
  static const double _columnHeight = 128;

  late FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    final index = widget.items.indexOf(widget.value).clamp(0, widget.items.length - 1);
    _controller = FixedExtentScrollController(initialItem: index);
  }

  @override
  void didUpdateWidget(covariant _TimeColumn<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final newIndex = widget.items.indexOf(widget.value).clamp(0, widget.items.length - 1);
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
    final isDark = theme.brightness == Brightness.dark;
    final child = SizedBox(
      width: _columnWidth,
      height: _columnHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Wheel with visible track background
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ListWheelScrollView.useDelegate(
              controller: _controller,
              itemExtent: _itemExtent,
              diameterRatio: 1.4,
              perspective: 0.003,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (i) => widget.onChanged(widget.items[i]),
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: widget.items.length,
                builder: (context, index) {
                  final item = widget.items[index];
                  final selected = item == widget.value;
                  return Center(
                    child: Text(
                      widget.format(item),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: selected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: selected ? 1 : 0.6,
                              ),
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Selection strip over the centered row (drawn on top, non-interactive)
          Positioned(
            left: 10,
            right: 10,
            top: (_columnHeight - _itemExtent) / 2,
            height: _itemExtent,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                      : theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
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
