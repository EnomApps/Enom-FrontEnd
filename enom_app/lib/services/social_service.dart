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

  /// GET /api/users/discover — Suggested people to follow.
  /// Each entry carries: id, name, username, bio, profile_image_url,
  /// followers_count, mutual_count, reason.
  static Future<List<Map<String, dynamic>>> getDiscoverPeople({int limit = 20}) async {
    final result = await ApiService.get('/api/users/discover?limit=$limit', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];

    if (status == 200 && body is Map<String, dynamic>) {
      final raw = body['data'] as List<dynamic>? ?? [];
      return raw.whereType<Map<String, dynamic>>().toList();
    }

    debugPrint('[Social] getDiscoverPeople status=$status');
    return <Map<String, dynamic>>[];
  }

  // ─── Favourites (private "Close Friends" list) ───

  /// POST /api/users/{userId}/favourite — Add/remove a user from your private
  /// favourites list. Returns the resulting favourite state.
  static Future<({bool success, bool isFavourite, String message})> toggleFavourite(int userId) async {
    final result = await ApiService.post('/api/users/$userId/favourite', {}, auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    final msg = body is Map ? (body['message'] as String? ?? '') : '';

    bool isFav = false;
    if (body is Map) {
      if (body.containsKey('is_favourite')) {
        isFav = body['is_favourite'] == true;
      } else if (body.containsKey('favourited')) {
        isFav = body['favourited'] == true;
      } else {
        final m = msg.toLowerCase();
        isFav = m.contains('added') || (m.contains('favourite') && !m.contains('removed'));
      }
    }

    // Verify with the status endpoint for accuracy.
    if (status == 200 || status == 201) {
      final check = await getFavouriteStatus(userId);
      if (check.success) isFav = check.isFavourite;
    }

    return (success: status == 200 || status == 201, isFavourite: isFav, message: msg);
  }

  /// GET /api/users/{userId}/favourite-status — Is this user in your favourites.
  static Future<({bool success, bool isFavourite})> getFavouriteStatus(int userId) async {
    final result = await ApiService.get('/api/users/$userId/favourite-status', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    final isFav = body is Map
        ? (body['is_favourite'] == true ||
            body['favourited'] == true ||
            body['favourite'] == true)
        : false;
    return (success: status == 200, isFavourite: isFav);
  }

  /// GET /api/favourites — Your private list of favourite users.
  static Future<List<Map<String, dynamic>>> getFavouriteUsers() async {
    final result = await ApiService.get('/api/favourites', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    if (status == 200 && body is Map<String, dynamic>) {
      final raw = body['data'] as List<dynamic>? ??
          body['favourites'] as List<dynamic>? ??
          body['users'] as List<dynamic>? ??
          [];
      // Some APIs nest the user object (e.g. { favourite_user: {...} }).
      return raw.whereType<Map<String, dynamic>>().map((item) {
        final nested = item['favourite_user'] ?? item['user'] ?? item['favourite'];
        return nested is Map<String, dynamic> ? nested : item;
      }).toList();
    }
    if (status == 200 && body is List) {
      return body.whereType<Map<String, dynamic>>().toList();
    }
    debugPrint('[Social] getFavouriteUsers status=$status');
    return <Map<String, dynamic>>[];
  }

  /// GET /api/posts/favourites — Chronological feed of posts from your
  /// favourite users only.
  static Future<({bool success, List<dynamic> posts, String? nextCursor})> getFavouritesFeed({
    String? cursor,
    int perPage = 15,
  }) async {
    var url = '/api/posts/favourites?per_page=$perPage';
    if (cursor != null) url += '&cursor=$cursor';
    final result = await ApiService.get(url, auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    if (status == 200 && body is Map<String, dynamic>) {
      final posts = body['data'] as List<dynamic>? ?? body['posts'] as List<dynamic>? ?? [];
      final next = body['next_cursor'] as String?;
      return (success: true, posts: posts, nextCursor: next);
    }
    return (success: false, posts: <dynamic>[], nextCursor: null);
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

  /// GET /api/users/{userId}/profile — View another user's public profile.
  static Future<({bool success, Map<String, dynamic>? user})> getUserProfile(int userId) async {
    final result = await ApiService.get('/api/users/$userId/profile', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    if (status == 200 && body is Map<String, dynamic>) {
      final user = body['user'] as Map<String, dynamic>? ?? body;
      return (success: true, user: user);
    }
    return (success: false, user: null);
  }

  /// GET /api/users/{userId}/share-link — Get shareable profile link.
  static Future<String?> getProfileShareLink(int userId) async {
    final result = await ApiService.get('/api/users/$userId/share-link', auth: true);
    if ((result['statusCode'] as int) == 200) {
      final body = result['body'];
      if (body is Map) {
        return body['share_url'] as String? ?? body['link'] as String?;
      }
    }
    return null;
  }

  /// GET /api/languages — Get server-side supported languages.
  static Future<List<Map<String, dynamic>>> getLanguages({String? region}) async {
    var url = '/api/languages';
    if (region != null) url += '?region=$region';
    final result = await ApiService.get(url);
    if ((result['statusCode'] as int) == 200) {
      final body = result['body'];
      if (body is Map && body['data'] is List) {
        return (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (body is List) {
        return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }

  /// GET /api/languages/regions — Get language regions.
  static Future<List<String>> getLanguageRegions() async {
    final result = await ApiService.get('/api/languages/regions');
    if ((result['statusCode'] as int) == 200) {
      final body = result['body'];
      if (body is Map && body['data'] is List) {
        return (body['data'] as List).map((e) => e.toString()).toList();
      }
      if (body is List) {
        return body.map((e) => e.toString()).toList();
      }
    }
    return [];
  }
}
