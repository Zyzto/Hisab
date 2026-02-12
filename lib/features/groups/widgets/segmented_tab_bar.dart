import 'package:flutter/material.dart';

/// A self-contained segmented tab bar that only rebuilds itself.
/// Uses [TabController] for [TabBarView] sync; manages its own selected index
/// so the parent page never rebuilds on tab change (no ink flash, no delay).
///
/// Optionally pass [currentIndexNotifier] so the parent can react (e.g. FAB)
/// without watching the controller or rebuilding the whole page.
class SegmentedTabBar extends StatefulWidget {
  const SegmentedTabBar({
    super.key,
    required this.controller,
    required this.labels,
    this.currentIndexNotifier,
    this.duration = const Duration(milliseconds: 150),
  });

  final TabController controller;
  final List<String> labels;
  final ValueNotifier<int>? currentIndexNotifier;
  final Duration duration;

  @override
  State<SegmentedTabBar> createState() => _SegmentedTabBarState();
}

class _SegmentedTabBarState extends State<SegmentedTabBar> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.controller.index;
    widget.controller.addListener(_onControllerChanged);
    widget.currentIndexNotifier?.value = _selectedIndex;
  }

  @override
  void didUpdateWidget(SegmentedTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _selectedIndex = widget.controller.index;
      widget.currentIndexNotifier?.value = _selectedIndex;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!widget.controller.indexIsChanging &&
        widget.controller.index != _selectedIndex) {
      setState(() {
        _selectedIndex = widget.controller.index;
        widget.currentIndexNotifier?.value = _selectedIndex;
      });
    }
  }

  void _onSegmentTap(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
      widget.currentIndexNotifier?.value = index;
    });
    widget.controller.animateTo(index, duration: widget.duration);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap:
              () {}, // Absorb tap at bar level; segments handle via GestureDetector
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: List.generate(widget.labels.length, (i) {
                final selected = _selectedIndex == i;
                return Expanded(
                  child: _Segment(
                    label: widget.labels[i],
                    selected: selected,
                    theme: theme,
                    duration: widget.duration,
                    onTap: () => _onSegmentTap(i),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single segment: GestureDetector only; no Material/InkWell so no ink. Bar-level InkWell absorbs ink.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.theme,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final ThemeData theme;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: selected ? duration : Duration.zero,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
