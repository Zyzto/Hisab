/// Ring buffer of recent route locations for error reports (GitHub / share).
/// Paths are route URIs (ASCII); section text for reports is written in English.
class NavigationTrace {
  NavigationTrace._();
  static final NavigationTrace instance = NavigationTrace._();

  static const int _maxEntries = 24;

  final List<({DateTime atUtc, String location})> _entries = [];

  /// Records a navigation target. Skips consecutive duplicates.
  void recordUri(String location) {
    final normalized = location.trim();
    if (normalized.isEmpty) return;
    if (_entries.isNotEmpty && _entries.last.location == normalized) return;
    _entries.add((atUtc: DateTime.now().toUtc(), location: normalized));
    while (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
  }

  /// English markdown section: recent screens / route changes (oldest first).
  String buildReportSectionEnglish({int maxChars = 2400}) {
    if (_entries.isEmpty) {
      return '**Recent screens (route changes, oldest first):**\n'
          '_No navigation recorded yet in this session._\n\n';
    }
    final buf = StringBuffer();
    buf.writeln(
      '**Recent screens (route changes, oldest first):**',
    );
    buf.writeln(
      '_Each line is UTC time and app path (query string included if present)._',
    );
    for (final e in _entries) {
      final safe = e.location.replaceAll('`', "'");
      buf.writeln('- `${e.atUtc.toIso8601String()}`  `$safe`');
    }
    buf.writeln();
    var s = buf.toString();
    if (s.length > maxChars) {
      s = '${s.substring(0, maxChars)}…\n_(navigation list truncated for size)_\n\n';
    }
    return s;
  }
}
