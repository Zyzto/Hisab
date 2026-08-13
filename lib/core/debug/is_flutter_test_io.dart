import 'dart:io' show Platform;

/// True when running under `flutter test` / integration_test harness.
bool get isFlutterTest => Platform.environment.containsKey('FLUTTER_TEST');
