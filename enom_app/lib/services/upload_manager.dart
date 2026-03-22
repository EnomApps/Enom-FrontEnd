import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'package:video_compress/video_compress.dart';
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
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);
    _initialized = true;
  }

  bool get isUploading => _isUploading;

  /// Start a background upload. Returns immediately.
  /// [mediaTypes] should match [mediaBytes] — each entry is 'image' or 'video'.
  /// [mediaFilePaths] are original file paths (needed for video compression).
  void startUpload({
    String? content,
    String visibility = 'public',
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
      mediaBytes: mediaBytes,
      mediaNames: mediaNames,
      mediaTypes: mediaTypes,
      mediaFilePaths: mediaFilePaths,
    );
  }

  Future<void> _doUpload({
    String? content,
    String visibility = 'public',
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

      if (mediaBytes != null && mediaNames != null) {
        for (int i = 0; i < mediaBytes.length; i++) {
          final type = (mediaTypes != null && i < mediaTypes.length)
              ? mediaTypes[i]
              : 'image';
          final filePath = (mediaFilePaths != null && i < mediaFilePaths.length)
              ? mediaFilePaths[i]
              : null;

          if (type == 'video' && filePath != null) {
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
      };

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
        await _showCompletedNotification('Post uploaded successfully!');
        _uploadCompleteController.add(true);
      } else {
        final msg = decoded is Map
            ? (decoded['message'] as String? ?? 'Upload failed')
            : 'Upload failed';
        await _showFailedNotification(msg);
      }
    } catch (e) {
      await _showFailedNotification('Upload failed: ${e.toString().length > 50 ? '${e.toString().substring(0, 50)}...' : e}');
    } finally {
      _isUploading = false;
    }
  }

  Future<void> _showProgressNotification(int percent, String body) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Shows upload progress for posts',
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

  Future<void> _showCompletedNotification(String body) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Shows upload progress for posts',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      ongoing: false,
      autoCancel: true,
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

  Future<void> _showFailedNotification(String body) async {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Shows upload progress for posts',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
      autoCancel: true,
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

  void dispose() {
    _uploadCompleteController.close();
  }
}
