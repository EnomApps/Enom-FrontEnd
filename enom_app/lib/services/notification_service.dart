import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart' show rootNavigatorKey;
import '../screens/notification_screen.dart';
import 'notification_api_service.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  /// Android channel used for backend push notifications. Importance.high
  /// pops a heads-up banner and plays the default notification sound.
  static const AndroidNotificationChannel _pushChannel =
      AndroidNotificationChannel(
    'enom_push',
    'Enom Notifications',
    description: 'Likes, comments, follows, and other activity alerts',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
    // Skip launcher-icon badge — the count was drifting from server state.
    showBadge: false,
  );

  /// Initialize notifications: request permission, get token, register with backend.
  static Future<void> init() async {
    // Web push requires a firebase-messaging-sw.js + VAPID key that aren't set up;
    // calling getToken on web throws and blocks app startup. Skip until configured.
    if (kIsWeb) return;

    // Local notifications plugin — used to surface FCM messages received
    // while the app is in the foreground (which the system doesn't auto-show).
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (_) => _openNotificationsScreen(),
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_pushChannel);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: false,
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

    // Handle foreground messages — system won't auto-show these, so we
    // surface them via flutter_local_notifications so the user hears the
    // notification sound and sees a heads-up banner.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground: ${message.notification?.title}');
      _showLocalForForeground(message);
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

  /// Show a heads-up local notification (with sound) for a foreground FCM
  /// message. Background/terminated messages already trigger the system tray
  /// through the same channel, so they play the sound on their own.
  static Future<void> _showLocalForForeground(RemoteMessage m) async {
    final title = m.notification?.title ?? m.data['title'] as String? ?? 'Enom';
    final body =
        m.notification?.body ?? m.data['body'] as String? ?? 'New activity';
    final androidDetails = AndroidNotificationDetails(
      _pushChannel.id,
      _pushChannel.name,
      channelDescription: _pushChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      channelShowBadge: false,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: true,
    );
    await _local.show(
      m.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
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
