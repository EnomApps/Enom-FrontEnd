import 'dart:typed_data';
import 'api_service.dart';

class PostService {
  /// Get paginated feed posts. Optionally filter by [userId].
  static Future<({bool success, List<dynamic> posts, Map<String, dynamic>? pagination})> getFeed({
    int page = 1,
    int? userId,
  }) async {
    String endpoint = '/api/posts?page=$page&per_page=5';
    if (userId != null) endpoint += '&user_id=$userId';

    final result = await ApiService.get(endpoint, auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];

    if (status == 200 && body is Map<String, dynamic>) {
      final posts = body['data'] as List<dynamic>? ?? [];
      // Debug: log first post media structure
      if (posts.isNotEmpty) {
        final first = posts[0];
        if (first is Map) {
          // ignore: avoid_print
          print('[Feed] first post keys: ${first.keys.toList()}');
          // ignore: avoid_print
          print('[Feed] first post media: ${first['media']}');
        }
      }
      final pagination = <String, dynamic>{
        'current_page': body['current_page'],
        'last_page': body['last_page'],
        'per_page': body['per_page'],
        'total': body['total'],
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
    final result = await ApiService.post(
      '/api/posts/$postId/reactions',
      {'type': type},
      auth: true,
    );
    final status = result['statusCode'] as int;
    final body = result['body'];
    final msg = body is Map ? (body['message'] as String? ?? '') : '';

    return (success: status == 200, message: msg);
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
      final comments = body['data'] as List<dynamic>? ?? [];
      final pagination = <String, dynamic>{
        'current_page': body['current_page'],
        'last_page': body['last_page'],
      };
      return (success: true, comments: comments, pagination: pagination);
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

  /// Delete a comment by id.
  static Future<({bool success, String message})> deleteComment(int commentId) async {
    final result = await ApiService.delete('/api/comments/$commentId', auth: true);
    final status = result['statusCode'] as int;
    final body = result['body'];
    final msg = body is Map ? (body['message'] as String? ?? '') : '';

    return (success: status == 200, message: msg);
  }
}
