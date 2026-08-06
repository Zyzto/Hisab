import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/platform/ui_perf.dart';
import '../../../core/theme/theme_config.dart';
import '../../../domain/domain.dart';
import '../utils/home_list_reorder.dart';

/// Maps a global Y to an insert-before index (0..[itemCount]).
///
/// Past [listTop] → 0. Past [listBottom] → [itemCount].
/// [rowTops] / [rowBottoms] are global Y edges for each list row.
@visibleForTesting
int insertIndexForGlobalY({
  required double globalY,
  required List<double> rowTops,
  required List<double> rowBottoms,
  required double listTop,
  required double listBottom,
}) {
  assert(rowTops.length == rowBottoms.length);
  final n = rowTops.length;
  if (n == 0) return 0;

  if (globalY < listTop || globalY < rowTops.first) return 0;
  if (globalY >= listBottom) return n;

  for (var i = 0; i < n; i++) {
    final top = rowTops[i];
    final bottom = rowBottoms[i];
    final height = bottom - top;
    if (height <= 0) continue;
    final threshold = i == n - 1 ? height * 0.42 : height * 0.5;
    if (globalY < top + threshold) return i;
    if (globalY < bottom) return i + 1;
  }
  return n;
}

class _GeomCache {
  const _GeomCache({
    required this.tops,
    required this.bottoms,
    required this.listTop,
    required this.listBottom,
  });

  final List<double> tops;
  final List<double> bottoms;
  final double listTop;
  final double listBottom;
}

/// Long-press drag reorder that keeps list rows in place.
///
/// While dragging, a floating card follows the finger and a slim insert line
/// shows the drop slot — other items do not shuffle aside. Dragging past the
/// top or bottom clamps to first/last slot. Only groups that belong to this
/// sliver are accepted (Personal/Groups sections cannot steal drops).
///
/// Perf: geometry is cached during a drag; insert-line updates use a
/// [ValueNotifier] so rows are not rebuilt. iOS web uses
/// [UiPerf.preferCheapListDrag] for lighter feedback/placeholders.
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
  final ValueNotifier<int?> _insertBefore = ValueNotifier<int?>(null);

  final Map<int, GlobalKey> _rowKeys = {};
  final GlobalKey _bottomKey = GlobalKey();

  _GeomCache? _geom;
  ScrollPosition? _scrollPosition;

  GlobalKey _rowKey(int index) => _rowKeys.putIfAbsent(index, GlobalKey.new);

  bool _isPinned(Group group) => widget.pinnedIds.contains(group.id);

  bool _belongs(Group group) => widget.groups.any((g) => g.id == group.id);

  void _setHover(int insertBefore) {
    if (_insertBefore.value == insertBefore) return;
    // Selection haptics are noisy/no-op on most web surfaces.
    if (!kIsWeb) {
      HapticFeedback.selectionClick();
    }
    _insertBefore.value = insertBefore;
  }

  void _invalidateGeom() => _geom = null;

  void _clearDrag() {
    _scrollPosition?.removeListener(_invalidateGeom);
    _scrollPosition = null;
    _geom = null;
    if (_draggingId == null && _insertBefore.value == null) return;
    setState(() {
      _draggingId = null;
      _insertBefore.value = null;
    });
  }

  void _commitDrop(Group data) {
    if (!_belongs(data)) return;
    final from = widget.groups.indexWhere((g) => g.id == data.id);
    final insertBefore = _insertBefore.value;
    _clearDrag();
    if (from < 0 || insertBefore == null) return;

    final next = moveToInsertSlot<Group>(
      items: widget.groups,
      fromIndex: from,
      insertBeforeIndex: insertBefore,
      isPinned: _isPinned,
    );
    if (_sameIds(next, widget.groups)) return;
    HapticFeedback.mediumImpact();
    widget.onReorderComplete(next);
  }

  RenderBox? _boxFor(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    return box;
  }

  RenderBox? _boxForRow(int index) => _boxFor(_rowKey(index));

  _GeomCache? _readGeom() {
    final n = widget.groups.length;
    if (n == 0) return null;

    final firstBox = _boxForRow(0);
    if (firstBox == null) return null;
    final listTop = firstBox.localToGlobal(Offset.zero).dy;

    final tops = <double>[];
    final bottoms = <double>[];
    for (var i = 0; i < n; i++) {
      final box = _boxForRow(i);
      if (box == null) {
        // Partial layout: fall back to visible-only walk without caching.
        return null;
      }
      final origin = box.localToGlobal(Offset.zero);
      tops.add(origin.dy);
      bottoms.add(origin.dy + box.size.height);
    }

    final bottomBox = _boxFor(_bottomKey);
    final listBottom = bottomBox != null
        ? bottomBox.localToGlobal(Offset(0, bottomBox.size.height)).dy
        : bottoms.last;

    return _GeomCache(
      tops: tops,
      bottoms: bottoms,
      listTop: listTop,
      listBottom: listBottom,
    );
  }

  void _updateInsertFromGlobal(Offset global) {
    final n = widget.groups.length;
    if (n == 0) return;
    final y = global.dy;

    final cached = _geom ?? _readGeom();
    if (cached != null) {
      _geom = cached;
      _setHover(
        insertIndexForGlobalY(
          globalY: y,
          rowTops: cached.tops,
          rowBottoms: cached.bottoms,
          listTop: cached.listTop,
          listBottom: cached.listBottom,
        ),
      );
      return;
    }

    // Visible-only fallback when some sliver children are not laid out.
    final firstBox = _boxForRow(0);
    if (firstBox != null) {
      final top0 = firstBox.localToGlobal(Offset.zero).dy;
      if (y < top0) {
        _setHover(0);
        return;
      }
    }
    final bottomBox = _boxFor(_bottomKey);
    if (bottomBox != null) {
      final listBottom = bottomBox
          .localToGlobal(Offset(0, bottomBox.size.height))
          .dy;
      if (y >= listBottom) {
        _setHover(n);
        return;
      }
    }
    for (var i = 0; i < n; i++) {
      final box = _boxForRow(i);
      if (box == null) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final bottom = top + box.size.height;
      final threshold = (i == n - 1 ? 0.42 : 0.5) * box.size.height;
      if (y < top) {
        _setHover(i);
        return;
      }
      if (y < top + threshold) {
        _setHover(i);
        return;
      }
      if (y < bottom) {
        _setHover(i + 1);
        return;
      }
    }
    _setHover(n);
  }

  void _onDragStarted(int index, String groupId) {
    HapticFeedback.mediumImpact();
    _scrollPosition = Scrollable.maybeOf(context)?.position;
    _scrollPosition?.addListener(_invalidateGeom);
    _geom = _readGeom();
    setState(() {
      _draggingId = groupId;
      _insertBefore.value = index;
    });
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_invalidateGeom);
    _insertBefore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.groups.length;
    final dragging = _draggingId != null;
    final cheap = UiPerf.preferCheapListDrag;
    _rowKeys.removeWhere((i, _) => i >= n);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == n) {
            return ValueListenableBuilder<int?>(
              valueListenable: _insertBefore,
              builder: (context, insert, _) {
                return _BottomDropZone(
                  key: _bottomKey,
                  enabled: dragging,
                  highlighted: dragging && insert == n,
                  cheap: cheap,
                  onHover: () => _setHover(n),
                  onAccept: _commitDrop,
                  accepts: _belongs,
                );
              },
            );
          }

          final group = widget.groups[index];
          final row = KeyedSubtree(
            key: _rowKey(index),
            child: RepaintBoundary(
              child: _HoldDragGroupRow(
                group: group,
                isDragging: _draggingId == group.id,
                cheap: cheap,
                itemBuilder: widget.itemBuilder,
                accepts: _belongs,
                onDragStarted: () => _onDragStarted(index, group.id),
                onDragUpdate: _updateInsertFromGlobal,
                onDragEnd: (accepted) {
                  if (accepted) return;
                  _commitDrop(group);
                },
                onHoverAt: _updateInsertFromGlobal,
                onAccept: _commitDrop,
              ),
            ),
          );

          return ValueListenableBuilder<int?>(
            valueListenable: _insertBefore,
            // Keep the row element stable when only the insert line moves.
            child: row,
            builder: (context, insert, child) {
              final showLine = dragging && insert == index;
              return Stack(
                key: ValueKey(group.id),
                clipBehavior: Clip.none,
                children: [
                  child!,
                  if (showLine)
                    Positioned(
                      top: -1.5,
                      left: 28,
                      right: 28,
                      child: _DropInsertLine(cheap: cheap),
                    ),
                ],
              );
            },
          );
        },
        childCount: n + 1,
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
    required this.isDragging,
    required this.cheap,
    required this.itemBuilder,
    required this.accepts,
    required this.onDragStarted,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onHoverAt,
    required this.onAccept,
  });

  final Group group;
  final bool isDragging;
  final bool cheap;
  final Widget Function(BuildContext context, Group group) itemBuilder;
  final bool Function(Group group) accepts;
  final VoidCallback onDragStarted;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<bool> onDragEnd;
  final ValueChanged<Offset> onHoverAt;
  final ValueChanged<Group> onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Slightly longer press on mobile web reduces fight with scroll.
    final delay = Duration(milliseconds: UiPerf.isWebMobile ? 280 : 220);

    return LayoutBuilder(
      builder: (context, constraints) {
        final rowWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        return DragTarget<Group>(
          onWillAcceptWithDetails: (details) => accepts(details.data),
          onMove: (details) {
            if (!accepts(details.data)) return;
            onHoverAt(details.offset);
          },
          onAcceptWithDetails: (details) {
            if (!accepts(details.data)) return;
            onAccept(details.data);
          },
          builder: (context, candidate, rejected) {
            final over = candidate.isNotEmpty && !isDragging;
            return LongPressDraggable<Group>(
              data: group,
              delay: delay,
              hapticFeedbackOnStart: false,
              maxSimultaneousDrags: 1,
              onDragStarted: onDragStarted,
              onDragUpdate: (details) => onDragUpdate(details.globalPosition),
              onDragEnd: (details) => onDragEnd(details.wasAccepted),
              feedback: RepaintBoundary(
                child: _DragFeedbackCard(
                  width: rowWidth,
                  cheap: cheap,
                  child: itemBuilder(context, group),
                ),
              ),
              childWhenDragging: _DragPlaceholder(
                cheap: cheap,
                child: itemBuilder(context, group),
              ),
              child: Semantics(
                label: '${group.name}. ${'home_list_hold_to_reorder'.tr()}',
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
                    boxShadow: over && !cheap
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.12,
                              ),
                              blurRadius: 10,
                            ),
                          ]
                        : const [],
                    border: over && cheap
                        ? Border.all(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.35,
                            ),
                          )
                        : null,
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

/// Fixed-height hit target under the list (idle height == drag height).
class _BottomDropZone extends StatelessWidget {
  const _BottomDropZone({
    super.key,
    required this.enabled,
    required this.highlighted,
    required this.cheap,
    required this.onHover,
    required this.onAccept,
    required this.accepts,
  });

  final bool enabled;
  final bool highlighted;
  final bool cheap;
  final VoidCallback onHover;
  final ValueChanged<Group> onAccept;
  final bool Function(Group group) accepts;

  static const double height = 48;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return const SizedBox(height: height);
    }

    return DragTarget<Group>(
      onWillAcceptWithDetails: (details) => accepts(details.data),
      onMove: (details) {
        if (!accepts(details.data)) return;
        onHover();
      },
      onAcceptWithDetails: (details) {
        if (!accepts(details.data)) return;
        onAccept(details.data);
      },
      builder: (context, candidate, rejected) {
        final active = highlighted || candidate.isNotEmpty;
        final line = _DropInsertLine(cheap: cheap);
        return SizedBox(
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 28,
                right: 28,
                child: IgnorePointer(
                  child: cheap
                      ? Opacity(opacity: active ? 1 : 0, child: line)
                      : AnimatedOpacity(
                          opacity: active ? 1 : 0,
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          child: line,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DragPlaceholder extends StatelessWidget {
  const _DragPlaceholder({required this.cheap, required this.child});

  final bool cheap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final border = Border.all(color: cs.outlineVariant.withValues(alpha: 0.7));

    // iOS web: keep size without painting the card tree through Opacity.
    if (cheap) {
      return IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
            border: border,
            color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          ),
          child: Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: child,
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Opacity(
        opacity: 0.28,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(ThemeConfig.radiusL),
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DragFeedbackCard extends StatelessWidget {
  const _DragFeedbackCard({
    required this.width,
    required this.cheap,
    required this.child,
  });

  final double width;
  final bool cheap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(ThemeConfig.radiusL);

    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: cheap
            ? Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.4),
              )
            : null,
        boxShadow: cheap
            ? [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.14),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: child,
    );

    final sized = SizedBox(width: width, child: decorated);

    if (cheap) {
      return Material(type: MaterialType.transparency, child: sized);
    }

    return Material(
      type: MaterialType.transparency,
      child: Transform.rotate(
        angle: -0.015,
        child: Transform.scale(scale: 1.03, child: sized),
      ),
    );
  }
}

class _DropInsertLine extends StatelessWidget {
  const _DropInsertLine({required this.cheap});

  final bool cheap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(99),
          boxShadow: cheap
              ? null
              : [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                  ),
                ],
        ),
      ),
    );
  }
}
