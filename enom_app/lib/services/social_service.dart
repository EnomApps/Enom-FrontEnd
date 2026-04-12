import 'package:flutter/foundation.dart';
import 'api_service.dart';

class SocialService {
  // ─── Follow / Unfollow ───

  /// Toggle follow on a user. Returns follow status.
  static Future<({bool success, String message, bool isFollowing})> toggleFollow(int userId) async {
    final result = await ApiService.post('/api/users/$userId/follow', {}, auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    // ignore: avoid_print
    print('[Social] toggleFollow($userId) => $status: $body');
    final msg = body is Map ? (body['message'] as String? ?? '') : '';

    bool isFollowing = false;
    if (body is Map) {
      if (body.containsKey('is_following')) {
        isFollowing = body['is_following'] == true;
      } else if (body.containsKey('status')) {
        final s = body['status'].toString().toLowerCase();
        isFollowing = s == 'followed' || s == 'following';
      } else {
        final m = msg.toLowerCase();
        isFollowing = m.contains('followed') && !m.contains('unfollowed') && !m.contains('removed');
      }
    }

    // After toggling, verify with follow-status API for accuracy
    if (status == 200 || status == 201) {
      final check = await getFollowStatus(userId);
      if (check.success) isFollowing = check.isFollowing;
    }

    return (success: status == 200 || status == 201, message: msg, isFollowing: isFollowing);
  }

  /// Check if current user follows the given user.
  static Future<({bool success, bool isFollowing})> getFollowStatus(int userId) async {
    final result = await ApiService.get('/api/users/$userId/follow-status', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    final isFollowing = body is Map ? (body['is_following'] == true) : false;
    return (success: status == 200, isFollowing: isFollowing);
  }

  /// Get follow counts (followers_count + following_count) for a user.
  static Future<({bool success, int followersCount, int followingCount})> getFollowCounts(int userId) async {
    final result = await ApiService.get('/api/users/$userId/follow-counts', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];

    debugPrint('[FOLLOW_COUNTS_API] status=$status body=$body');

    if (status == 200 && body is Map) {
      // Try multiple possible field names
      final data = body['data'] is Map ? body['data'] as Map : body;
      final followers = _tryInt(data, 'followers_count') ??
          _tryInt(data, 'followersCount') ??
          _tryInt(data, 'followers') ?? 0;
      final following = _tryInt(data, 'following_count') ??
          _tryInt(data, 'followingCount') ??
          _tryInt(data, 'following') ?? 0;
      return (
        success: true,
        followersCount: followers,
        followingCount: following,
      );
    }
    return (success: false, followersCount: 0, followingCount: 0);
  }

  static int? _tryInt(Map data, String key) {
    final val = data[key];
    if (val == null) return null;
    if (val is int) return val;
    if (val is num) return val.toInt();
    if (val is String) return int.tryParse(val);
    return null;
  }

  /// Batch check follow status for multiple user IDs.
  /// Returns a map of userId → isFollowing.
  static Future<Map<int, bool>> batchFollowStatus(List<int> userIds) async {
    final result = <int, bool>{};
    // Check each unique user (API doesn't have batch endpoint)
    final futures = <Future>[];
    for (final uid in userIds.toSet()) {
      futures.add(
        getFollowStatus(uid).then((r) {
          if (r.success) result[uid] = r.isFollowing;
        }),
      );
    }
    await Future.wait(futures);
    return result;
  }

  /// Get followers of a user.
  /// API returns nested: { data: [{ follower: { id, name, ... } }] }
  static Future<({bool success, List<Map<String, dynamic>> users, Map<String, dynamic>? pagination})> getFollowers(
    int userId, {
    int page = 1,
  }) async {
    final result = await ApiService.get('/api/users/$userId/followers?page=$page', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];

    if (status == 200 && body is Map<String, dynamic>) {
      final rawList = body['data'] as List<dynamic>? ?? [];
      // Extract the nested 'follower' user object from each item
      final users = <Map<String, dynamic>>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final followerUser = item['follower'] as Map<String, dynamic>?;
          if (followerUser != null) {
            users.add(followerUser);
          } else {
            // Fallback: item itself might be the user
            users.add(item);
          }
        }
      }
      final pagination = <String, dynamic>{
        'current_page': body['current_page'] ?? 1,
        'last_page': body['last_page'] ?? 1,
      };
      return (success: true, users: users, pagination: pagination);
    }

    return (success: false, users: <Map<String, dynamic>>[], pagination: null);
  }

  /// Get users that a user is following.
  /// API returns nested: { data: [{ following: { id, name, ... } }] }
  static Future<({bool success, List<Map<String, dynamic>> users, Map<String, dynamic>? pagination})> getFollowing(
    int userId, {
    int page = 1,
  }) async {
    final result = await ApiService.get('/api/users/$userId/following?page=$page', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];

    if (status == 200 && body is Map<String, dynamic>) {
      final rawList = body['data'] as List<dynamic>? ?? [];
      // Extract the nested 'following' user object from each item
      final users = <Map<String, dynamic>>[];
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final followingUser = item['following'] as Map<String, dynamic>?;
          if (followingUser != null) {
            users.add(followingUser);
          } else {
            users.add(item);
          }
        }
      }
      final pagination = <String, dynamic>{
        'current_page': body['current_page'] ?? 1,
        'last_page': body['last_page'] ?? 1,
      };
      return (success: true, users: users, pagination: pagination);
    }

    return (success: false, users: <Map<String, dynamic>>[], pagination: null);
  }

  // ─── Save / Bookmark ───

  /// Toggle save/bookmark on a post.
  static Future<({bool success, String message, bool isSaved})> toggleSave(int postId) async {
    final result = await ApiService.post('/api/posts/$postId/save', {}, auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    // ignore: avoid_print
    print('[Social] toggleSave($postId) => $status: $body');
    final msg = body is Map ? (body['message'] as String? ?? '') : '';
    bool isSaved = false;
    if (body is Map) {
      if (body.containsKey('is_saved')) {
        isSaved = body['is_saved'] == true;
      } else if (body.containsKey('status')) {
        final s = body['status'].toString().toLowerCase();
        isSaved = s == 'saved';
      } else {
        final m = msg.toLowerCase();
        isSaved = m.contains('saved') && !m.contains('unsaved') && !m.contains('removed');
      }
    }
    return (success: status == 200 || status == 201, message: msg, isSaved: isSaved);
  }

  /// Get all saved posts for current user.
  static Future<({bool success, List<dynamic> posts, Map<String, dynamic>? pagination})> getSavedPosts({
    int page = 1,
  }) async {
    final result = await ApiService.get('/api/saved-posts?page=$page', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    // ignore: avoid_print
    print('[Social] getSavedPosts => $status: ${body is Map ? body.keys : body}');

    if (status == 200 && body is Map<String, dynamic>) {
      final posts = body['data'] as List<dynamic>? ?? body['posts'] as List<dynamic>? ?? [];
      final pagination = <String, dynamic>{
        'current_page': body['current_page'] ?? 1,
        'last_page': body['last_page'] ?? 1,
      };
      return (success: true, posts: posts, pagination: pagination);
    }

    return (success: false, posts: <dynamic>[], pagination: null);
  }

  // ─── Views ───

  /// Record a view on a post.
  static Future<bool> recordView(int postId) async {
    final result = await ApiService.post('/api/posts/$postId/view', {}, auth: true);
    return (result['statusCode'] as int) == 200 || (result['statusCode'] as int) == 201;
  }

  /// Get views count for a post.
  static Future<({bool success, int viewsCount})> getViews(int postId) async {
    final result = await ApiService.get('/api/posts/$postId/views', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    final count = body is Map ? (body['views_count'] ?? body['views'] ?? body['count'] ?? 0) : 0;
    return (success: status == 200, viewsCount: count is int ? count : int.tryParse(count.toString()) ?? 0);
  }
}
