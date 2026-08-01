import 'package:shared_preferences/shared_preferences.dart';

/// Persists celebration keys so join/leave (and similar) fire once even across
/// sync rebuilds and app restarts.
class CelebrationDedupe {
  CelebrationDedupe._();

  static final CelebrationDedupe instance = CelebrationDedupe._();

  static const _prefsKey = 'celebration_dedupe_v1';
  static const _maxKeys = 800;

  final Set<String> _memory = <String>{};
  Future<void>? _loadFuture;
  bool _loaded = false;

  Future<void> _ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loadFuture ??= () async {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_prefsKey) ?? const <String>[];
      _memory.addAll(stored);
      _loaded = true;
    }();
  }

  /// Returns true only the first time [key] is claimed.
  Future<bool> tryClaim(String key) async {
    if (!_memory.add(key)) return false;
    await _ensureLoaded();
    // Another isolate/session may have persisted it; memory already has key.
    final prefs = await SharedPreferences.getInstance();
    final stored = List<String>.from(prefs.getStringList(_prefsKey) ?? const []);
    if (stored.contains(key)) {
      return false;
    }
    stored.add(key);
    while (stored.length > _maxKeys) {
      stored.removeAt(0);
    }
    await prefs.setStringList(_prefsKey, stored);
    return true;
  }

  /// Mark keys as already seen without celebrating (cold open / first snapshot).
  Future<void> seed(Iterable<String> keys) async {
    await _ensureLoaded();
    final prefs = await SharedPreferences.getInstance();
    final stored = List<String>.from(prefs.getStringList(_prefsKey) ?? const []);
    var changed = false;
    for (final key in keys) {
      if (_memory.add(key)) {
        stored.add(key);
        changed = true;
      }
    }
    if (!changed) return;
    while (stored.length > _maxKeys) {
      stored.removeAt(0);
    }
    await prefs.setStringList(_prefsKey, stored);
  }

  /// Test helper — clears in-memory claims only.
  void debugReset() {
    _memory.clear();
    _loaded = false;
    _loadFuture = null;
  }

  /// Debug menu helper — clears memory and persisted keys.
  Future<void> debugClearAll() async {
    debugReset();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
