import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Formats a diagnostic report without sending it anywhere automatically.
String buildErrorReportText({
  required String message,
  String? details,
  StackTrace? stackTrace,
  String? summaryEnglish,
  String? uiLocaleTag,
}) {
  final buffer = StringBuffer()
    ..writeln('Hisab local diagnostic')
    ..writeln('Locale: ${uiLocaleTag ?? 'unknown'}')
    ..writeln('Message: ${summaryEnglish ?? message}');
  if (details != null && details.isNotEmpty) buffer.writeln('Details: $details');
  if (stackTrace != null) buffer.writeln('Stack trace:\n$stackTrace');
  return buffer.toString();
}

String readUiLocaleTagForReport(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

Future<void> shareErrorReport(
  BuildContext context, {
  required String message,
  String? details,
  StackTrace? stackTrace,
  String? summaryEnglish,
  String? uiLocaleTag,
}) async {
  final report = buildErrorReportText(
    message: message,
    details: details,
    stackTrace: stackTrace,
    summaryEnglish: summaryEnglish,
    uiLocaleTag: uiLocaleTag ?? readUiLocaleTagForReport(context),
  );
  await SharePlus.instance.share(ShareParams(text: report));
}

/// Copies diagnostics locally. The public build never uploads reports.
Future<void> copyErrorReportToClipboard(
  BuildContext context, {
  required String message,
  String? details,
  StackTrace? stackTrace,
  String? summaryEnglish,
  String? uiLocaleTag,
  VoidCallback? onCopied,
}) async {
  final report = buildErrorReportText(
    message: message,
    details: details,
    stackTrace: stackTrace,
    summaryEnglish: summaryEnglish,
    uiLocaleTag: uiLocaleTag ?? readUiLocaleTagForReport(context),
  );
  await Clipboard.setData(ClipboardData(text: report));
  onCopied?.call();
}
