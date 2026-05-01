import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Raw notification data returned by the native layer.
class CapturedNotification {
  final int nativeId;
  final String senderPackage;
  final String? senderTitle;
  final String body;
  final DateTime postedAt;
  final DateTime capturedAt;

  const CapturedNotification({
    required this.nativeId,
    required this.senderPackage,
    this.senderTitle,
    required this.body,
    required this.postedAt,
    required this.capturedAt,
  });

  factory CapturedNotification.fromMap(Map<dynamic, dynamic> map) {
    return CapturedNotification(
      nativeId: map['id'] as int,
      senderPackage: map['sender_package'] as String,
      senderTitle: map['sender_title'] as String?,
      body: map['body'] as String,
      postedAt: DateTime.fromMillisecondsSinceEpoch(map['posted_at'] as int),
      capturedAt:
          DateTime.fromMillisecondsSinceEpoch(map['captured_at'] as int),
    );
  }
}

/// Flutter bridge to the Android [TransactionNotificationListener] service.
///
/// On non-Android platforms, all methods are no-ops that return safe defaults.
class NotificationBridge {
  NotificationBridge._();

  static const _method = MethodChannel('com.shenepoy.hisab/scanner');
  static const _events = EventChannel('com.shenepoy.hisab/scanner_events');

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether the user has granted notification listener access in system settings.
  static Future<bool> isListenerEnabled() async {
    if (!_isAndroid) return false;
    try {
      return await _method.invokeMethod<bool>('isListenerEnabled') ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Open the Android notification listener settings page.
  static Future<void> openListenerSettings() async {
    if (!_isAndroid) return;
    await _method.invokeMethod<void>('openListenerSettings');
  }

  /// Enable or disable the scanner in the native service.
  static Future<void> setEnabled(bool enabled) async {
    if (!_isAndroid) return;
    await _method.invokeMethod<void>('setEnabled', {'enabled': enabled});
  }

  /// Update the sender whitelist in the native service.
  static Future<void> setSenders(List<String> packageNames) async {
    if (!_isAndroid) return;
    await _method.invokeMethod<void>('setSenders', {'senders': packageNames});
  }

  /// Fetch notifications captured while Flutter was not running.
  static Future<List<CapturedNotification>> getPendingNotifications() async {
    if (!_isAndroid) return [];
    try {
      final result =
          await _method.invokeMethod<List<dynamic>>('getPendingNotifications');
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map(CapturedNotification.fromMap)
          .toList();
    } on PlatformException {
      return [];
    }
  }

  /// Mark native rows as flushed after processing.
  static Future<void> markFlushed(List<int> nativeIds) async {
    if (!_isAndroid) return;
    await _method.invokeMethod<void>('markFlushed', {'ids': nativeIds});
  }

  /// Delete all captured notifications from the native database.
  static Future<void> clearAll() async {
    if (!_isAndroid) return;
    await _method.invokeMethod<void>('clearAll');
  }

  /// Stream that emits whenever a new notification is captured while the app is alive.
  static Stream<void> get onNewNotification {
    if (!_isAndroid) return const Stream.empty();
    return _events.receiveBroadcastStream().map((_) {});
  }
}
