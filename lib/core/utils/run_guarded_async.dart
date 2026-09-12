import 'package:flutter/material.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import '../widgets/toast.dart';

/// Runs [future] and on catch logs [logMessage] with [Log.warning].
/// Returns the result on success, or `null` on failure.
/// If [context] and [errorToastMessage] are provided and the context is still
/// mounted after a catch, shows an error toast with Share/Report actions.
/// [errorSummaryEnglish] is included in copied diagnostic reports (English). When
/// null, [logMessage] is used for that section.
Future<T?> runGuardedAsync<T>(
  Future<T> future,
  String logMessage, {
  BuildContext? context,
  String? errorToastMessage,
  String? errorSummaryEnglish,
}) async {
  try {
    return await future;
  } catch (e, st) {
    Log.warning(logMessage, error: e, stackTrace: st);
    final details = e.toString();
    if (context != null && context.mounted && errorToastMessage != null) {
      context.showErrorWithActions(
        errorToastMessage,
        details: details,
        stackTrace: st,
        summaryEnglish: errorSummaryEnglish ?? logMessage,
      );
    }
    return null;
  }
}
