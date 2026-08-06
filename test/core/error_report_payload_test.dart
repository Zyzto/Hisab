import 'package:flutter_test/flutter_test.dart';
import 'package:hisab/core/utils/error_report_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('buildErrorReportPayload screenshot section', () {
    test('embeds markdown image when screenshotUrl is set', () async {
      final payload = await buildErrorReportPayload(
        message: 'Something broke',
        summaryEnglish: 'User feedback',
        uiLocaleTag: 'en',
        screenshotUrl: 'https://example.com/shot.png',
      );

      expect(payload.githubBody, contains('**Screenshot**'));
      expect(
        payload.githubBody,
        contains('![Screenshot](https://example.com/shot.png)'),
      );
      expect(
        payload.plainText,
        contains('Screenshot: https://example.com/shot.png'),
      );
    });

    test('adds English manual-attach note when upload failed', () async {
      final payload = await buildErrorReportPayload(
        message: 'Bug',
        summaryEnglish: 'User feedback',
        uiLocaleTag: 'ar',
        includeScreenshotManualNote: true,
      );

      expect(payload.githubBody, contains('**Screenshot**'));
      expect(payload.githubBody, contains(kScreenshotManualAttachNoteEnglish));
      expect(payload.githubBody, isNot(contains('![Screenshot]')));
      expect(payload.plainText, contains('Screenshot: manual attach needed'));
    });

    test('prefers URL over manual note when both provided', () async {
      final payload = await buildErrorReportPayload(
        message: 'Bug',
        uiLocaleTag: 'en',
        screenshotUrl: 'https://example.com/a.png',
        includeScreenshotManualNote: true,
      );

      expect(
        payload.githubBody,
        contains('![Screenshot](https://example.com/a.png)'),
      );
      expect(
        payload.githubBody,
        isNot(contains(kScreenshotManualAttachNoteEnglish)),
      );
    });

    test('keeps English section headings with Arabic UI locale', () async {
      final payload = await buildErrorReportPayload(
        message: 'رسالة',
        summaryEnglish: 'User feedback',
        uiLocaleTag: 'ar',
      );

      expect(
        payload.githubBody,
        contains('### Hisab bug report (auto-generated)'),
      );
      expect(payload.githubBody, contains('**Environment**'));
      expect(payload.githubBody, contains('**Summary (English)**'));
      expect(payload.githubBody, contains('User feedback'));
      expect(payload.githubBody, contains('رسالة'));
    });
  });
}
