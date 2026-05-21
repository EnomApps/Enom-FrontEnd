import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'notification_api_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize notifications: request permission, get token, register with backend.
  static Future<void> init() async {
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

    // Handle notification tap (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Tapped: ${message.data}');
    });
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
