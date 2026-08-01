import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/layout/content_aligned_fab_location.dart';

void main() {
  testWidgets(
    'ContentAlignedFabLocation.of equal across rebuilds with same metrics',
    (tester) async {
      FloatingActionButtonLocation? first;
      FloatingActionButtonLocation? second;

      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(1200, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.shrink(),
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      first = ContentAlignedFabLocation.of(context, contentAreaWidth: 960);
      second = ContentAlignedFabLocation.of(context, contentAreaWidth: 960);

      expect(first, isA<ContentAlignedFabLocation>());
      expect(identical(first, second), isFalse);
      expect(first, equals(second));
      expect(first.hashCode, second.hashCode);
    },
  );

  testWidgets(
    'ContentAlignedFabLocation.of differs when content band changes',
    (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(1200, 800)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.shrink(),
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      // Both widths leave enough end gutter for content-aligned placement,
      // but produce different leftOffset / band metrics.
      final a = ContentAlignedFabLocation.of(context, contentAreaWidth: 960);
      final b = ContentAlignedFabLocation.of(context, contentAreaWidth: 1000);

      expect(a, isA<ContentAlignedFabLocation>());
      expect(b, isA<ContentAlignedFabLocation>());
      expect(a, isNot(equals(b)));
    },
  );

  testWidgets(
    'ContentAlignedFabLocation.of reuses endFloat on narrow screens',
    (tester) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(size: Size(390, 844)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: SizedBox.shrink(),
          ),
        ),
      );

      final context = tester.element(find.byType(SizedBox));
      final a = ContentAlignedFabLocation.of(context, contentAreaWidth: 390);
      final b = ContentAlignedFabLocation.of(context, contentAreaWidth: 390);

      expect(a, FloatingActionButtonLocation.endFloat);
      expect(identical(a, b), isTrue);
    },
  );
}
