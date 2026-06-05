import 'package:app_badge_plus/app_badge_plus.dart';
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
    // Let the OS badge the launcher icon from the live tray state. On Samsung
    // (One UI) this shows a numeric count even while the app is closed, with no
    // backend `unread_count` needed. The OS self-corrects the count as the user
    // dismisses notifications, which avoids the drift the old per-push
    // programmatic increment caused.
    showBadge: true,
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
      // If the backend included the new unread count, reconcile the badge now.
      final unread = unreadFromMessage(message);
      if (unread != null) updateBadge(unread);
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
      channelShowBadge: true,
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

  /// Reconcile the launcher-icon badge to the server's unread count.
  ///
  /// IMPORTANT: always *set* the badge to the server value — never increment
  /// it locally. Incrementing per-push is what caused the badge to drift from
  /// server state previously. The server's `unread_count` is the single source
  /// of truth; call this at every point the count is fetched or changes.
  static Future<void> updateBadge(int count) async {
    try {
      if (count <= 0) {
        // Samsung derives the icon badge from the live tray. Clearing the
        // programmatic count alone won't drop the badge while read pushes still
        // sit in the tray, so cancel them too to keep the badge in sync with
        // the "all read" state.
        await _local.cancelAll();
      }
      if (!await AppBadgePlus.isSupported()) return;
      if (count > 0) {
        await AppBadgePlus.updateBadge(count);
      } else {
        await AppBadgePlus.updateBadge(0); // clears the badge on supported OEMs
      }
    } catch (e) {
      debugPrint('[NOTIF] updateBadge failed: $e');
    }
  }

  /// Clear the launcher-icon badge (e.g. on logout).
  static Future<void> clearBadge() async => updateBadge(0);

  /// Read a server-supplied unread count from an FCM payload, if present.
  /// Backend must include `unread_count` in the data payload for the badge to
  /// stay correct while the app is backgrounded/terminated (see backend request).
  static int? unreadFromMessage(RemoteMessage m) {
    final raw = m.data['unread_count'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
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
