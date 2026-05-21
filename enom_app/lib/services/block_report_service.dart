import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Block & Report service.
///
/// Endpoints:
/// - POST   /api/users/{userId}/block        — Toggle block
/// - GET    /api/users/{userId}/block-status  — Check block status
/// - GET    /api/blocked-users               — List blocked users
/// - POST   /api/report                      — Report content
class BlockReportService {
  /// Toggle block/unblock a user.
  static Future<({bool success, bool isBlocked, String message})> toggleBlock(int userId) async {
    try {
      final result = await ApiService.post('/api/users/$userId/block', {}, auth: true);
      final status = result['statusCode'] as int;
      final body = result['body'] as Map<String, dynamic>? ?? {};
      debugPrint('[BLOCK] Toggle userId=$userId → $status');
      if (status == 200) {
        return (
          success: true,
          isBlocked: body['blocked'] as bool? ?? body['is_blocked'] as bool? ?? true,
          message: body['message'] as String? ?? 'Done',
        );
      }
      return (success: false, isBlocked: false, message: body['message'] as String? ?? 'Failed');
    } catch (e) {
      return (success: false, isBlocked: false, message: e.toString());
    }
  }

  /// Check if a user is blocked.
  static Future<bool> isBlocked(int userId) async {
    try {
      final result = await ApiService.get('/api/users/$userId/block-status', auth: true);
      if ((result['statusCode'] as int) == 200) {
        final body = result['body'];
        if (body is Map) {
          return body['is_blocked'] as bool? ?? body['blocked'] as bool? ?? false;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Get list of blocked users.
  static Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    try {
      final result = await ApiService.get('/api/blocked-users', auth: true);
      if ((result['statusCode'] as int) == 200) {
        final body = result['body'];
        if (body is Map && body['data'] is List) {
          return (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
        if (body is List) {
          return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Report a post, comment, or user.
  static Future<({bool success, String message})> report({
    required String type, // 'post', 'comment', 'user'
    required int id,
    required String reason, // 'spam', 'harassment', 'nudity', 'violence', 'misinformation', 'other'
    String? description,
  }) async {
    try {
      final body = <String, dynamic>{
        'type': type,
        'id': id,
        'reason': reason,
        if (description != null) 'description': description,
      };
      final result = await ApiService.post('/api/report', body, auth: true);
      final status = result['statusCode'] as int;
      final respBody = result['body'] as Map<String, dynamic>? ?? {};
      debugPrint('[REPORT] $type/$id reason=$reason → $status');
      if (status == 201 || status == 200) {
        return (success: true, message: respBody['message'] as String? ?? 'Report submitted');
      }
      return (success: false, message: respBody['message'] as String? ?? 'Failed to report');
    } catch (e) {
      return (success: false, message: e.toString());
    }
  }
}
