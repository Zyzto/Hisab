import 'dart:async';

import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:hisab_backend/hisab_backend.dart';

/// Whether the error is an auth failure (401/403). No retry.
bool isSyncAuthError(Object e) {
  if (e is CloudException) return e.isAuthError;
  final code = syncErrorStatusCode(e);
  return code == 401 || code == 403;
}

/// Whether the error is transient (network, 5xx, 429). Retry with backoff.
bool isSyncTransientError(Object e) {
  if (e is TimeoutException) return true;
  if (e is CloudException && e.isTransient) return true;
  final code = syncErrorStatusCode(e);
  if (code != null && (code >= 500 || code == 429)) return true;
  return !isSyncAuthError(e);
}

/// Extracts an HTTP status code from the error when it carries one.
int? syncErrorStatusCode(Object e) {
  if (e is CloudException) return e.statusCode;
  try {
    final dynamic d = e;
    if (d.status != null) return d.status as int?;
    if (d.statusCode != null) return d.statusCode as int?;
  } catch (probeError) {
    Log.debug('syncErrorStatusCode probe failed', error: probeError);
  }
  return null;
}
