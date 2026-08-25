import 'dart:convert';

/// Role of a highlighted span inside a notification body.
enum FieldRole {
  amount,
  currency,
  merchant,
  place,
  date,
  card,
  ignore;

  static FieldRole fromString(String s) => FieldRole.values.firstWhere(
    (v) => v.name == s,
    orElse: () => FieldRole.ignore,
  );
}

/// Byte-offset span of a parsed or user-labeled field.
class FieldSpan {
  final FieldRole role;
  final int start;
  final int end;

  const FieldSpan({required this.role, required this.start, required this.end});

  FieldSpan copyWith({FieldRole? role, int? start, int? end}) {
    return FieldSpan(
      role: role ?? this.role,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'start': start,
    'end': end,
  };

  factory FieldSpan.fromJson(Map<String, dynamic> json) {
    return FieldSpan(
      role: FieldRole.fromString(json['role'] as String? ?? 'ignore'),
      start: (json['start'] as num?)?.toInt() ?? 0,
      end: (json['end'] as num?)?.toInt() ?? 0,
    );
  }

  static List<FieldSpan> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => FieldSpan.fromJson(Map<String, dynamic>.from(e)))
          .where((s) => s.end > s.start)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String encode(List<FieldSpan> spans) =>
      jsonEncode(spans.map((s) => s.toJson()).toList());
}
