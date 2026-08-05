import 'package:flutter/material.dart';

bool _animationAlreadyFinished(Animation<double> animation) {
  // Prefer status, but also accept value==1 (e.g. AlwaysStoppedAnimation in tests
  // always reports [AnimationStatus.dismissed]).
  return animation.isCompleted ||
      animation.status == AnimationStatus.completed ||
      animation.value >= 1.0;
}

/// Runs [action] when [animation] (or the ambient [ModalRoute] animation)
/// has completed. If already completed or absent, runs [action] immediately.
///
/// Returns a cancel callback that removes the status listener (no-op if already
/// fired or never attached). Call from [State.dispose].
VoidCallback armWhenAnimationReady({
  required BuildContext context,
  Animation<double>? animation,
  required VoidCallback action,
}) {
  final anim = animation ?? ModalRoute.of(context)?.animation;
  if (anim == null || _animationAlreadyFinished(anim)) {
    action();
    return () {};
  }

  var cancelled = false;
  late final AnimationStatusListener listener;
  listener = (status) {
    if (cancelled) return;
    if (status == AnimationStatus.completed || anim.value >= 1.0) {
      anim.removeStatusListener(listener);
      action();
    }
  };
  anim.addStatusListener(listener);
  if (_animationAlreadyFinished(anim)) {
    anim.removeStatusListener(listener);
    action();
    return () {};
  }
  return () {
    cancelled = true;
    anim.removeStatusListener(listener);
  };
}

/// Gates heavy page bodies until the push route transition finishes.
///
/// When [ModalRoute.animation] is null or already completed (widget tests,
/// [MaterialApp.home], etc.), [routeReady] becomes true synchronously without
/// [setState] so the same frame can mount the full body.
mixin RouteTransitionReady<T extends StatefulWidget> on State<T> {
  bool routeReady = false;

  Animation<double>? _routeAnimation;
  AnimationStatusListener? _routeAnimationStatusListener;
  VoidCallback? _onRouteReady;

  /// Arm the gate. Safe to call from [State.build] and post-frame callbacks.
  ///
  /// [onReady] is stored and invoked when the route becomes ready (post-frame
  /// if already completed, immediately after [setState] when waiting on the
  /// animation). Later non-null values replace earlier ones; if the route is
  /// already ready when a new [onReady] is supplied, it is scheduled post-frame.
  void ensureRouteReady(BuildContext context, {VoidCallback? onReady}) {
    final hadReadyCallback = _onRouteReady != null;
    if (onReady != null) {
      _onRouteReady = onReady;
    }
    if (routeReady) {
      // Late onReady after sync-ready (first call had none) — fire once now.
      if (onReady != null && !hadReadyCallback) {
        onReady();
      }
      return;
    }

    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || _animationAlreadyFinished(animation)) {
      routeReady = true;
      _detachRouteAnimationListener();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onRouteReady?.call();
      });
      return;
    }

    if (_routeAnimationStatusListener != null) return;

    _routeAnimation = animation;
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed || animation.value >= 1.0) {
        _markRouteReady();
      }
    }

    _routeAnimationStatusListener = listener;
    animation.addStatusListener(listener);
    if (_animationAlreadyFinished(animation)) {
      _markRouteReady();
    }
  }

  void _markRouteReady() {
    _detachRouteAnimationListener();
    if (!mounted) return;
    if (routeReady) return;
    setState(() => routeReady = true);
    _onRouteReady?.call();
  }

  void _detachRouteAnimationListener() {
    final anim = _routeAnimation;
    final listener = _routeAnimationStatusListener;
    if (anim != null && listener != null) {
      anim.removeStatusListener(listener);
    }
    _routeAnimation = null;
    _routeAnimationStatusListener = null;
  }

  /// Call from [State.dispose] before other teardown.
  void disposeRouteReady() {
    _detachRouteAnimationListener();
    _onRouteReady = null;
  }
}
