import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Notification API service.
///
/// Endpoints:
/// - GET    /api/notifications           — List notifications (paginated)
/// - POST   /api/notifications/{id}/read — Mark as read
/// - POST   /api/notifications/read-all  — Mark all as read
/// - DELETE /api/notifications/{id}      — Delete notification
/// - POST   /api/device-tokens           — Register FCM token
/// - DELETE /api/device-tokens           — Remove FCM token
class NotificationApiService {
  /// Get paginated notifications.
  static Future<({bool success, List<Map<String, dynamic>> notifications, int unreadCount})>
      getNotifications({int page = 1}) async {
    try {
      final result = await ApiService.get('/api/notifications?page=$page', auth: true);
      final status = result['statusCode'] as int;
      final body = result['body'];
      debugPrint('[NOTIF] GET notifications page=$page → $status');

      if (status == 200 && body is Map<String, dynamic>) {
        final list = body['data'] as List<dynamic>? ??
            body['notifications'] as List<dynamic>? ?? [];
        final unread = body['unread_count'] as int? ?? 0;
        return (
          success: true,
          notifications: list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          unreadCount: unread,
        );
      }
    } catch (e) {
      debugPrint('[NOTIF] Error: $e');
    }
    return (success: false, notifications: <Map<String, dynamic>>[], unreadCount: 0);
  }

  /// Mark a single notification as read.
  static Future<bool> markAsRead(int notificationId) async {
    try {
      final result = await ApiService.post(
        '/api/notifications/$notificationId/read', {}, auth: true,
      );
      return (result['statusCode'] as int) == 200;
    } catch (_) {
      return false;
    }
  }

  /// Mark all notifications as read.
  static Future<bool> markAllAsRead() async {
    try {
      final result = await ApiService.post('/api/notifications/read-all', {}, auth: true);
      return (result['statusCode'] as int) == 200;
    } catch (_) {
      return false;
    }
  }

  /// Delete a notification.
  static Future<bool> deleteNotification(int notificationId) async {
    try {
      final result = await ApiService.delete(
        '/api/notifications/$notificationId', auth: true,
      );
      return (result['statusCode'] as int) == 200;
    } catch (_) {
      return false;
    }
  }

  /// Register FCM device token for push notifications.
  static Future<bool> registerDeviceToken(String token, {String platform = 'android'}) async {
    try {
      final result = await ApiService.post('/api/device-tokens', {
        'token': token,
        'platform': platform,
      }, auth: true);
      debugPrint('[NOTIF] Register device token → ${result['statusCode']}');
      return (result['statusCode'] as int) == 200;
    } catch (_) {
      return false;
    }
  }

  /// Remove FCM device token.
  static Future<bool> removeDeviceToken(String token) async {
    try {
      final result = await ApiService.delete('/api/device-tokens', auth: true);
      return (result['statusCode'] as int) == 200;
    } catch (_) {
      return false;
    }
  }
}
