import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab/core/motion/app_motion.dart';
import 'package:hisab/core/navigation/app_page.dart';

void main() {
  test('appFadeSlidePage uses CustomTransitionPage with page duration', () {
    final page = appFadeSlidePage(
      key: const ValueKey('fade'),
      child: const SizedBox(),
    );
    expect(page, isA<CustomTransitionPage<dynamic>>());
    expect(page.transitionDuration, AppMotion.page);
    expect(page.reverseTransitionDuration, AppMotion.page);
  });

  test('appNoTransitionPage uses NoTransitionPage', () {
    final page = appNoTransitionPage(
      key: const ValueKey('none'),
      child: const SizedBox(),
    );
    expect(page, isA<NoTransitionPage<dynamic>>());
  });

  test('AppMotion durations match motion language', () {
    expect(AppMotion.modal, const Duration(milliseconds: 320));
    expect(AppMotion.shellTab, const Duration(milliseconds: 200));
    expect(AppMotion.page, const Duration(milliseconds: 280));
    expect(AppMotion.shellNav, const Duration(milliseconds: 280));
  });

  testWidgets('fade+slide transition respects RTL direction', (tester) async {
    final animation = AlwaysStoppedAnimation<double>(0.5);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) {
            return AppMotion.buildFadeSlideTransition(
              animation: animation,
              direction: Directionality.of(context),
              child: const SizedBox(key: ValueKey('child')),
            );
          },
        ),
      ),
    );
    expect(find.byKey(const ValueKey('child')), findsOneWidget);
  });

  testWidgets('buildHierarchicalPageTransition fadeOnly skips SlideTransition', (
    tester,
  ) async {
    final animation = AlwaysStoppedAnimation<double>(0.5);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AppMotion.buildHierarchicalPageTransition(
          animation: animation,
          direction: TextDirection.ltr,
          fadeOnly: true,
          child: const SizedBox(key: ValueKey('child')),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('child')), findsOneWidget);
    expect(find.byType(SlideTransition), findsNothing);
  });

  testWidgets('buildHierarchicalPageTransition includes SlideTransition', (
    tester,
  ) async {
    final animation = AlwaysStoppedAnimation<double>(0.5);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AppMotion.buildHierarchicalPageTransition(
          animation: animation,
          direction: TextDirection.ltr,
          fadeOnly: false,
          child: const SizedBox(key: ValueKey('child')),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('child')), findsOneWidget);
    expect(find.byType(SlideTransition), findsOneWidget);
  });
}
