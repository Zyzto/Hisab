import 'package:flutter/foundation.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:hisab_backend/hisab_backend.dart';

const _timeout = Duration(seconds: 10);

/// Probes the backend this build is wired to, so the status sheet can tell
/// "your connection is down" apart from "the service is down".
///
/// Never throws: an unreachable backend is a result, not an error.
Future<CloudHealthResult> fetchCloudHealth() async {
  final health = cloudBackend?.health;
  if (health == null) {
    return const CloudHealthResult(CloudHealthStatus.notConfigured);
  }
  try {
    return await health.probe().timeout(_timeout);
  } catch (e, st) {
    if (kDebugMode) {
      Log.error('Cloud health probe failed', error: e, stackTrace: st);
    }
    return CloudHealthResult(CloudHealthStatus.unreachable, e.toString());
  }
}
