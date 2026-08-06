import 'package:flutter/foundation.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:http/http.dart' as http;

import '../constants/supabase_config.dart';

/// Result of probing this app's configured Supabase project (not the public status page).
sealed class SupabaseProjectHealthResult {}

/// Project answered health successfully (API is up).
class SupabaseProjectHealthActive extends SupabaseProjectHealthResult {}

/// Free-tier / inactive project is paused (HTTP 540).
class SupabaseProjectHealthPaused extends SupabaseProjectHealthResult {}

/// Could not reach the project or got an unexpected response.
class SupabaseProjectHealthUnreachable extends SupabaseProjectHealthResult {
  SupabaseProjectHealthUnreachable([this.message]);
  final String? message;
}

/// Supabase is not configured in this build (local-only).
class SupabaseProjectHealthNotConfigured extends SupabaseProjectHealthResult {}

const _timeout = Duration(seconds: 8);

/// Supabase platform code for a paused project (see HTTP status codes docs).
@visibleForTesting
const supabaseProjectPausedStatusCode = 540;

/// Classifies an HTTP status / body from the project health probe.
@visibleForTesting
SupabaseProjectHealthResult classifySupabaseProjectHealthResponse({
  required int statusCode,
  String body = '',
}) {
  if (statusCode == supabaseProjectPausedStatusCode) {
    return SupabaseProjectHealthPaused();
  }
  final lower = body.toLowerCase();
  if (lower.contains('project is paused') ||
      lower.contains('"paused"') ||
      lower.contains('project paused')) {
    return SupabaseProjectHealthPaused();
  }
  if (statusCode >= 200 && statusCode < 300) {
    return SupabaseProjectHealthActive();
  }
  return SupabaseProjectHealthUnreachable('HTTP $statusCode');
}

/// Probes `{SUPABASE_URL}/auth/v1/health` with the anon key.
///
/// Free-tier paused projects typically return **HTTP 540**. A 2xx means the
/// API gateway/auth health endpoint is responding (project not paused).
Future<SupabaseProjectHealthResult> fetchSupabaseProjectHealth() async {
  if (!supabaseConfigAvailable) {
    return SupabaseProjectHealthNotConfigured();
  }

  final base = effectiveSupabaseUrl.replaceAll(RegExp(r'/+$'), '');
  final uri = Uri.parse('$base/auth/v1/health');

  try {
    final response = await http
        .get(
          uri,
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $supabaseAnonKey',
          },
        )
        .timeout(_timeout);

    final result = classifySupabaseProjectHealthResponse(
      statusCode: response.statusCode,
      body: response.body,
    );
    if (result is SupabaseProjectHealthUnreachable && kDebugMode) {
      Log.warning(
        'Supabase project health: HTTP ${response.statusCode} from $uri',
      );
    }
    return result;
  } catch (e, st) {
    if (kDebugMode) {
      Log.error(
        'Supabase project health probe failed',
        error: e,
        stackTrace: st,
      );
    }
    return SupabaseProjectHealthUnreachable(e.toString());
  }
}
