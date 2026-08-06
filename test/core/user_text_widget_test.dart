import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/widgets/user_text.dart';

Rect _glyphBounds(WidgetTester tester, Finder textFinder) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(of: textFinder, matching: find.byType(RichText)),
  );
  final data = paragraph.text.toPlainText();
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: data.length),
  );
  expect(boxes, isNotEmpty);
  final local = boxes
      .map((b) => b.toRect())
      .reduce((a, b) => a.expandToInclude(b));
  final origin = paragraph.localToGlobal(Offset.zero);
  return local.shift(origin);
}

void main() {
  testWidgets('UserText aligns Latin UGC to UI start in RTL', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SizedBox(
              width: 240,
              child: UserText(
                'abcd',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('abcd'));
    expect(text.textDirection, TextDirection.ltr);
    expect(text.textAlign, TextAlign.right);
  });

  testWidgets('UserText aligns Latin UGC to UI start in LTR', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: SizedBox(
              width: 240,
              child: UserText(
                'abcd',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('abcd'));
    expect(text.textDirection, TextDirection.ltr);
    expect(text.textAlign, TextAlign.left);
  });

  testWidgets('explicit textAlign wins over UI start default', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: UserText('abcd', textAlign: TextAlign.center)),
        ),
      ),
    );

    final text = tester.widget<Text>(find.text('abcd'));
    expect(text.textAlign, TextAlign.center);
  });

  testWidgets('Latin glyphs sit beside leading avatar in RTL Expanded row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: Row(
                  children: [
                    CircleAvatar(radius: 14, child: Text('A')),
                    SizedBox(width: 8),
                    Expanded(
                      child: UserText(
                        'abcd',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatarRect = tester.getRect(find.byType(CircleAvatar));
    final glyphs = _glyphBounds(tester, find.text('abcd'));

    // RTL Row: avatar on the right; Latin glyphs must hug its left side.
    expect(avatarRect.left - glyphs.right, lessThan(14));
    expect(avatarRect.left - glyphs.right, greaterThanOrEqualTo(0));
    // Glyphs must not sit on the far left of the 300px row.
    expect(glyphs.left, greaterThan(avatarRect.left - 120));
  });

  testWidgets('Arabic glyphs sit beside leading avatar in LTR Expanded row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: Row(
                  children: [
                    CircleAvatar(radius: 14, child: Text('ع')),
                    SizedBox(width: 8),
                    Expanded(
                      child: UserText(
                        'علي',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final avatarRect = tester.getRect(find.byType(CircleAvatar));
    final glyphs = _glyphBounds(tester, find.text('علي'));

    // LTR Row: avatar on the left; Arabic glyphs must hug its right side.
    expect(glyphs.left - avatarRect.right, lessThan(14));
    expect(glyphs.left - avatarRect.right, greaterThanOrEqualTo(0));
    expect(glyphs.right, lessThan(avatarRect.right + 120));
  });
}
