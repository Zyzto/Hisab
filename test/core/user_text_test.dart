import 'package:characters/characters.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/utils/user_text.dart';

void main() {
  group('elideGraphemes', () {
    test('leaves short text unchanged', () {
      expect(elideGraphemes('مرحبا', maxGraphemes: 40), 'مرحبا');
    });

    test('does not split emoji ZWJ sequences', () {
      // Family emoji is one grapheme cluster (multiple code points).
      const family = '👨‍👩‍👧‍👦';
      final long = List.filled(5, family).join();
      final elided = elideGraphemes(long, maxGraphemes: 2);
      expect(elided, '$family$family…');
      expect(elided.characters.length, 3); // 2 families + ellipsis
    });

    test('elides Arabic by grapheme count', () {
      const text = 'عنوان مصروف طويل جدا جدا جدا جدا جدا';
      final elided = elideGraphemes(text, maxGraphemes: 10);
      expect(elided.endsWith('…'), isTrue);
      expect(elided.characters.length, 11);
    });
  });

  group('clampCodePoints', () {
    test('cuts at code-point boundary for emoji', () {
      // Each thumbs-up is one code point in the BMP? 👍 is U+1F44D (one rune).
      const thumb = '👍';
      final clamped = clampCodePoints(
        List.filled(5, thumb).join(),
        maxCodePoints: 3,
      );
      expect(clamped.runes.length, 3);
      expect(clamped, '$thumb$thumb$thumb');
    });
  });

  group('isolateBidi', () {
    test('wraps with FSI/PDI', () {
      expect(isolateBidi('Lunch'), '\u2068Lunch\u2069');
      expect(unwrapBidiIsolates(isolateBidi('عشاء')), 'عشاء');
    });
  });

  group('resolveUserTextDirection', () {
    test('detects Arabic as RTL', () {
      expect(resolveUserTextDirection('عشاء مع الأصدقاء'), TextDirection.rtl);
    });

    test('detects Latin as LTR', () {
      expect(
        resolveUserTextDirection('Dinner with friends'),
        TextDirection.ltr,
      );
    });

    test('inherits for digits-only', () {
      expect(resolveUserTextDirection('12345'), isNull);
    });

    test('inherits for empty', () {
      expect(resolveUserTextDirection('   '), isNull);
    });
  });

  group('resolveUiStartTextAlign', () {
    test('uses right in RTL UI and left in LTR UI', () {
      expect(resolveUiStartTextAlign(TextDirection.rtl), TextAlign.right);
      expect(resolveUiStartTextAlign(TextDirection.ltr), TextAlign.left);
    });
  });
}
