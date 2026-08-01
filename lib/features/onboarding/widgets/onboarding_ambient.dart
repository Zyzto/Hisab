import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/platform/ui_perf.dart';

/// Whether onboarding may run soft looping chrome (logo float, icon pulse).
///
/// Off on iOS web (`preferReducedChromeMotion`) where timers + transforms on
/// chrome were historically janky.
bool get onboardingAmbientAllowed => !UiPerf.preferReducedChromeMotion;

/// Gentle vertical float + scale breathe for a hero mark (logo).
///
/// No [Opacity] — transform-only so it stays cheap. Identity when ambient
/// motion is disabled.
class OnboardingBreathing extends StatefulWidget {
  const OnboardingBreathing({
    super.key,
    required this.child,
    this.floatPx = 5,
    this.scaleAmp = 0.03,
    this.period = const Duration(milliseconds: 2800),
  });

  final Widget child;
  final double floatPx;
  final double scaleAmp;
  final Duration period;

  @override
  State<OnboardingBreathing> createState() => _OnboardingBreathingState();
}

class _OnboardingBreathingState extends State<OnboardingBreathing>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (!onboardingAmbientAllowed) return;
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return widget.child;
    return AnimatedBuilder(
      animation: c,
      builder: (context, child) {
        // Smooth ease through the reverse cycle.
        final t = Curves.easeInOut.transform(c.value);
        final dy = -widget.floatPx * (t - 0.5) * 2;
        final scale = 1.0 + widget.scaleAmp * math.sin(t * math.pi);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Soft phase-offset scale pulse for icon chips (welcome feature rows).
class OnboardingIconPulse extends StatefulWidget {
  const OnboardingIconPulse({
    super.key,
    required this.child,
    required this.phase,
    this.scaleAmp = 0.055,
    this.period = const Duration(milliseconds: 3200),
  });

  final Widget child;
  final double phase;
  final double scaleAmp;
  final Duration period;

  @override
  State<OnboardingIconPulse> createState() => _OnboardingIconPulseState();
}

class _OnboardingIconPulseState extends State<OnboardingIconPulse>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    if (!onboardingAmbientAllowed) return;
    _controller = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return widget.child;
    return AnimatedBuilder(
      animation: c,
      builder: (context, child) {
        final wave = math.sin((c.value + widget.phase) * math.pi * 2);
        // Mostly idle; pulse peaks are brief and soft.
        final scale = 1.0 + widget.scaleAmp * math.max(0.0, wave);
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}
