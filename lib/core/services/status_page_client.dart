import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Result of fetching a Statuspage.io summary.
sealed class StatusPageResult {}

/// Successfully parsed status page summary.
class StatusPageSummary extends StatusPageResult {
  StatusPageSummary({
    required this.status,
    required this.incidents,
    required this.statusPageUrl,
  });

  final ServiceStatus status;
  final List<StatusPageIncident> incidents;
  final String statusPageUrl;
}

/// Failure to fetch or parse.
class StatusPageFailure extends StatusPageResult {
  StatusPageFailure([this.message]);

  final String? message;
}

/// Overall status from Statuspage.io (status.status.indicator / description).
class ServiceStatus {
  const ServiceStatus({
    required this.indicator,
    required this.description,
  });

  final String indicator; // none, minor, major, critical
  final String description;
}

/// Single incident from the summary (for "last couple of hours" display).
class StatusPageIncident {
  const StatusPageIncident({
    required this.name,
    required this.status,
    this.updatedAt,
  });

  final String name;
  final String status;
  final DateTime? updatedAt;
}

const _supabaseSummaryUrl = 'https://status.supabase.com/api/v2/summary.json';
const _timeout = Duration(seconds: 8);

/// Fetches Supabase status page summary. Returns [StatusPageSummary] on
/// success or [StatusPageFailure] on network/parse error.
Future<StatusPageResult> fetchSupabaseStatus() async {
  try {
    final response = await http
        .get(Uri.parse(_supabaseSummaryUrl))
        .timeout(_timeout);

    if (response.statusCode != 200) {
      return StatusPageFailure('HTTP ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>?;
    if (json == null) return StatusPageFailure('Invalid response');

    final statusObj = json['status'] as Map<String, dynamic>?;
    final indicator = statusObj?['indicator'] as String? ?? 'none';
    final description =
        statusObj?['description'] as String? ?? 'Unknown';

    final incidentsList = json['incidents'] as List<dynamic>? ?? [];
    final incidents = <StatusPageIncident>[];
    for (final e in incidentsList) {
      if (e is! Map<String, dynamic>) continue;
      final name = e['name'] as String? ?? '';
      final status = e['status'] as String? ?? '';
      final updated = e['updated_at'];
      final DateTime? updatedAt =
          updated is String ? DateTime.tryParse(updated) : null;
      incidents.add(StatusPageIncident(
        name: name,
        status: status,
        updatedAt: updatedAt,
      ));
    }

    final page = json['page'] as Map<String, dynamic>?;
    final statusPageUrl = page?['url'] as String? ?? 'https://status.supabase.com';

    return StatusPageSummary(
      status: ServiceStatus(
        indicator: indicator,
        description: description,
      ),
      incidents: incidents,
      statusPageUrl: statusPageUrl,
    );
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('StatusPage fetch error: $e\n$st');
    }
    return StatusPageFailure(e.toString());
  }
}
