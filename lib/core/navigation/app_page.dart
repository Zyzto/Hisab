import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../motion/app_motion.dart';
import '../platform/ui_perf.dart';

/// Hierarchical page for GoRouter (fade+slide, or fade-only on iOS web).
CustomTransitionPage<T> appFadeSlidePage<T>({
  required LocalKey key,
  required Widget child,
  String? name,
  Object? arguments,
  String? restorationId,
}) {
  return CustomTransitionPage<T>(
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.page,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return AppMotion.buildHierarchicalPageTransition(
        animation: animation,
        child: child,
        direction: Directionality.of(context),
        fadeOnly: UiPerf.preferFadeOnlyPageTransitions,
      );
    },
  );
}

/// Instant page (IndexedStack roots, onboarding steps, expense paging).
NoTransitionPage<T> appNoTransitionPage<T>({
  required LocalKey key,
  required Widget child,
  String? name,
  Object? arguments,
  String? restorationId,
}) {
  return NoTransitionPage<T>(
    key: key,
    name: name,
    arguments: arguments,
    restorationId: restorationId,
    child: child,
  );
}
