import 'package:flutter/material.dart';

import '../motion/app_motion.dart';
import '../platform/ui_perf.dart';

/// One-shot fade (+ optional slide-up) when a wizard step body first mounts.
///
/// On iOS web (`UiPerf.preferFadeOnlyPageTransitions`), skips motion entirely
/// (identity) — Opacity + slide is expensive on that surface.
class WizardStepEnter extends StatefulWidget {
  const WizardStepEnter({
    super.key,
    required this.child,
    this.slidePx = 20,
  });

  final Widget child;
  final double slidePx;

  @override
  State<WizardStepEnter> createState() => _WizardStepEnterState();
}

class _WizardStepEnterState extends State<WizardStepEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _t;

  @override
  void initState() {
    super.initState();
    // iOS web: skip enter motion entirely (Opacity + slide is expensive).
    if (UiPerf.preferFadeOnlyPageTransitions) {
      _controller = AnimationController(vsync: this, value: 1);
      _t = CurvedAnimation(parent: _controller, curve: AppMotion.enterCurve);
      return;
    }
    _controller = AnimationController(vsync: this, duration: AppMotion.page);
    _t = CurvedAnimation(parent: _controller, curve: AppMotion.enterCurve);
    _controller.forward();
  }

  @override
  void dispose() {
    _t.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (UiPerf.preferFadeOnlyPageTransitions || _controller.isCompleted) {
      return widget.child;
    }
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * widget.slidePx),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
