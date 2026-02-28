import 'package:flutter/material.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';

import '../widgets/toast.dart';

/// Runs [future] and on catch logs [logMessage] with [Log.warning].
/// Returns the result on success, or `null` on failure.
/// If [context] and [errorToastMessage] are provided and the context is still
/// mounted after a catch, shows an error toast.
Future<T?> runGuardedAsync<T>(
  Future<T> future,
  String logMessage, {
  BuildContext? context,
  String? errorToastMessage,
}) async {
  try {
    return await future;
  } catch (e, st) {
    Log.warning(logMessage, error: e, stackTrace: st);
    if (context != null && context.mounted && errorToastMessage != null) {
      context.showError(errorToastMessage);
    }
    return null;
  }
}
