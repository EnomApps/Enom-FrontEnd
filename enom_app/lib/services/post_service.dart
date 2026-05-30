import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class PostService {
  /// Get paginated feed posts using cursor-based pagination.
  /// Pass [cursor] from the previous response's `next_cursor` to load the next page.
  /// Optionally filter by [userId].
  static Future<({bool success, List<dynamic> posts, Map<String, dynamic>? pagination})> getFeed({
    String? cursor,
    int? userId,
    int perPage = 10,
  }) async {
    String endpoint = '/api/posts?per_page=$perPage';
    if (cursor != null) endpoint += '&cursor=$cursor';
    if (userId != null) endpoint += '&user_id=$userId';

    final result = await ApiService.get(endpoint, auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];

    if (status == 200 && body is Map<String, dynamic>) {
      final posts = body['data'] as List<dynamic>? ?? [];

      // ── TEMP DIAGNOSTIC (thumbnail issue) ──
      // Dump the media field for the first page so the backend team can see
      // exactly what the API is returning for recent video posts. Only fires
      // on the first page (no cursor) to keep logs manageable.
      if (cursor == null) {
        debugPrint('[THUMB_DEBUG] endpoint=$endpoint  postCount=${posts.length}');
        for (final p in posts.take(8)) {
          if (p is Map<String, dynamic>) {
            final summary = {
              'id': p['id'],
              'created_at': p['created_at'],
              'user_id': (p['user'] is Map ? p['user']['id'] : p['user_id']),
              'media': p['media'],
            };
            debugPrint('[THUMB_DEBUG] post=${jsonEncode(summary)}');
          }
        }
      }
      // ── END DIAGNOSTIC ──

      final pagination = <String, dynamic>{
        'next_cursor': body['next_cursor'],
        'prev_cursor': body['prev_cursor'],
        'next_page_url': body['next_page_url'],
      };
      return (success: true, posts: posts, pagination: pagination);
    }

    return (success: false, posts: <dynamic>[], pagination: null);
  }

  /// Create a new post with optional media files.
  static Future<({bool success, String message, Map<String, dynamic>? post})> createPost({
    String? content,
    String visibility = 'public',
    List<Uint8List>? mediaBytes,
    List<String>? mediaNames,
  }) async {
    final fields = <String, String>{
      if (content != null && content.isNotEmpty) 'content': content,
      'visibility': visibility,
    };

    final result = await ApiService.postMultipartMultiFile(
      '/api/posts',
      fields: fields,
      fileField: 'media',
      filesBytes: mediaBytes,
      fileNames: mediaNames,
      auth: true,
    );

    final status = result['statusCode'] as int;
    final body = result['body'];

    if (status == 201 && body is Map<String, dynamic>) {
      return (
        success: true,
        message: body['message'] as String? ?? 'Post created',
        post: body['post'] as Map<String, dynamic>?,
      );
    }

    final msg = body is Map ? (body['message'] as String? ?? 'Failed to create post') : 'Failed to create post';
    return (success: false, message: msg, post: null);
  }

  /// Delete a post by id.
  static Future<({bool success, String message})> deletePost(int postId) async {
    final result = await ApiService.delete('/api/posts/$postId', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    final msg = body is Map ? (body['message'] as String? ?? '') : '';

    return (success: status == 200, message: msg);
  }

  /// Update a post's content and/or visibility (text only).
  static Future<({bool success, String message, Map<String, dynamic>? post})> updatePost(
    int postId, {
    String? content,
    String? visibility,
  }) async {
    final body = <String, dynamic>{
      if (content != null) 'content': content,
      if (visibility != null) 'visibility': visibility,
    };

    final result = await ApiService.put('/api/posts/$postId', body, auth: true);
    final status = result['statusCode'] as int;
    final resBody = result['body'];

    if (status == 200 && resBody is Map<String, dynamic>) {
      return (
        success: true,
        message: resBody['message'] as String? ?? 'Post updated',
        post: resBody['post'] as Map<String, dynamic>?,
      );
    }

    final msg = resBody is Map ? (resBody['message'] as String? ?? 'Failed to update post') : 'Failed to update post';
    return (success: false, message: msg, post: null);
  }

  /// Update a post with media support (uses POST + _method=PUT for multipart).
  static Future<({bool success, String message, Map<String, dynamic>? post})> updatePostWithMedia(
    int postId, {
    String? content,
    String? visibility,
    List<Uint8List>? newMediaBytes,
    List<String>? newMediaNames,
    List<int>? keepMediaIds,
  }) async {
    final fields = <String, String>{
      '_method': 'PUT',
      if (content != null) 'content': content,
      if (visibility != null) 'visibility': visibility,
    };

    // Tell the server which existing media to keep
    if (keepMediaIds != null) {
      for (int i = 0; i < keepMediaIds.length; i++) {
        fields['keep_media[$i]'] = keepMediaIds[i].toString();
      }
    }

    final result = await ApiService.postMultipartMultiFile(
      '/api/posts/$postId',
      fields: fields,
      fileField: 'media',
      filesBytes: newMediaBytes,
      fileNames: newMediaNames,
      auth: true,
    );

    final status = result['statusCode'] as int;
    final resBody = result['body'];

    if (status == 200 && resBody is Map<String, dynamic>) {
      return (
        success: true,
        message: resBody['message'] as String? ?? 'Post updated',
        post: resBody['post'] as Map<String, dynamic>?,
      );
    }

    final msg = resBody is Map ? (resBody['message'] as String? ?? 'Failed to update post') : 'Failed to update post';
    return (success: false, message: msg, post: null);
  }

  /// Toggle a reaction on a post. Type: like, love, haha, wow.
  static Future<({bool success, String message})> toggleReaction(int postId, String type) async {
    // Use /like for simple likes, /react for other reaction types
    final endpoint = type == 'like'
        ? '/api/posts/$postId/like'
        : '/api/posts/$postId/react';
    final body = type == 'like' ? <String, dynamic>{} : {'type': type};

    final result = await ApiService.post(endpoint, body, auth: true);
    final status = result['statusCode'] as int;
    final resBody = result['body'];
    final msg = resBody is Map ? (resBody['message'] as String? ?? '') : '';

    debugPrint('[PostService.toggleReaction] postId=$postId type=$type endpoint=$endpoint status=$status body=$resBody');

    // Accept both 200 and 201 as success
    return (success: status == 200 || status == 201, message: msg);
  }

  /// Get paginated comments for a post.
  static Future<({bool success, List<dynamic> comments, Map<String, dynamic>? pagination})> getComments(
    int postId, {
    int page = 1,
  }) async {
    final result = await ApiService.get('/api/posts/$postId/comments?page=$page', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];

    if (status == 200 && body is Map<String, dynamic>) {
      final rawComments = body['data'] as List<dynamic>? ?? [];

      // Debug: print raw API response to see the actual structure
      debugPrint('[PostService.getComments] raw keys: ${body.keys.toList()}');
      if (rawComments.isNotEmpty) {
        debugPrint('[PostService.getComments] first comment keys: ${(rawComments.first as Map?)?.keys.toList()}');
      }

      // Flatten: if the API nests replies inside each comment, extract them.
      final flatComments = <dynamic>[];
      for (final c in rawComments) {
        if (c is Map<String, dynamic>) {
          flatComments.add(c);
          // Check for nested replies array (common Laravel pattern)
          final replies = c['replies'] as List<dynamic>?;
          if (replies != null) {
            for (final r in replies) {
              if (r is Map<String, dynamic>) {
                // Ensure parent_id is set on nested replies
                r['parent_id'] ??= c['id'];
                flatComments.add(r);
              }
            }
          }
        }
      }

      final pagination = <String, dynamic>{
        'current_page': body['current_page'],
        'last_page': body['last_page'],
      };
      return (success: true, comments: flatComments, pagination: pagination);
    }

    return (success: false, comments: <dynamic>[], pagination: null);
  }

  /// Add a comment to a post. Optionally reply to a parent comment.
  static Future<({bool success, String message})> addComment(
    int postId, {
    required String content,
    int? parentId,
  }) async {
    final body = <String, dynamic>{
      'content': content,
      if (parentId != null) 'parent_id': parentId,
    };

    final result = await ApiService.post('/api/posts/$postId/comments', body, auth: true);
    final status = result['statusCode'] as int;
    final resBody = result['body'];
    final msg = resBody is Map ? (resBody['message'] as String? ?? '') : '';

    return (success: status == 201, message: msg);
  }

  /// Get the list of users who reacted to a post.
  static Future<({bool success, List<dynamic> reactions})> getReactions(int postId) async {
    final result = await ApiService.get('/api/posts/$postId/likes', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];

    debugPrint('[getReactions] postId=$postId status=$status body=$body');

    if (status == 200 && body is Map<String, dynamic>) {
      // Try common response structures: data, reactions, likes
      final reactions = body['data'] ?? body['reactions'] ?? body['likes'] ?? [];
      if (reactions is List) {
        return (success: true, reactions: reactions);
      }
      // If data is a map with nested list (e.g. { data: { reactions: [...] } })
      if (reactions is Map<String, dynamic>) {
        final nested = reactions['reactions'] ?? reactions['likes'] ?? reactions['data'] ?? [];
        if (nested is List) {
          return (success: true, reactions: nested);
        }
      }
      return (success: true, reactions: <dynamic>[]);
    }

    // Some APIs return a direct list
    if (status == 200 && body is List<dynamic>) {
      return (success: true, reactions: body);
    }

    return (success: false, reactions: <dynamic>[]);
  }

  /// Get shareable link for a post.
  static Future<({bool success, String link})> getShareLink(int postId) async {
    final result = await ApiService.get('/api/posts/$postId/share-link', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];

    debugPrint('[getShareLink] postId=$postId status=$status body=$body');

    if (status == 200 && body is Map<String, dynamic>) {
      final link = (body['share_url'] ?? body['link'] ?? body['url'] ?? body['share_link'] ?? body['data'] ?? '') as String;
      return (success: true, link: link);
    }

    return (success: false, link: '');
  }

  /// Delete a comment by id.
  static Future<({bool success, String message})> deleteComment(int commentId) async {
    final result = await ApiService.delete('/api/comments/$commentId', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    final msg = body is Map ? (body['message'] as String? ?? '') : '';

    return (success: status == 200, message: msg);
  }

  /// PUT /api/comments/{id} — Update/edit a comment.
  static Future<({bool success, String message})> updateComment(
      int commentId, String content) async {
    final result = await ApiService.put(
        '/api/comments/$commentId', {'content': content}, auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    final msg = body is Map ? (body['message'] as String? ?? '') : '';
    return (success: status == 200, message: msg);
  }

  /// POST /api/comments/{id}/like — Toggle like on a comment.
  static Future<({bool success, bool liked})> toggleCommentLike(int commentId) async {
    final result = await ApiService.post('/api/comments/$commentId/like', {}, auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    if (status == 200 && body is Map) {
      return (success: true, liked: body['liked'] as bool? ?? true);
    }
    return (success: false, liked: false);
  }

  /// GET /api/comments/{id}/likes — Get users who liked a comment.
  static Future<List<Map<String, dynamic>>> getCommentLikes(int commentId) async {
    final result = await ApiService.get('/api/comments/$commentId/likes', auth: true);
    if ((result['statusCode'] as int) == 200) {
      final body = result['body'];
      if (body is Map && body['data'] is List) {
        return (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }

  /// POST /api/posts/{postId}/repost — Toggle repost with optional quote.
  static Future<({bool success, bool reposted, String message})> toggleRepost(
      int postId, {String? quote}) async {
    final body = <String, dynamic>{};
    if (quote != null) body['quote'] = quote;
    final result = await ApiService.post('/api/posts/$postId/repost', body, auth: true);
    final status = result['statusCode'] as int;
    final resp = result['body'];
    if (status == 200 && resp is Map) {
      return (
        success: true,
        reposted: resp['reposted'] as bool? ?? true,
        message: resp['message'] as String? ?? '',
      );
    }
    return (success: false, reposted: false, message: '');
  }

  /// GET /api/posts/{postId}/reposts — Get users who reposted.
  static Future<List<Map<String, dynamic>>> getReposts(int postId) async {
    final result = await ApiService.get('/api/posts/$postId/reposts', auth: true);
    if ((result['statusCode'] as int) == 200) {
      final body = result['body'];
      if (body is Map && body['data'] is List) {
        return (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }
    return [];
  }

  /// GET /api/posts/{postId}/like-status — Check like/reaction status.
  static Future<({bool liked, String? reactionType})> getLikeStatus(int postId) async {
    final result = await ApiService.get('/api/posts/$postId/like-status', auth: true);
    if ((result['statusCode'] as int) == 200) {
      final body = result['body'];
      if (body is Map) {
        return (
          liked: body['liked'] as bool? ?? body['reacted'] as bool? ?? false,
          reactionType: body['reaction_type'] as String?,
        );
      }
    }
    return (liked: false, reactionType: null);
  }

  /// GET /api/posts/{postId}/save-status — Check if post is saved.
  static Future<bool> getSaveStatus(int postId) async {
    final result = await ApiService.get('/api/posts/$postId/save-status', auth: true);
    if ((result['statusCode'] as int) == 200) {
      final body = result['body'];
      if (body is Map) {
        return body['saved'] as bool? ?? body['is_saved'] as bool? ?? false;
      }
    }
    return false;
  }

  /// POST /api/posts/{postId}/not-interested — Tell the feed to show fewer
  /// posts like this one. Fire-and-forget; we remove the post locally either
  /// way so the user gets instant feedback.
  static Future<bool> markNotInterested(int postId) async {
    final result =
        await ApiService.post('/api/posts/$postId/not-interested', {}, auth: true);
    final status = result['statusCode'] as int;
    return status == 200 || status == 201;
  }

  /// DELETE /api/posts/{postId}/not-interested — Undo a "not interested" mark
  /// (rarely needed).
  static Future<bool> undoNotInterested(int postId) async {
    final result =
        await ApiService.delete('/api/posts/$postId/not-interested', auth: true);
    final status = result['statusCode'] as int;
    return status == 200;
  }

  /// GET /api/posts/for-you — Personalized "For You" feed.
  static Future<({bool success, List<dynamic> posts, String? nextCursor})>
      getForYouFeed({String? cursor, int perPage = 15}) async {
    var url = '/api/posts/for-you?per_page=$perPage';
    if (cursor != null) url += '&cursor=$cursor';
    final result = await ApiService.get(url, auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    if (status == 200 && body is Map) {
      final posts = body['data'] as List<dynamic>? ?? [];
      final next = body['next_cursor'] as String?;
      return (success: true, posts: posts, nextCursor: next);
    }
    return (success: false, posts: <dynamic>[], nextCursor: null);
  }
}
