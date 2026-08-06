import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/features/expenses/category_icons.dart';

void main() {
  group('tag contrast', () {
    for (final brightness in Brightness.values) {
      final surface = brightness == Brightness.dark
          ? const Color(0xFF121212)
          : Colors.white;

      test('preset tags meet AA on $brightness surface/container', () {
        for (final preset in presetCategoryTags) {
          final chrome = chromeForExpenseTag(
            preset.id,
            brightness: brightness,
            surface: surface,
          );
          expect(
            contrastRatio(chrome.onContainer, chrome.container),
            greaterThanOrEqualTo(kTagTextContrastRatio),
            reason: '${preset.id} onContainer vs container',
          );
          expect(
            contrastRatio(chrome.onSurface, surface),
            greaterThanOrEqualTo(kTagTextContrastRatio),
            reason: '${preset.id} onSurface vs surface',
          );
        }
      });
    }

    test('custom tags also meet AA', () {
      const ids = ['custom-a', 'custom-b', 'vacation-fund', 'xyz'];
      for (final id in ids) {
        final chrome = chromeForExpenseTag(
          id,
          brightness: Brightness.light,
          surface: Colors.white,
        );
        expect(
          contrastRatio(chrome.onContainer, chrome.container),
          greaterThanOrEqualTo(kTagTextContrastRatio),
        );
      }
    });
  });
}
