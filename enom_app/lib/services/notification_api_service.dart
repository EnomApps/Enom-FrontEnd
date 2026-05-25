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
  /// Response shape: { data: [...], unread_count, current_page, total }
  static Future<({
    bool success,
    List<Map<String, dynamic>> notifications,
    int unreadCount,
    int currentPage,
    int total,
  })> getNotifications({int page = 1}) async {
    try {
      final url = '/api/notifications?page=$page';
      debugPrint('[NOTIF] GET $url');
      final result = await ApiService.get(url, auth: true);
      final status = result['statusCode'] as int;
      final body = result['body'];
      debugPrint('[NOTIF] status=$status');
      // Dump the raw body so we can see the actual contract. Truncate long ones.
      final bodyStr = body.toString();
      debugPrint('[NOTIF] body=${bodyStr.length > 800 ? '${bodyStr.substring(0, 800)}...(${bodyStr.length} chars)' : bodyStr}');

      if (status == 200 && body is Map<String, dynamic>) {
        // Server response shape:
        //   { notifications: { current_page, data: [...], total, last_page, ... }, unread_count }
        // Also handle a few fallback shapes for safety.
        List<dynamic> list = [];
        Map<String, dynamic>? paginator;
        final notifs = body['notifications'];
        final data = body['data'];

        if (notifs is Map<String, dynamic>) {
          paginator = notifs;
          list = (notifs['data'] as List<dynamic>?) ?? [];
        } else if (notifs is List) {
          list = notifs;
        } else if (data is Map<String, dynamic>) {
          paginator = data;
          list = (data['data'] as List<dynamic>?) ?? [];
        } else if (data is List) {
          list = data;
        }

        final unread = body['unread_count'] as int? ??
            (paginator != null ? paginator['unread_count'] as int? : null) ?? 0;
        final currentPage = (paginator?['current_page'] as int?) ??
            (body['current_page'] as int?) ?? page;
        final total = (paginator?['total'] as int?) ??
            (body['total'] as int?) ?? list.length;
        debugPrint('[NOTIF] Parsed ${list.length} items, unread=$unread, page=$currentPage, total=$total, top-level keys=${body.keys.toList()}');
        return (
          success: true,
          notifications: list.map((e) => Map<String, dynamic>.from(e as Map)).toList(),
          unreadCount: unread,
          currentPage: currentPage,
          total: total,
        );
      }
      debugPrint('[NOTIF] non-200 or unexpected body type — returning empty');
    } catch (e, st) {
      debugPrint('[NOTIF] Error: $e');
      debugPrint('[NOTIF] stack: $st');
    }
    return (
      success: false,
      notifications: <Map<String, dynamic>>[],
      unreadCount: 0,
      currentPage: page,
      total: 0,
    );
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
