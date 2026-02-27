import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase configuration for web (push notifications / FCM).
///
/// Values must be provided at build/run time via `--dart-define` or
/// `--dart-define-from-file` (e.g. [dart_defines_online.json] for debug).
/// No defaults are committed; use CONFIGURATION.md and
/// dart_defines_online.example.json for the list of keys.
///
/// Debug: use launch config with --dart-define-from-file=dart_defines_online.json.
/// CI: GitHub Actions secrets are passed as --dart-define in the workflow.
const _apiKey =
    String.fromEnvironment('FIREBASE_API_KEY', defaultValue: '');
const _authDomain =
    String.fromEnvironment('FIREBASE_AUTH_DOMAIN', defaultValue: '');
const _projectId =
    String.fromEnvironment('FIREBASE_PROJECT_ID', defaultValue: '');
const _storageBucket =
    String.fromEnvironment('FIREBASE_STORAGE_BUCKET', defaultValue: '');
const _messagingSenderId =
    String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID', defaultValue: '');
const _appId =
    String.fromEnvironment('FIREBASE_APP_ID', defaultValue: '');

/// Returns [FirebaseOptions] for web when all required values are set.
/// On non-web, or when config is missing (e.g. no dart-define), returns null.
FirebaseOptions? get firebaseOptionsForWeb {
  if (!kIsWeb) return null;
  if (_apiKey.isEmpty || _projectId.isEmpty || _appId.isEmpty) return null;
  return const FirebaseOptions(
    apiKey: _apiKey,
    authDomain: _authDomain,
    projectId: _projectId,
    storageBucket: _storageBucket,
    messagingSenderId: _messagingSenderId,
    appId: _appId,
  );
}
