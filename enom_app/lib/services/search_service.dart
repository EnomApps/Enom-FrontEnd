import 'package:flutter/foundation.dart';
import 'api_service.dart';

/// Search service — users, posts, hashtags.
///
/// API Endpoints:
/// - GET /api/search?q=...&type=users|posts|hashtags&per_page=15
/// - GET /api/trending/hashtags?limit=20
/// - GET /api/hashtags/{name}/posts?cursor=...&per_page=15
class SearchService {
  /// Search users, posts, and/or hashtags.
  static Future<SearchResult> search(
    String query, {
    String? type, // 'users', 'posts', 'hashtags', or null for all
    int perPage = 15,
  }) async {
    try {
      var url = '/api/search?q=${Uri.encodeComponent(query)}&per_page=$perPage';
      if (type != null) url += '&type=$type';

      final response = await ApiService.get(url, auth: true);
      final status = response['statusCode'] as int;
      final body = response['body'];

      debugPrint('[SEARCH] GET $url → $status');

      if (status == 200 && body is Map<String, dynamic>) {
        return SearchResult(
          success: true,
          users: _parseList(body['users'] ?? body['data']?['users']),
          posts: _parseList(body['posts'] ?? body['data']?['posts']),
          hashtags: _parseList(body['hashtags'] ?? body['data']?['hashtags']),
        );
      }

      return const SearchResult(success: false);
    } catch (e) {
      debugPrint('[SEARCH] Error: $e');
      return const SearchResult(success: false);
    }
  }

  /// Get trending hashtags.
  static Future<List<Map<String, dynamic>>> getTrendingHashtags({
    int limit = 20,
  }) async {
    try {
      final response = await ApiService.get(
        '/api/trending/hashtags?limit=$limit',
        auth: true,
      );
      final status = response['statusCode'] as int;
      final body = response['body'];

      debugPrint('[SEARCH] Trending hashtags → $status');

      if (status == 200 && body is Map<String, dynamic>) {
        return _parseList(
          body['hashtags'] ?? body['data'] ?? body['trending'] ?? [],
        );
      }
      if (status == 200 && body is List) {
        return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('[SEARCH] Trending error: $e');
    }
    return [];
  }

  /// Get posts for a specific hashtag.
  static Future<({bool success, List<Map<String, dynamic>> posts, String? nextCursor})>
      getHashtagPosts(
    String hashtagName, {
    String? cursor,
    int perPage = 15,
  }) async {
    try {
      var url = '/api/hashtags/${Uri.encodeComponent(hashtagName)}/posts?per_page=$perPage';
      if (cursor != null) url += '&cursor=$cursor';

      final response = await ApiService.get(url, auth: true);
      final status = response['statusCode'] as int;
      final body = response['body'];

      if (status == 200 && body is Map<String, dynamic>) {
        final posts = _parseList(body['data'] ?? body['posts'] ?? []);
        final next = body['next_cursor'] as String? ??
            body['meta']?['next_cursor'] as String?;
        return (success: true, posts: posts, nextCursor: next);
      }
    } catch (e) {
      debugPrint('[SEARCH] Hashtag posts error: $e');
    }
    return (success: false, posts: <Map<String, dynamic>>[], nextCursor: null);
  }

  static List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }
}

/// Search result container.
class SearchResult {
  final bool success;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> posts;
  final List<Map<String, dynamic>> hashtags;

  const SearchResult({
    this.success = false,
    this.users = const [],
    this.posts = const [],
    this.hashtags = const [],
  });

  bool get isEmpty => users.isEmpty && posts.isEmpty && hashtags.isEmpty;
}
