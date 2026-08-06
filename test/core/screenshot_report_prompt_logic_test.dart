import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/services/screenshot_report_prompt_logic.dart';

void main() {
  group('ScreenshotReportPromptLogic', () {
    late ScreenshotReportPromptLogic logic;
    final t0 = DateTime.utc(2026, 7, 31, 12);

    setUp(() {
      logic = ScreenshotReportPromptLogic(debounce: const Duration(seconds: 5));
    });

    test('prompts when enabled, in foreground, and feedback closed', () {
      expect(
        logic.shouldPrompt(
          enabled: true,
          appInForeground: true,
          feedbackOpen: false,
          now: t0,
        ),
        isTrue,
      );
    });

    test('does not prompt when toggle is off', () {
      expect(
        logic.shouldPrompt(
          enabled: false,
          appInForeground: true,
          feedbackOpen: false,
          now: t0,
        ),
        isFalse,
      );
    });

    test('does not prompt when app is not in foreground', () {
      expect(
        logic.shouldPrompt(
          enabled: true,
          appInForeground: false,
          feedbackOpen: false,
          now: t0,
        ),
        isFalse,
      );
    });

    test('does not prompt when BetterFeedback is already open', () {
      expect(
        logic.shouldPrompt(
          enabled: true,
          appInForeground: true,
          feedbackOpen: true,
          now: t0,
        ),
        isFalse,
      );
    });

    test('debounces within the cooldown window', () {
      expect(
        logic.shouldPrompt(
          enabled: true,
          appInForeground: true,
          feedbackOpen: false,
          now: t0,
        ),
        isTrue,
      );
      expect(
        logic.shouldPrompt(
          enabled: true,
          appInForeground: true,
          feedbackOpen: false,
          now: t0.add(const Duration(seconds: 4)),
        ),
        isFalse,
      );
      expect(
        logic.shouldPrompt(
          enabled: true,
          appInForeground: true,
          feedbackOpen: false,
          now: t0.add(const Duration(seconds: 5)),
        ),
        isTrue,
      );
    });
  });
}
