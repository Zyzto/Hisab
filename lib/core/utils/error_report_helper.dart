import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_config.dart';
import '../navigation/navigation_trace.dart';
import '../services/connectivity_service.dart';
import '../telemetry/telemetry_service.dart';
import '../../features/settings/feedback_clipboard.dart';
import '../../features/settings/feedback_upload.dart';
import '../../features/settings/providers/settings_framework_providers.dart';

const int _maxMessageForShare = 2000;
const int _maxMessageForTelemetry = 200;
const int _maxGithubTitle = 80;
const int _maxStackChars = 800;

/// English note when a screenshot was captured but could not be uploaded.
const String kScreenshotManualAttachNoteEnglish =
    '(Screenshot was captured; please attach it manually if needed.)';

String _deviceLocaleTag() =>
    WidgetsBinding.instance.platformDispatcher.locale.toLanguageTag();

String _uiLocaleTagFromContext(BuildContext context) {
  try {
    return context.locale.toLanguageTag();
  } catch (_) {
    return _deviceLocaleTag();
  }
}

/// UI locale tag for diagnostics (EasyLocalization if present, else device).
/// Prefer calling with the screen that surfaced the error, not an overlay child.
String readUiLocaleTagForReport(BuildContext context) =>
    _uiLocaleTagFromContext(context);

String _platformLabelEnglish() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}

/// Builds plain text and GitHub issue body for an error report.
///
/// Section headings and environment lines are **English** so issues are
/// readable on GitHub regardless of UI language. [message] is the string shown
/// to the user (may be localized). [summaryEnglish] is optional developer-facing
/// English text (e.g. same as [logMessage] passed to [Log.warning]).
///
/// When [screenshotUrl] is set, embeds a markdown image. When upload failed but
/// a capture exists, set [includeScreenshotManualNote] for the English fallback.
Future<({String plainText, String githubBody})> buildErrorReportPayload({
  required String message,
  String? details,
  StackTrace? stackTrace,
  String? summaryEnglish,
  String? uiLocaleTag,
  String? screenshotUrl,
  bool includeScreenshotManualNote = false,
}) async {
  String version = 'unknown';
  try {
    final info = await PackageInfo.fromPlatform();
    version = '${info.version}+${info.buildNumber}';
  } catch (_) {}

  final sanitizedMessage = _sanitizeForReport(message, _maxMessageForShare);
  final sanitizedSummaryEn = summaryEnglish != null && summaryEnglish.isNotEmpty
      ? _sanitizeForReport(summaryEnglish.trim(), _maxMessageForShare)
      : null;

  final buffer = StringBuffer();
  buffer.writeln('### Hisab bug report (auto-generated)');
  buffer.writeln();
  buffer.writeln('**Environment**');
  buffer.writeln('- **App version:** $version');
  buffer.writeln('- **Platform:** ${_platformLabelEnglish()}');
  buffer.writeln(
    '- **UI locale (EasyLocalization):** ${uiLocaleTag ?? 'unknown'}',
  );
  buffer.writeln('- **Device locale:** ${_deviceLocaleTag()}');
  buffer.writeln();
  buffer.writeln(NavigationTrace.instance.buildReportSectionEnglish());
  if (sanitizedSummaryEn != null) {
    buffer.writeln('**Summary (English)**');
    buffer.writeln(sanitizedSummaryEn);
    buffer.writeln();
  }
  buffer.writeln(
    '**User-visible message (may be localized to UI locale above)**',
  );
  buffer.writeln(sanitizedMessage);
  buffer.writeln();
  if (details != null && details.isNotEmpty) {
    buffer.writeln('**Technical details**');
    buffer.writeln(
      details.length > _maxMessageForShare
          ? '${details.substring(0, _maxMessageForShare)}...'
          : details,
    );
    buffer.writeln();
  }
  if (stackTrace != null) {
    final stackStr = stackTrace.toString();
    buffer.writeln('**Stack trace**');
    buffer.writeln(
      stackStr.length > _maxStackChars
          ? '${stackStr.substring(0, _maxStackChars)}...'
          : stackStr,
    );
    buffer.writeln();
  }
  final url = screenshotUrl?.trim();
  if (url != null && url.isNotEmpty) {
    buffer.writeln('**Screenshot**');
    buffer.writeln('![Screenshot]($url)');
    buffer.writeln();
  } else if (includeScreenshotManualNote) {
    buffer.writeln('**Screenshot**');
    buffer.writeln(kScreenshotManualAttachNoteEnglish);
    buffer.writeln();
  }

  final githubBody = buffer.toString();
  final plainText = 'Hisab error report (English template)\n'
      'Version: $version | Platform: ${_platformLabelEnglish()} | '
      'UI locale: ${uiLocaleTag ?? 'unknown'}\n'
      '${sanitizedSummaryEn != null ? 'Summary (en): $sanitizedSummaryEn\n' : ''}'
      'User message (may be localized): $sanitizedMessage\n'
      '${details != null && details.isNotEmpty ? 'Details: $details\n' : ''}'
      '${NavigationTrace.instance.buildReportSectionEnglish(maxChars: 1200)}'
      '${url != null && url.isNotEmpty ? 'Screenshot: $url\n' : ''}'
      '${includeScreenshotManualNote && (url == null || url.isEmpty) ? 'Screenshot: manual attach needed\n' : ''}';
  return (plainText: plainText, githubBody: githubBody);
}

String _sanitizeForReport(String text, int maxLen) {
  final t = text.trim();
  if (t.length <= maxLen) return t;
  return '${t.substring(0, maxLen)}...';
}

/// Shares the error report via the system share sheet.
Future<void> shareErrorReport(
  BuildContext context, {
  required String message,
  String? details,
  StackTrace? stackTrace,
  String? summaryEnglish,
  /// When null, derived from [context] (prefer passing from the caller surface).
  String? uiLocaleTag,
}) async {
  final payload = await buildErrorReportPayload(
    message: message,
    details: details,
    stackTrace: stackTrace,
    summaryEnglish: summaryEnglish,
    uiLocaleTag: uiLocaleTag ?? _uiLocaleTagFromContext(context),
  );
  if (!context.mounted) return;
  try {
    await SharePlus.instance.share(ShareParams(text: payload.plainText));
  } catch (_) {}
}

/// Opens GitHub issue with prefilled title and body, or copies body to clipboard if [reportIssueUrl] is empty.
/// [onCopied] is called when body was copied to clipboard (e.g. show a success toast).
Future<void> openErrorReportGitHubIssue(
  BuildContext context, {
  required String message,
  String? details,
  StackTrace? stackTrace,
  String? summaryEnglish,
  /// When null, derived from [context] (prefer passing from the caller surface).
  String? uiLocaleTag,
  VoidCallback? onCopied,
}) async {
  final payload = await buildErrorReportPayload(
    message: message,
    details: details,
    stackTrace: stackTrace,
    summaryEnglish: summaryEnglish,
    uiLocaleTag: uiLocaleTag ?? _uiLocaleTagFromContext(context),
  );
  if (!context.mounted) return;

  final titleBase = (summaryEnglish != null && summaryEnglish.isNotEmpty)
      ? summaryEnglish
      : message;
  final title = 'Bug: ${_sanitizeForReport(titleBase, _maxGithubTitle)}'
      .replaceAll('\n', ' ');

  if (reportIssueUrl.isEmpty) {
    await Clipboard.setData(ClipboardData(text: payload.githubBody));
    if (context.mounted) onCopied?.call();
    return;
  }

  try {
    final uri = Uri.parse(reportIssueUrl).replace(
      queryParameters: <String, String>{
        'title': title,
        'body': payload.githubBody,
      },
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: payload.githubBody));
    if (context.mounted) onCopied?.call();
  }
}

/// Uploads an optional screenshot, builds the English report payload, opens GitHub
/// (or copies when [reportIssueUrl] is empty), and copies body (+ image) to clipboard.
///
/// Returns whether the body was written to the clipboard as the primary outcome
/// (true when [reportIssueUrl] is empty or launch failed after copy fallback).
Future<bool> submitUserBugReport(
  BuildContext context, {
  required String message,
  Uint8List? screenshotPng,
  String? summaryEnglish,
  String? uiLocaleTag,
}) async {
  final hasScreenshot = screenshotPng != null && screenshotPng.isNotEmpty;
  final resolvedUiLocale = uiLocaleTag ?? _uiLocaleTagFromContext(context);
  String? screenshotUrl;
  if (hasScreenshot) {
    screenshotUrl = await uploadFeedbackScreenshot(screenshotPng);
  }

  final payload = await buildErrorReportPayload(
    message: message.trim().isEmpty ? '—' : message.trim(),
    summaryEnglish: summaryEnglish,
    uiLocaleTag: resolvedUiLocale,
    screenshotUrl: screenshotUrl,
    includeScreenshotManualNote: hasScreenshot && screenshotUrl == null,
  );
  if (!context.mounted) return false;

  final titleBase = (summaryEnglish != null && summaryEnglish.isNotEmpty)
      ? summaryEnglish
      : message;
  final title = 'Bug: ${_sanitizeForReport(titleBase, _maxGithubTitle)}'
      .replaceAll('\n', ' ');

  var copiedAsPrimary = reportIssueUrl.isEmpty;
  try {
    if (reportIssueUrl.isNotEmpty) {
      final uri = Uri.parse(reportIssueUrl).replace(
        queryParameters: <String, String>{
          'title': title,
          'body': payload.githubBody,
        },
      );
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    copiedAsPrimary = true;
  }
  try {
    await setFeedbackClipboard(payload.githubBody, screenshotPng);
  } catch (_) {
    // Ignore clipboard failure; caller may still show a toast.
  }
  return copiedAsPrimary;
}

/// Sends anonymized error telemetry when the user is online and telemetry is enabled.
/// Payload: sanitized message (first 200 chars), version, platform. No user id, no stack trace.
void sendErrorTelemetryIfOnline(
  WidgetRef ref, {
  required String message,
  String? details,
}) {
  final hasNetwork = ref.read(connectivityProvider);
  final telemetryEnabled = ref.read(telemetryEnabledProvider);
  if (!hasNetwork || !telemetryEnabled) return;

  final sanitizedMessage = _sanitizeForReport(message, _maxMessageForTelemetry);
  final platform = kIsWeb
      ? 'web'
      : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

  PackageInfo.fromPlatform()
      .then((info) {
        TelemetryService.sendEvent('error_occurred', {
          'message': sanitizedMessage,
          'version': '${info.version}+${info.buildNumber}',
          'platform': platform,
        }, enabled: true);
      })
      .catchError((_) {});
}
