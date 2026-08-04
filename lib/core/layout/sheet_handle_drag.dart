import 'package:flutter/material.dart';

import '../motion/app_motion.dart';

/// Result of releasing the sheet drag handle.
enum SheetHandleDragAction { none, expand, collapse, dismiss }

/// Shared drag math for compact↔full camera / QR sheets (+ dismiss).
///
/// Offset: positive = dragged down, negative = dragged up.
class SheetHandleDrag {
  double offset = 0;

  static const double expandDistance = 72;
  static const double collapseDistance = 72;
  static const double dismissDistance = 96;
  static const double flingVelocity = 900;

  void update(double deltaDy, {required bool expanded}) {
    if (expanded) {
      // Full screen: only drag down toward compact.
      offset = (offset + deltaDy).clamp(0.0, 280.0);
    } else {
      offset = (offset + deltaDy).clamp(-280.0, 240.0);
    }
  }

  void reset() => offset = 0;

  double panelHeight({
    required bool expanded,
    required double compactH,
    required double fullH,
  }) {
    if (expanded) {
      return (fullH - offset).clamp(compactH, fullH);
    }
    // Drag up (negative offset) grows toward full.
    if (offset < 0) {
      return (compactH - offset).clamp(compactH, fullH);
    }
    return compactH;
  }

  /// Visual slide-down only while dismissing from compact (not while expanding).
  double translateY({required bool expanded}) {
    if (expanded) return 0;
    return offset > 0 ? offset : 0;
  }

  SheetHandleDragAction end({
    required bool expanded,
    required double velocity,
  }) {
    if (expanded) {
      if (offset > collapseDistance || velocity > flingVelocity) {
        return SheetHandleDragAction.collapse;
      }
      return SheetHandleDragAction.none;
    }
    if (offset < -expandDistance || velocity < -flingVelocity) {
      return SheetHandleDragAction.expand;
    }
    if (offset > dismissDistance || velocity > flingVelocity) {
      return SheetHandleDragAction.dismiss;
    }
    return SheetHandleDragAction.none;
  }
}

/// Top grabber for expandable black sheets (receipt camera / invite scanner).
class SheetHandleBar extends StatelessWidget {
  const SheetHandleBar({
    super.key,
    required this.expanded,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
    required this.onVerticalDragCancel,
    this.duration = AppMotion.modal,
  });

  final bool expanded;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;
  final VoidCallback onVerticalDragCancel;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: AppMotion.enterCurve,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: onVerticalDragUpdate,
        onVerticalDragEnd: onVerticalDragEnd,
        onVerticalDragCancel: onVerticalDragCancel,
        child: Padding(
          padding: EdgeInsets.only(
            top: expanded ? 8 : 10,
            bottom: expanded ? 4 : 6,
          ),
          child: Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
