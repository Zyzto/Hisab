import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../motion/app_motion.dart';

/// Hierarchical fade + end-slide page for GoRouter.
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
      return AppMotion.buildFadeSlideTransition(
        animation: animation,
        child: child,
        direction: Directionality.of(context),
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
