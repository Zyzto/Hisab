import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart' show ShareParams, SharePlus;
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_config.dart';
import '../services/connectivity_service.dart';
import '../telemetry/telemetry_service.dart';
import '../../features/settings/providers/settings_framework_providers.dart';

const int _maxMessageForShare = 2000;
const int _maxMessageForTelemetry = 200;
const int _maxGithubTitle = 80;
const int _maxStackChars = 800;

/// Builds plain text and GitHub issue body for an error report.
/// Uses [PackageInfo.fromPlatform] for version; [details] and [stackTrace] are optional.
Future<({String plainText, String githubBody})> buildErrorReportPayload({
  required String message,
  String? details,
  StackTrace? stackTrace,
}) async {
  String version = 'unknown';
  try {
    final info = await PackageInfo.fromPlatform();
    version = '${info.version}+${info.buildNumber}';
  } catch (_) {}

  final sanitizedMessage = _sanitizeForReport(message, _maxMessageForShare);
  final buffer = StringBuffer();
  buffer.writeln('**Error:** $sanitizedMessage');
  buffer.writeln();
  buffer.writeln('**App version:** $version');
  if (details != null && details.isNotEmpty) {
    buffer.writeln();
    buffer.writeln('**Details:**');
    buffer.writeln(details.length > _maxMessageForShare
        ? '${details.substring(0, _maxMessageForShare)}...'
        : details);
  }
  if (stackTrace != null) {
    final stackStr = stackTrace.toString();
    buffer.writeln();
    buffer.writeln('**Stack trace:**');
    buffer.writeln(stackStr.length > _maxStackChars
        ? '${stackStr.substring(0, _maxStackChars)}...'
        : stackStr);
  }

  final githubBody = buffer.toString();
  final plainText = 'Hisab error: $sanitizedMessage\nVersion: $version'
      '${details != null && details.isNotEmpty ? '\nDetails: $details' : ''}';
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
}) async {
  final payload = await buildErrorReportPayload(
    message: message,
    details: details,
    stackTrace: stackTrace,
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
  VoidCallback? onCopied,
}) async {
  final payload = await buildErrorReportPayload(
    message: message,
    details: details,
    stackTrace: stackTrace,
  );
  if (!context.mounted) return;

  final title =
      'Bug: ${_sanitizeForReport(message, _maxGithubTitle)}'.replaceAll('\n', ' ');

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

  PackageInfo.fromPlatform().then((info) {
    TelemetryService.sendEvent(
      'error_occurred',
      {
        'message': sanitizedMessage,
        'version': '${info.version}+${info.buildNumber}',
        'platform': platform,
      },
      enabled: true,
    );
  }).catchError((_) {});
}
