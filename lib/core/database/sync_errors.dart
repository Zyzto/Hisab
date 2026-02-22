import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether the error is an auth failure (401/403). No retry.
bool isSyncAuthError(Object e) {
  if (e is AuthException) return true;
  final code = syncErrorStatusCode(e);
  return code == 401 || code == 403;
}

/// Whether the error is transient (network, 5xx, 429). Retry with backoff.
bool isSyncTransientError(Object e) {
  if (e is TimeoutException) return true;
  final code = syncErrorStatusCode(e);
  if (code != null && (code >= 500 || code == 429)) return true;
  return !isSyncAuthError(e);
}

/// Extracts HTTP status code from auth/postgrest-style exceptions if present.
int? syncErrorStatusCode(Object e) {
  try {
    if (e is AuthException && e.statusCode != null) {
      return int.tryParse(e.statusCode!);
    }
    final dynamic d = e;
    if (d.status != null) return d.status as int?;
    if (d.statusCode != null) return d.statusCode as int?;
  } catch (_) {}
  return null;
}
