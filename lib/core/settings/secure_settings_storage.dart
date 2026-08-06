import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_settings_framework/flutter_settings_framework.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [SettingsStorage] that keeps secret string keys in [FlutterSecureStorage]
/// while delegating everything else to [SharedPreferencesStorage].
///
/// On [init], migrates any plaintext secret values still present in
/// SharedPreferences into secure storage and removes the prefs copies.
class SecureSettingsStorage implements SettingsStorage {
  SecureSettingsStorage({
    required this.secretKeys,
    SharedPreferencesStorage? prefsStorage,
    FlutterSecureStorage? secureStorage,
  }) : _prefs = prefsStorage ?? SharedPreferencesStorage(),
       _secure = secureStorage ?? const FlutterSecureStorage();

  final Set<String> secretKeys;
  final SharedPreferencesStorage _prefs;
  final FlutterSecureStorage _secure;

  final Map<String, String> _secretCache = {};

  @override
  Future<void> init() async {
    await _prefs.init();
    for (final key in secretKeys) {
      try {
        final secureValue = await _secure.read(key: key);
        if (secureValue != null) {
          _secretCache[key] = secureValue;
          continue;
        }
        // Migrate plaintext SharedPreferences → secure storage.
        final legacy = _prefs.getString(key);
        if (legacy != null && legacy.isNotEmpty) {
          await _secure.write(key: key, value: legacy);
          _secretCache[key] = legacy;
          await _prefs.remove(key);
          Log.info('Migrated setting "$key" into secure storage');
        } else {
          _secretCache[key] = '';
        }
      } catch (e, st) {
        Log.warning(
          'Secure storage init failed for "$key"',
          error: e,
          stackTrace: st,
        );
        _secretCache[key] = _prefs.getString(key) ?? '';
      }
    }

    // Belt-and-suspenders: clear any leftover plaintext secret prefs.
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in secretKeys) {
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
        }
      }
    } catch (e, st) {
      Log.warning(
        'Failed clearing plaintext secret prefs',
        error: e,
        stackTrace: st,
      );
    }
  }

  bool _isSecret(String key) => secretKeys.contains(key);

  @override
  String? getString(String key) {
    if (_isSecret(key)) {
      final v = _secretCache[key];
      return (v == null || v.isEmpty) ? null : v;
    }
    return _prefs.getString(key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (_isSecret(key)) {
      try {
        await _secure.write(key: key, value: value);
        _secretCache[key] = value;
        await _prefs.remove(key);
        return true;
      } catch (e, st) {
        Log.warning(
          'Secure storage write failed for "$key"',
          error: e,
          stackTrace: st,
        );
        return false;
      }
    }
    return _prefs.setString(key, value);
  }

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  Future<bool> setInt(String key, int value) => _prefs.setInt(key, value);

  @override
  double? getDouble(String key) => _prefs.getDouble(key);

  @override
  Future<bool> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<bool> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  List<String>? getStringList(String key) => _prefs.getStringList(key);

  @override
  Future<bool> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  @override
  bool containsKey(String key) {
    if (_isSecret(key)) {
      final v = _secretCache[key];
      return v != null && v.isNotEmpty;
    }
    return _prefs.containsKey(key);
  }

  @override
  Future<bool> remove(String key) async {
    if (_isSecret(key)) {
      try {
        await _secure.delete(key: key);
      } catch (e, st) {
        Log.warning(
          'Secure storage delete failed for "$key"',
          error: e,
          stackTrace: st,
        );
      }
      _secretCache[key] = '';
      await _prefs.remove(key);
      return true;
    }
    return _prefs.remove(key);
  }

  @override
  Future<bool> clear() async {
    for (final key in secretKeys) {
      try {
        await _secure.delete(key: key);
      } catch (e) {
        Log.debug('Secure storage wipe failed for "$key"', error: e);
      }
      _secretCache[key] = '';
    }
    return _prefs.clear();
  }

  @override
  Set<String> getKeys() {
    // SharedPreferences.getKeys() is unmodifiable — copy before adding secrets.
    final keys = {..._prefs.getKeys()};
    for (final key in secretKeys) {
      if (containsKey(key)) keys.add(key);
    }
    return keys;
  }

  @override
  Future<void> reload() async {
    await _prefs.reload();
    for (final key in secretKeys) {
      try {
        _secretCache[key] = await _secure.read(key: key) ?? '';
      } catch (e, st) {
        Log.warning(
          'Secure storage reload failed for "$key"',
          error: e,
          stackTrace: st,
        );
      }
    }
  }
}
