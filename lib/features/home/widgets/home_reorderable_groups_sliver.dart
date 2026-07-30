import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/theme_config.dart';
import '../../../domain/domain.dart';
import '../utils/home_list_reorder.dart';

/// Long-press drag reorder that keeps list rows in place.
///
/// While dragging, a floating card follows the finger and a slim insert line
/// shows the drop slot — other items do not shuffle aside.
class HomeReorderableGroupsSliver extends StatefulWidget {
  const HomeReorderableGroupsSliver({
    super.key,
    required this.groups,
    required this.pinnedIds,
    required this.itemBuilder,
    required this.onReorderComplete,
  });

  final List<Group> groups;
  final Set<String> pinnedIds;
  final Widget Function(BuildContext context, Group group) itemBuilder;
  final void Function(List<Group> newOrder) onReorderComplete;

  @override
  State<HomeReorderableGroupsSliver> createState() =>
      _HomeReorderableGroupsSliverState();
}

class _HomeReorderableGroupsSliverState
    extends State<HomeReorderableGroupsSliver> {
  String? _draggingId;
  int? _insertBeforeIndex;

  bool _isPinned(Group group) => widget.pinnedIds.contains(group.id);

  void _setHover(int insertBefore) {
    if (_insertBeforeIndex == insertBefore) return;
    setState(() => _insertBeforeIndex = insertBefore);
  }

  void _clearDrag() {
    if (_draggingId == null && _insertBeforeIndex == null) return;
    setState(() {
      _draggingId = null;
      _insertBeforeIndex = null;
    });
  }

  void _commitDrop(Group data) {
    final from = widget.groups.indexWhere((g) => g.id == data.id);
    final insertBefore = _insertBeforeIndex;
    _clearDrag();
    if (from < 0 || insertBefore == null) return;

    final next = moveToInsertSlot<Group>(
      items: widget.groups,
      fromIndex: from,
      insertBeforeIndex: insertBefore,
      isPinned: _isPinned,
    );
    if (_sameIds(next, widget.groups)) return;
    HapticFeedback.selectionClick();
    widget.onReorderComplete(next);
  }

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final group = widget.groups[index];
          final showLineBefore =
              _draggingId != null && _insertBeforeIndex == index;
          final showLineAfter =
              _draggingId != null &&
              index == widget.groups.length - 1 &&
              _insertBeforeIndex == widget.groups.length;

          // Overlay the insert line so rows never grow while dragging.
          return Stack(
            key: ValueKey(group.id),
            clipBehavior: Clip.none,
            children: [
              _HoldDragGroupRow(
                group: group,
                index: index,
                isDragging: _draggingId == group.id,
                itemBuilder: widget.itemBuilder,
                onDragStarted: () {
                  HapticFeedback.mediumImpact();
                  setState(() {
                    _draggingId = group.id;
                    _insertBeforeIndex = index;
                  });
                },
                onDragEnded: _clearDrag,
                onHoverInsertBefore: _setHover,
                onAccept: _commitDrop,
              ),
              if (showLineBefore)
                const Positioned(
                  top: -1,
                  left: 28,
                  right: 28,
                  child: _DropInsertLine(),
                ),
              if (showLineAfter)
                const Positioned(
                  bottom: -1,
                  left: 28,
                  right: 28,
                  child: _DropInsertLine(),
                ),
            ],
          );
        },
        childCount: widget.groups.length,
        addAutomaticKeepAlives: false,
      ),
    );
  }

  static bool _sameIds(List<Group> a, List<Group> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }
}

class _HoldDragGroupRow extends StatelessWidget {
  const _HoldDragGroupRow({
    required this.group,
    required this.index,
    required this.isDragging,
    required this.itemBuilder,
    required this.onDragStarted,
    required this.onDragEnded,
    required this.onHoverInsertBefore,
    required this.onAccept,
  });

  final Group group;
  final int index;
  final bool isDragging;
  final Widget Function(BuildContext context, Group group) itemBuilder;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnded;
  final ValueChanged<int> onHoverInsertBefore;
  final ValueChanged<Group> onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Match ConstrainedContent row width — never the full window.
        final rowWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        return DragTarget<Group>(
          onWillAcceptWithDetails: (_) => true,
          onMove: (details) {
            final box = context.findRenderObject() as RenderBox?;
            if (box == null || !box.hasSize) return;
            final local = box.globalToLocal(details.offset);
            final before = local.dy < box.size.height / 2;
            onHoverInsertBefore(before ? index : index + 1);
          },
          onAcceptWithDetails: (details) => onAccept(details.data),
          builder: (context, candidate, rejected) {
            return LongPressDraggable<Group>(
              data: group,
              delay: const Duration(milliseconds: 280),
              hapticFeedbackOnStart: false,
              onDragStarted: onDragStarted,
              onDragEnd: (details) {
                if (!details.wasAccepted) onDragEnded();
              },
              feedback: _DragFeedbackCard(
                width: rowWidth,
                child: itemBuilder(context, group),
              ),
              childWhenDragging: IgnorePointer(
                child: Opacity(
                  opacity: 0.34,
                  child: itemBuilder(context, group),
                ),
              ),
              child: Semantics(
                label: '${group.name}. ${'home_list_hold_to_reorder'.tr()}',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
                    boxShadow: candidate.isNotEmpty && !isDragging
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.10,
                              ),
                              blurRadius: 8,
                            ),
                          ]
                        : const [],
                  ),
                  child: itemBuilder(context, group),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DragFeedbackCard extends StatelessWidget {
  const _DragFeedbackCard({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      type: MaterialType.transparency,
      child: Transform.rotate(
        angle: -0.02,
        child: SizedBox(
          width: width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.26),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.14),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _DropInsertLine extends StatelessWidget {
  const _DropInsertLine();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.35),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}
