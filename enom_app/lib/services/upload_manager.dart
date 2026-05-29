import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:video_compress/video_compress.dart';
import '../main.dart' show rootNavigatorKey;
import '../screens/feed_reels_screen.dart';
import 'api_service.dart';

/// Instagram-style background upload manager.
/// Handles post upload in background with progress notification.
class UploadManager {
  UploadManager._();
  static final UploadManager instance = UploadManager._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _isUploading = false;

  /// Holds the most recently uploaded post so a notification tap can push
  /// the user straight into the Reels view of it without a refetch.
  static Map<String, dynamic>? _lastUploadedPost;

  /// Stream that emits when an upload completes successfully.
  final StreamController<bool> _uploadCompleteController =
      StreamController<bool>.broadcast();
  Stream<bool> get onUploadComplete => _uploadCompleteController.stream;

  static const int _notificationId = 9001;
  static const String _channelId = 'enom_upload';
  static const String _channelName = 'Post Upload';

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // If the app was launched from a tap on the completion notification while
    // killed, navigate after the first frame so the navigator is mounted.
    final launchDetails =
        await _notifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final payload = launchDetails!.notificationResponse?.payload;
      if (payload != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handlePayload(payload);
        });
      }
    }
    _initialized = true;
  }

  static void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) _handlePayload(payload);
  }

  static void _handlePayload(String payload) {
    if (!payload.startsWith('post:')) return;
    final post = _lastUploadedPost;
    if (post == null) return;
    final nav = rootNavigatorKey.currentState;
    if (nav == null) return;
    nav.push(MaterialPageRoute(
      builder: (_) => FeedReelsScreen(
        videoPosts: [post],
        initialIndex: 0,
      ),
    ));
  }

  bool get isUploading => _isUploading;

  /// Start a background upload. Returns immediately.
  /// [mediaTypes] should match [mediaBytes] — each entry is 'image' or 'video'.
  /// [mediaFilePaths] are original file paths (needed for video compression).
  void startUpload({
    String? content,
    String visibility = 'public',
    List<String>? hashtags,
    String? locationName,
    List<Uint8List>? mediaBytes,
    List<String>? mediaNames,
    List<String>? mediaTypes,
    List<String?>? mediaFilePaths,
  }) {
    if (_isUploading) return;
    _isUploading = true;

    // Fire and forget — runs in background
    _doUpload(
      content: content,
      visibility: visibility,
      hashtags: hashtags,
      locationName: locationName,
      mediaBytes: mediaBytes,
      mediaNames: mediaNames,
      mediaTypes: mediaTypes,
      mediaFilePaths: mediaFilePaths,
    );
  }

  Future<void> _doUpload({
    String? content,
    String visibility = 'public',
    List<String>? hashtags,
    String? locationName,
    List<Uint8List>? mediaBytes,
    List<String>? mediaNames,
    List<String>? mediaTypes,
    List<String?>? mediaFilePaths,
  }) async {
    try {
      // Show initial notification
      await _showProgressNotification(0, 'Uploading post...');

      final token = await ApiService.getToken();

      // Compress videos in background before uploading
      final processedBytes = <Uint8List>[];
      final processedNames = <String>[];
      // Thumbnails for each video, in the same relative order as the videos
      // appear in media[]. Backend maps thumbnails[i] → i-th video.
      final thumbnailBytes = <Uint8List>[];
      final thumbnailNames = <String>[];

      if (mediaBytes != null && mediaNames != null) {
        for (int i = 0; i < mediaBytes.length; i++) {
          final type = (mediaTypes != null && i < mediaTypes.length)
              ? mediaTypes[i]
              : 'image';
          final filePath = (mediaFilePaths != null && i < mediaFilePaths.length)
              ? mediaFilePaths[i]
              : null;

          if (type == 'video' && filePath != null) {
            // Grab a frame at ~1s to use as the video thumbnail. Done before
            // compression so we sample the original quality.
            try {
              final thumbFile = await VideoCompress.getFileThumbnail(
                filePath,
                quality: 75,
                position: 1000,
              );
              final tBytes = await thumbFile.readAsBytes();
              thumbnailBytes.add(tBytes);
              thumbnailNames.add(
                'thumb_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg',
              );
            } catch (_) {
              // Thumbnail is best-effort; backend can derive one later.
            }

            // Compress video in background
            await _showProgressNotification(
              0, 'Uploading post...',
            );

            final subscription = VideoCompress.compressProgress$.subscribe(
              (progress) async {
                final percent = (progress * 0.5).round(); // 0-50% for compression
                await _showProgressNotification(
                  percent, 'Uploading post... $percent%',
                );
              },
            );

            try {
              final info = await VideoCompress.compressVideo(
                filePath,
                quality: VideoQuality.MediumQuality,
                deleteOrigin: false,
                includeAudio: true,
              );

              if (info != null && info.file != null) {
                final compressedBytes = await info.file!.readAsBytes();
                processedBytes.add(compressedBytes);
                processedNames.add(mediaNames[i]);
              } else {
                // Compression failed, use original
                processedBytes.add(mediaBytes[i]);
                processedNames.add(mediaNames[i]);
              }
            } catch (_) {
              // Fallback to original on error
              processedBytes.add(mediaBytes[i]);
              processedNames.add(mediaNames[i]);
            } finally {
              subscription.unsubscribe();
            }
          } else {
            // Images — already compressed by image_picker
            processedBytes.add(mediaBytes[i]);
            processedNames.add(mediaNames[i]);
          }
        }
      }

      await _showProgressNotification(50, 'Uploading post... 50%');

      final hasVideos = mediaTypes?.contains('video') ?? false;
      final uploadBase = hasVideos ? 50 : 0; // If videos were compressed, start at 50%

      final fields = <String, String>{
        if (content != null && content.isNotEmpty) 'content': content,
        'visibility': visibility,
        if (locationName != null && locationName.isNotEmpty) 'location_name': locationName,
      };

      // Add hashtags as individual fields: hashtags[0], hashtags[1], etc.
      if (hashtags != null && hashtags.isNotEmpty) {
        for (int i = 0; i < hashtags.length; i++) {
          fields['hashtags[$i]'] = hashtags[i];
        }
      }

      // Build multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/api/posts'),
      );

      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });

      request.fields.addAll(fields);

      // Attach processed media files
      for (int i = 0; i < processedBytes.length; i++) {
        final name = processedNames[i];
        final ext = name.split('.').last.toLowerCase();
        final mimeType = switch (ext) {
          'png' => MediaType('image', 'png'),
          'gif' => MediaType('image', 'gif'),
          'webp' => MediaType('image', 'webp'),
          'mp4' => MediaType('video', 'mp4'),
          'mov' => MediaType('video', 'quicktime'),
          'avi' => MediaType('video', 'x-msvideo'),
          _ => MediaType('image', 'jpeg'),
        };
        request.files.add(http.MultipartFile.fromBytes(
          'media[]',
          processedBytes[i],
          filename: name,
          contentType: mimeType,
        ));
      }

      // Attach video thumbnails — one entry per video, in the same relative
      // order as videos in media[]. Backend pairs thumbnails[i] → i-th video.
      for (int i = 0; i < thumbnailBytes.length; i++) {
        request.files.add(http.MultipartFile.fromBytes(
          'thumbnails[]',
          thumbnailBytes[i],
          filename: thumbnailNames[i],
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      await _showProgressNotification(uploadBase, 'Uploading post...');

      // Finalize the multipart request to get body bytes
      final bodyStream = request.finalize();
      final bodyBytes = await bodyStream.toBytes();
      final totalUploadBytes = bodyBytes.length;

      // Create a StreamedRequest so we can send in chunks and track progress
      final rawRequest = http.StreamedRequest('POST', request.url);
      rawRequest.headers.addAll(request.headers);
      rawRequest.contentLength = totalUploadBytes;

      // Send body in chunks to track progress
      const chunkSize = 16 * 1024; // 16KB chunks
      int lastPercent = 0;
      final uploadRange = 100 - uploadBase; // remaining % for upload phase

      // Start sending chunks in background
      () async {
        for (int offset = 0; offset < totalUploadBytes; offset += chunkSize) {
          final end = (offset + chunkSize > totalUploadBytes)
              ? totalUploadBytes
              : offset + chunkSize;
          rawRequest.sink.add(bodyBytes.sublist(offset, end));

          final percent = uploadBase + (end * uploadRange / totalUploadBytes).round();
          if (percent != lastPercent && percent % 5 == 0) {
            lastPercent = percent;
            await _showProgressNotification(percent, 'Uploading post... $percent%');
          }
        }
        rawRequest.sink.close();
      }();

      final streamedResponse = await http.Client().send(rawRequest);
      final response = await http.Response.fromStream(streamedResponse);

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = {'message': 'Server error'};
      }

      if (response.statusCode == 201) {
        // Cache the post Map so a notification tap can open Reels on it.
        Map<String, dynamic>? post;
        if (decoded is Map<String, dynamic>) {
          final p = decoded['post'];
          if (p is Map<String, dynamic>) {
            post = p;
          } else if (decoded['id'] != null) {
            post = decoded;
          }
        }
        _lastUploadedPost = post;
        final postId = post?['id'];
        await _showCompletedNotification(postId);
        _uploadCompleteController.add(true);
      } else {
        await _showFailedNotification();
      }
    } catch (_) {
      await _showFailedNotification();
    } finally {
      _isUploading = false;
    }
  }

  Future<void> _showProgressNotification(int percent, String body) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Shows upload progress for posts',
      channelShowBadge: false,
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: percent,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      icon: '@mipmap/ic_launcher',
    );

    final iosDetails = DarwinNotificationDetails(
      subtitle: body,
    );

    await _notifications.show(
      _notificationId,
      'Enom',
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> _showCompletedNotification(dynamic postId) async {
    const title = 'Upload Complete';
    const body = 'See your post';
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Shows upload progress for posts',
      channelShowBadge: false,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: false,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      subtitle: body,
    );

    await _notifications.show(
      _notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: postId != null ? 'post:$postId' : null,
    );
  }

  Future<void> _showFailedNotification() async {
    const title = 'Upload Failed';
    const body = 'Please try again';
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Shows upload progress for posts',
      channelShowBadge: false,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      subtitle: body,
    );

    await _notifications.show(
      _notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  void dispose() {
    _uploadCompleteController.close();
  }
}
