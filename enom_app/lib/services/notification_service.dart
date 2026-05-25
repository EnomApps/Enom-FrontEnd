import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../main.dart' show rootNavigatorKey;
import '../screens/notification_screen.dart';
import 'notification_api_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize notifications: request permission, get token, register with backend.
  static Future<void> init() async {
    // Web push requires a firebase-messaging-sw.js + VAPID key that aren't set up;
    // calling getToken on web throws and blocks app startup. Skip until configured.
    if (kIsWeb) return;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Get FCM token and register with backend
    final token = await _messaging.getToken();
    debugPrint('[FCM] Token: $token');
    if (token != null) {
      await NotificationApiService.registerDeviceToken(
        token,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );
    }

    // Listen for token refresh — re-register with backend
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed: $newToken');
      NotificationApiService.registerDeviceToken(
        newToken,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
    });

    // Handle tap when app was in the background.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Tapped (background): ${message.data}');
      _openNotificationsScreen();
    });

    // Handle tap when app was terminated and launched by the notification.
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM] Launched from terminated tap: ${initial.data}');
      // The root navigator is mounted on the next frame; wait for it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openNotificationsScreen();
      });
    }
  }

  /// Push the in-app NotificationScreen onto the root navigator.
  /// Safe to call before the navigator is ready (no-ops in that case).
  static void _openNotificationsScreen() {
    final nav = rootNavigatorKey.currentState;
    if (nav == null) {
      debugPrint('[FCM] Navigator not ready — skipping nav');
      return;
    }
    nav.push(MaterialPageRoute(builder: (_) => const NotificationScreen()));
  }

  /// Get the current FCM token.
  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// Remove device token on logout.
  static Future<void> removeToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await NotificationApiService.removeDeviceToken(token);
    }
  }
}
