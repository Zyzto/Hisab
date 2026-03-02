import 'package:flutter/material.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show WidgetRef;

import 'error_report_helper.dart';
import '../widgets/toast.dart';

/// Runs [future] and on catch logs [logMessage] with [Log.warning].
/// Returns the result on success, or `null` on failure.
/// If [context] and [errorToastMessage] are provided and the context is still
/// mounted after a catch, shows an error toast with Share/Report actions.
/// If [ref] is provided, sends anonymized error telemetry when online and telemetry is enabled.
Future<T?> runGuardedAsync<T>(
  Future<T> future,
  String logMessage, {
  BuildContext? context,
  String? errorToastMessage,
  WidgetRef? ref,
}) async {
  try {
    return await future;
  } catch (e, st) {
    Log.warning(logMessage, error: e, stackTrace: st);
    final details = e.toString();
    if (ref != null) {
      sendErrorTelemetryIfOnline(
        ref,
        message: errorToastMessage ?? details,
        details: details,
      );
    }
    if (context != null && context.mounted && errorToastMessage != null) {
      context.showErrorWithActions(
        errorToastMessage,
        details: details,
        stackTrace: st,
      );
    }
    return null;
  }
}
