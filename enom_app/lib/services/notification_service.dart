import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize notifications: request permission, get token, listen to messages.
  static Future<void> init() async {
    // Request permission (iOS + Web need this, Android 13+ also needs it)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Get FCM token
    final token = await _messaging.getToken();
    debugPrint('[FCM] Token: $token');

    // TODO: Send this token to your backend API so it can send push notifications
    // e.g. PostService.registerFcmToken(token);

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed: $newToken');
      // TODO: Update token on backend
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message: ${message.notification?.title} - ${message.notification?.body}');
      // TODO: Show local notification or in-app banner
    });

    // Handle when user taps notification (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Notification tapped: ${message.data}');
      // TODO: Navigate to relevant screen based on message.data
    });
  }

  /// Get the current FCM token.
  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }
}
