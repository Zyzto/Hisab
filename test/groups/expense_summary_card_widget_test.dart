import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hisab/core/utils/currency_formatter.dart';
import 'package:hisab/core/widgets/amount_text.dart';
import 'package:hisab/core/widgets/amount_with_secondary_display.dart';
import 'package:hisab/features/groups/widgets/expense_summary_card.dart';
import 'package:hisab/core/settings/providers/settings_framework_providers.dart';

/// Half-width phone card (matches expenses tab pair of summary chips).
const _kNarrowCardWidth = 180.0;

Widget _wrapCard(
  Widget card, {
  double width = _kNarrowCardWidth,
  TextDirection textDirection = TextDirection.rtl,
}) {
  return ProviderScope(
    overrides: [displayCurrencyProvider.overrideWith((ref) => '')],
    child: MaterialApp(
      home: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: card),
          ),
        ),
      ),
    ),
  );
}

/// Distinct baseline bottoms from selection boxes ⇒ wrapped lines.
int _visualLineCount(RenderParagraph paragraph) {
  final plain = paragraph.text?.toPlainText() ?? '';
  if (plain.isEmpty) return 0;
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: plain.length),
  );
  return boxes.map((b) => b.bottom.round()).toSet().length;
}

void main() {
  test('integerDigitCount ignores grouping separators', () {
    expect(ExpenseSummaryCard.integerDigitCount('1,044.92 SAR'), 4);
    expect(ExpenseSummaryCard.integerDigitCount('10,000,000.00 SAR'), 8);
    expect(ExpenseSummaryCard.integerDigitCount('9999999.99'), 7);
  });

  testWidgets(
    'narrow RTL card keeps mid-size SAR amount on one line (no currency wrap)',
    (tester) async {
      // Reproduces the "You paid" bug: currency glyph wrapping above digits.
      const cents = 104492; // 1,044.92
      final value = '${CurrencyFormatter.formatCompactCents(cents)} SAR';
      final formatted = CurrencyFormatter.formatCents(cents, 'SAR');

      await tester.pumpWidget(
        _wrapCard(
          ExpenseSummaryCard(
            label: 'أنت دفعت',
            value: value,
            valueWidget: AmountWithSecondaryDisplay(
              amountCents: cents,
              groupCurrencyCode: 'SAR',
              showSecondary: false,
              softWrap: false,
              maxLines: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final amountFinder = find.descendant(
        of: find.byType(ExpenseSummaryCard),
        matching: find.byType(AmountText),
      );
      expect(amountFinder, findsOneWidget);

      final amountText = tester.widget<AmountText>(amountFinder);
      expect(amountText.data, formatted);
      expect(amountText.maxLines, 1);
      expect(amountText.softWrap, isFalse);

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: amountFinder, matching: find.byType(RichText)),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(
        _visualLineCount(paragraph),
        1,
        reason: 'Currency symbol must not wrap above the digits',
      );
    },
  );

  testWidgets('fallback Text amount stays single-line in a tight card', (
    tester,
  ) async {
    const value = '1,044.92 SAR';
    await tester.pumpWidget(
      _wrapCard(
        const ExpenseSummaryCard(label: 'You paid', value: value),
        textDirection: TextDirection.ltr,
      ),
    );
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text(value));
    expect(text.maxLines, 1);
    expect(text.softWrap, isFalse);

    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(
        of: find.byType(ExpenseSummaryCard),
        matching: find.text(value),
      ),
    );
    expect(_visualLineCount(paragraph), 1);
  });

  testWidgets(
    '8-digit amount uses overlay layout so label does not steal amount width',
    (tester) async {
      const cents = 1000000000; // 10,000,000.00
      final value = '${CurrencyFormatter.formatCompactCents(cents)} SAR';

      await tester.pumpWidget(
        _wrapCard(
          ExpenseSummaryCard(
            label: 'Total',
            value: value,
            valueWidget: AmountWithSecondaryDisplay(
              amountCents: cents,
              groupCurrencyCode: 'SAR',
              showSecondary: false,
              softWrap: false,
              maxLines: 1,
            ),
          ),
          width: 320,
          textDirection: TextDirection.ltr,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(ExpenseSummaryCard),
          matching: find.byType(Stack),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(ExpenseSummaryCard),
          matching: find.byType(Row),
        ),
        findsNothing,
      );

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(
          of: find.byType(AmountText),
          matching: find.byType(RichText),
        ),
      );
      expect(_visualLineCount(paragraph), 1);
    },
  );

  testWidgets('small amount that fits stays on a single Row with the label', (
    tester,
  ) async {
    const value = '12.00 SAR';
    await tester.pumpWidget(
      _wrapCard(
        const ExpenseSummaryCard(label: 'Share', value: value),
        width: 320,
        textDirection: TextDirection.ltr,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(ExpenseSummaryCard),
        matching: find.byType(Row),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ExpenseSummaryCard),
        matching: find.byType(Stack),
      ),
      findsNothing,
    );
  });
}
