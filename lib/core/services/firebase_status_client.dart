import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Result of fetching Firebase status (from incidents.json).
sealed class FirebaseStatusResult {}

/// Successfully parsed Firebase status with active/recent incidents.
class FirebaseStatusSummary extends FirebaseStatusResult {
  FirebaseStatusSummary({
    required this.operational,
    required this.recentIncidents,
  });

  /// True when there are no active incidents (most_recent_update.status == AVAILABLE for all recent).
  final bool operational;
  final List<FirebaseIncident> recentIncidents;
}

/// Single incident from Firebase status (incidents.json).
class FirebaseIncident {
  const FirebaseIncident({
    required this.name,
    required this.active,
    this.updatedAt,
  });

  final String name;
  final bool active;
  final DateTime? updatedAt;
}

/// Failure to fetch or parse.
class FirebaseStatusFailure extends FirebaseStatusResult {
  FirebaseStatusFailure([this.message]);

  final String? message;
}

const _firebaseIncidentsUrl = 'https://status.firebase.google.com/incidents.json';
const _timeout = Duration(seconds: 10);
const _recentHours = 6;

/// Fetches Firebase status from the public incidents.json. Returns active
/// and recent incidents (last [_recentHours] hours). No API key required.
Future<FirebaseStatusResult> fetchFirebaseStatus() async {
  try {
    final response = await http
        .get(Uri.parse(_firebaseIncidentsUrl))
        .timeout(_timeout);

    if (response.statusCode != 200) {
      return FirebaseStatusFailure('HTTP ${response.statusCode}');
    }

    final list = jsonDecode(response.body);
    if (list is! List) return FirebaseStatusFailure('Invalid response');

    final now = DateTime.now().toUtc();
    final cutoff = now.subtract(const Duration(hours: _recentHours));
    final recent = <FirebaseIncident>[];
    bool hasActive = false;

    for (final e in list) {
      if (e is! Map<String, dynamic>) continue;
      final modifiedRaw = e['modified'];
      DateTime? modified;
      if (modifiedRaw is String) {
        modified = DateTime.tryParse(modifiedRaw);
      }
      if (modified != null && modified.isBefore(cutoff)) continue;

      final desc = e['external_desc'] as String? ?? e['service_name'] as String? ?? 'Incident';
      final mostRecent = e['most_recent_update'] as Map<String, dynamic>?;
      final status = mostRecent?['status'] as String? ?? '';
      final active = status != 'AVAILABLE';

      if (active) hasActive = true;
      recent.add(FirebaseIncident(
        name: desc,
        active: active,
        updatedAt: modified,
      ));
    }

    recent.sort((a, b) {
      final at = a.updatedAt ?? DateTime(0);
      final bt = b.updatedAt ?? DateTime(0);
      return bt.compareTo(at);
    });

    return FirebaseStatusSummary(
      operational: !hasActive,
      recentIncidents: recent.take(10).toList(),
    );
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('Firebase status fetch error: $e\n$st');
    }
    return FirebaseStatusFailure(e.toString());
  }
}
