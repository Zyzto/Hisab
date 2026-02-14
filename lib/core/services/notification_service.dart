import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_logging_service/flutter_logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../constants/supabase_config.dart';
import '../navigation/app_router.dart';
import '../navigation/route_paths.dart';
import 'permission_service.dart';

part 'notification_service.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Top-level background message handler (required by firebase_messaging).
// Must be a top-level function — not a class method or closure.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  Log.debug('FCM background message: ${message.messageId}');
}

// ─────────────────────────────────────────────────────────────────────────────
// Android notification channel for foreground notifications
// ─────────────────────────────────────────────────────────────────────────────
const _androidChannel = AndroidNotificationChannel(
  'group_activity',
  'Group Activity',
  description: 'Notifications for group expense and membership changes',
  importance: Importance.high,
);

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService — Riverpod provider
//
// Responsibilities:
//   1. Initialize FCM and request permissions
//   2. Obtain FCM token and store in Supabase `device_tokens`
//   3. Listen for token refresh and update the table
//   4. Show foreground notifications (native on mobile, browser on web)
//   5. Handle notification taps → navigate to the relevant group
// ─────────────────────────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
class NotificationService extends _$NotificationService {
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;

  String? _currentToken;
  bool _initialized = false;

  @override
  Future<void> build() async {
    // Only initialise when Supabase + Firebase are both available
    if (!supabaseConfigAvailable || !firebaseInitialized) return;

    ref.onDispose(() {
      _foregroundSub?.cancel();
      _tokenRefreshSub?.cancel();
      _initialized = false;
    });
  }

  // ───────────────────── Public API ─────────────────────

  /// Call after Firebase.initializeApp() and after the user is authenticated.
  /// Idempotent — safe to call multiple times.
  ///
  /// [context] is optional — when provided, a non-blocking dialog is shown
  /// if the user denies notification permission, explaining how to re-enable
  /// it from system settings.
  Future<void> initialize([BuildContext? context]) async {
    if (!supabaseConfigAvailable || !firebaseInitialized || _initialized) return;

    final messaging = FirebaseMessaging.instance;

    // Request permission (shows system dialog on iOS / Android 13+ / web)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      Log.warning('NotificationService: permission denied');
      if (context != null && context.mounted) {
        PermissionService.showNotificationDeniedInfo(context);
      }
      return;
    }

    Log.info(
      'NotificationService: permission ${settings.authorizationStatus}',
    );

    // Set up foreground notification display (mobile only)
    if (!kIsWeb) {
      await _setupLocalNotifications();
    }

    // Get initial FCM token
    await _registerToken();

    // Listen for token refresh
    _tokenRefreshSub = messaging.onTokenRefresh.listen((_) async {
      await _registerToken();
    });

    // Handle foreground messages
    _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background / terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated-state notification
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _initialized = true;
  }

  /// Remove the device token from Supabase (call on sign-out).
  Future<void> unregisterToken() async {
    _initialized = false;
    _foregroundSub?.cancel();
    _foregroundSub = null;
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;

    if (_currentToken == null) return;

    try {
      final client = Supabase.instance.client;
      await client
          .from('device_tokens')
          .delete()
          .eq('token', _currentToken!);
      Log.info('NotificationService: token unregistered');
      _currentToken = null;
    } catch (e) {
      Log.warning('NotificationService: failed to unregister token', error: e);
    }
  }

  // ───────────────────── Private helpers ─────────────────────

  Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create the Android notification channel
    final androidPlugin =
        _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    await androidPlugin?.createNotificationChannel(_androidChannel);
  }

  Future<void> _registerToken() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // On web, VAPID key is required
      final String? token;
      if (kIsWeb) {
        if (fcmVapidKey.isEmpty) {
          Log.warning('NotificationService: FCM_VAPID_KEY not set, skipping web token');
          return;
        }
        token = await messaging.getToken(vapidKey: fcmVapidKey);
      } else {
        token = await messaging.getToken();
      }

      if (token == null) {
        Log.warning('NotificationService: FCM token is null');
        return;
      }

      _currentToken = token;

      // Determine platform
      final platform = kIsWeb
          ? 'web'
          : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

      // Upsert into device_tokens
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client.from('device_tokens').upsert(
        {
          'user_id': userId,
          'token': token,
          'platform': platform,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,token',
      );

      Log.info('NotificationService: token registered ($platform)');
    } catch (e, st) {
      Log.warning(
        'NotificationService: failed to register token',
        error: e,
        stackTrace: st,
      );
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    Log.debug('FCM foreground: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    if (kIsWeb) {
      // On web, the service worker handles display; nothing to do here.
      // Optionally, we could show an in-app banner/snackbar.
      return;
    }

    // Show a local notification on mobile
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['group_id'],
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final groupId = message.data['group_id'] as String?;
    if (groupId == null || groupId.isEmpty) return;

    Log.info('NotificationService: tapped notification for group $groupId');
    _navigateToGroup(groupId);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final groupId = response.payload;
    if (groupId == null || groupId.isEmpty) return;

    Log.info('NotificationService: tapped local notification for group $groupId');
    _navigateToGroup(groupId);
  }

  void _navigateToGroup(String groupId) {
    try {
      final router = ref.read(routerProvider);
      router.push(RoutePaths.groupDetail(groupId));
    } catch (e) {
      Log.warning('NotificationService: navigation failed', error: e);
    }
  }
}
