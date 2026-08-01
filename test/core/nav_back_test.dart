import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hisab/core/navigation/nav_back.dart';

void main() {
  group('routerCanPop', () {
    testWidgets('uses Navigator when GoRouter is absent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(routerCanPop(context), isFalse);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });

    testWidgets('uses GoRouter when present', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Builder(
              builder: (context) {
                expect(routerCanPop(context), isFalse);
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    });
  });

  group('isStrictAncestorPath', () {
    test('expense detail is under group expenses', () {
      expect(
        isStrictAncestorPath(
          '/groups/g1/expenses',
          '/groups/g1/expenses/e1',
        ),
        isTrue,
      );
      expect(
        isStrictAncestorPath(
          '/groups/g1/expenses',
          '/groups/g1/expenses/e1/edit',
        ),
        isTrue,
      );
    });

    test('rejects self and siblings', () {
      expect(
        isStrictAncestorPath('/groups/g1/expenses', '/groups/g1/expenses'),
        isFalse,
      );
      expect(
        isStrictAncestorPath('/groups/g1/expenses', '/groups/g1/settings'),
        isFalse,
      );
      expect(
        isStrictAncestorPath('/groups/g1/settings', '/groups/g1/invites'),
        isFalse,
      );
    });

    test('profile expenses under profile', () {
      expect(isStrictAncestorPath('/profile', '/profile/expenses'), isTrue);
      expect(isStrictAncestorPath('/profile', '/profile'), isFalse);
    });

    test('home is ancestor of nested routes', () {
      expect(isStrictAncestorPath('/', '/groups/g1/expenses'), isTrue);
      expect(isStrictAncestorPath('/', '/'), isFalse);
    });
  });
}
