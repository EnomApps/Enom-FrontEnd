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
///
/// Handles post uploads in the background with a progress notification.
/// Multiple videos can upload at the same time — the user never has to wait
/// for one upload to finish before posting another. Each upload runs
/// independently and shows its own progress notification.
///
/// The only step that is serialized is the native video compression: the
/// [VideoCompress] plugin is a process-global singleton, so two compressions
/// must not run at the same moment or they corrupt each other's state. The
/// (much longer) HTTP upload phase runs fully concurrently.
class UploadManager {
  UploadManager._();
  static final UploadManager instance = UploadManager._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// How many uploads are currently in flight.
  int _activeCount = 0;

  /// Generates a unique id per upload so each gets its own notification slot.
  int _nextUploadId = 0;

  /// Caps how many uploads hit the network at the same moment. Firing many
  /// posts at once previously let them all contend for bandwidth and memory and
  /// stall (one frozen at 100%, another at 28%). Extra uploads now queue here
  /// and start as slots free up — nothing is dropped.
  static const int _maxConcurrentUploads = 2;
  int _networkActive = 0;
  final List<Completer<void>> _networkWaiters = [];

  /// Per-attempt network timeout. A stalled request aborts and retries instead
  /// of freezing the progress bar forever. Generous enough for large videos on
  /// mobile data, short enough that a dead socket doesn't hang indefinitely.
  static const Duration _attemptTimeout = Duration(minutes: 4);

  /// How many times a failed/stalled upload is retried before giving up. With
  /// backoff this is what makes "every post eventually lands" hold.
  static const int _maxUploadAttempts = 3;

  /// Holds uploaded posts keyed by post id so a notification tap can push the
  /// user straight into the Reels view of the right post, even when several
  /// uploads have completed.
  static final Map<String, Map<String, dynamic>> _uploadedPosts = {};

  /// Serializes the native video-compression step. Each compression chains
  /// onto the previous one so only a single video is compressed at a time.
  Future<void> _compressionLock = Future<void>.value();

  /// Stream that emits when an upload completes successfully.
  final StreamController<bool> _uploadCompleteController =
      StreamController<bool>.broadcast();
  Stream<bool> get onUploadComplete => _uploadCompleteController.stream;

  /// Base id for upload notifications. Each upload uses [_notificationBaseId]
  /// plus its own offset so progress bars stack instead of overwriting.
  static const int _notificationBaseId = 9001;
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
    final postId = payload.substring('post:'.length);
    final post = _uploadedPosts[postId];
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

  /// True while at least one upload is still in progress.
  bool get isUploading => _activeCount > 0;

  /// Start a background upload. Returns immediately. Can be called again while
  /// other uploads are still running — each upload is independent.
  ///
  /// [mediaTypes] should match [mediaBytes] — each entry is 'image' or 'video'.
  /// [mediaFilePaths] are original file paths (needed for video compression).
  void startUpload({
    String? content,
    String visibility = 'public',
    List<String>? hashtags,
    String? locationName,
    double? latitude,
    double? longitude,
    List<Uint8List>? mediaBytes,
    List<String>? mediaNames,
    List<String>? mediaTypes,
    List<String?>? mediaFilePaths,
  }) {
    final uploadId = _nextUploadId++;
    final notificationId = _notificationBaseId + (uploadId % 1000);
    _activeCount++;

    // Fire and forget — runs in background, concurrently with other uploads.
    _doUpload(
      notificationId: notificationId,
      content: content,
      visibility: visibility,
      hashtags: hashtags,
      locationName: locationName,
      latitude: latitude,
      longitude: longitude,
      mediaBytes: mediaBytes,
      mediaNames: mediaNames,
      mediaTypes: mediaTypes,
      mediaFilePaths: mediaFilePaths,
    );
  }

  Future<void> _doUpload({
    required int notificationId,
    String? content,
    String visibility = 'public',
    List<String>? hashtags,
    String? locationName,
    double? latitude,
    double? longitude,
    List<Uint8List>? mediaBytes,
    List<String>? mediaNames,
    List<String>? mediaTypes,
    List<String?>? mediaFilePaths,
  }) async {
    try {
      // Show initial notification
      await _showProgressNotification(notificationId, 0, 'Uploading post...');

      final token = await ApiService.getToken();

      // Compress videos in background before uploading.
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
            // Compression touches the global VideoCompress plugin, so it must
            // run exclusively — one video at a time across all uploads.
            final result = await _compressVideoExclusive(
              notificationId: notificationId,
              filePath: filePath,
              originalBytes: mediaBytes[i],
              originalName: mediaNames[i],
              index: i,
            );
            processedBytes.add(result.videoBytes);
            processedNames.add(result.videoName);
            if (result.thumbBytes != null && result.thumbName != null) {
              thumbnailBytes.add(result.thumbBytes!);
              thumbnailNames.add(result.thumbName!);
            }
          } else {
            // Images — already compressed by image_picker
            processedBytes.add(mediaBytes[i]);
            processedNames.add(mediaNames[i]);
          }
        }
      }

      final hasVideos = mediaTypes?.contains('video') ?? false;
      // If videos were compressed, the compression phase already covered 0-50%.
      final uploadBase = hasVideos ? 50 : 0;
      await _showProgressNotification(
          notificationId, uploadBase, 'Uploading post... $uploadBase%');

      final fields = <String, String>{
        if (content != null && content.isNotEmpty) 'content': content,
        'visibility': visibility,
        if (locationName != null && locationName.isNotEmpty)
          'location_name': locationName,
        if (locationName != null && locationName.isNotEmpty && latitude != null)
          'latitude': latitude.toString(),
        if (locationName != null && locationName.isNotEmpty && longitude != null)
          'longitude': longitude.toString(),
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

      // Finalize the multipart request to get body bytes
      final bodyBytes = await request.finalize().toBytes();

      // Send through the queued, timed-out, auto-retrying network layer. This
      // is what stops a stalled request from freezing at 100% and makes
      // posting several at once reliable. Returns null only after every
      // attempt failed.
      final response = await _sendWithRetry(
        url: request.url,
        headers: request.headers,
        bodyBytes: bodyBytes,
        notificationId: notificationId,
        uploadBase: uploadBase,
      );

      if (response == null) {
        debugPrint('[UPLOAD] #$notificationId all attempts failed');
        await _showFailedNotification(notificationId);
        return;
      }

      dynamic decoded;
      try {
        decoded = json.decode(response.body);
      } catch (_) {
        decoded = {'message': 'Server error'};
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
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
        final postId = post?['id'];
        if (post != null && postId != null) {
          _uploadedPosts[postId.toString()] = post;
        }
        debugPrint('[UPLOAD] #$notificationId complete → post $postId');
        await _showCompletedNotification(notificationId, postId);
        _uploadCompleteController.add(true);
      } else {
        debugPrint('[UPLOAD] #$notificationId failed status ${response.statusCode}');
        await _showFailedNotification(notificationId);
      }
    } catch (_) {
      await _showFailedNotification(notificationId);
    } finally {
      _activeCount--;
    }
  }

  /// Result of compressing a single video under the global compression lock.
  Future<_ProcessedVideo> _compressVideoExclusive({
    required int notificationId,
    required String filePath,
    required Uint8List originalBytes,
    required String originalName,
    required int index,
  }) {
    final completer = Completer<_ProcessedVideo>();
    final previous = _compressionLock;

    // Chain this compression after any compression already running.
    _compressionLock = previous.then((_) async {
      Uint8List? thumbBytes;
      String? thumbName;

      // Grab a frame at ~1s for the thumbnail. Done before compression so we
      // sample the original quality. Best-effort — backend can derive one.
      try {
        final thumbFile = await VideoCompress.getFileThumbnail(
          filePath,
          quality: 75,
          position: 1000,
        );
        thumbBytes = await thumbFile.readAsBytes();
        thumbName =
            'thumb_${index}_${notificationId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      } catch (_) {
        // Thumbnail is best-effort.
      }

      // Map compression progress to 0-50% on this upload's notification.
      final subscription = VideoCompress.compressProgress$.subscribe(
        (progress) async {
          final percent = (progress * 0.5).round(); // 0-50% for compression
          await _showProgressNotification(
              notificationId, percent, 'Uploading post... $percent%');
        },
      );

      Uint8List videoBytes;
      String videoName = originalName;
      try {
        final info = await VideoCompress.compressVideo(
          filePath,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );
        if (info != null && info.file != null) {
          videoBytes = await info.file!.readAsBytes();
        } else {
          videoBytes = originalBytes; // compression failed, use original
        }
      } catch (_) {
        videoBytes = originalBytes; // fallback to original on error
      } finally {
        subscription.unsubscribe();
      }

      completer.complete(_ProcessedVideo(
        videoBytes: videoBytes,
        videoName: videoName,
        thumbBytes: thumbBytes,
        thumbName: thumbName,
      ));
    });

    // Make sure a failure in one compression never stalls the lock chain for
    // the next upload.
    _compressionLock = _compressionLock.catchError((_) {});

    return completer.future;
  }

  /// Wait for a free network slot. Hands the slot directly to the next waiter
  /// on release so the in-flight count never exceeds [_maxConcurrentUploads].
  Future<void> _acquireNetworkSlot() async {
    if (_networkActive < _maxConcurrentUploads) {
      _networkActive++;
      return;
    }
    final waiter = Completer<void>();
    _networkWaiters.add(waiter);
    await waiter.future; // resumes already holding the slot (count unchanged)
  }

  void _releaseNetworkSlot() {
    if (_networkWaiters.isNotEmpty) {
      _networkWaiters.removeAt(0).complete(); // pass the slot straight on
    } else {
      _networkActive--;
    }
  }

  /// Send the post body with a per-attempt timeout and automatic retries,
  /// gated through the concurrency limit. Returns the final HTTP response, or
  /// null if every attempt failed (network errors / timeouts).
  Future<http.Response?> _sendWithRetry({
    required Uri url,
    required Map<String, String> headers,
    required Uint8List bodyBytes,
    required int notificationId,
    required int uploadBase,
  }) async {
    await _acquireNetworkSlot();
    try {
      for (int attempt = 1; attempt <= _maxUploadAttempts; attempt++) {
        try {
          final response = await _sendOnce(
            url: url,
            headers: headers,
            bodyBytes: bodyBytes,
            notificationId: notificationId,
            uploadBase: uploadBase,
          );
          // Success, or a client error that retrying can't fix (bad request,
          // auth, validation) — return either way. Only 5xx / 408 / 429 retry.
          final code = response.statusCode;
          final worthRetry =
              code >= 500 || code == 408 || code == 429;
          if (!worthRetry) return response;
          debugPrint('[UPLOAD] #$notificationId attempt $attempt got $code — retrying');
        } catch (e) {
          // Timeout or socket error — fall through to retry.
          debugPrint('[UPLOAD] #$notificationId attempt $attempt error: $e — retrying');
        }

        if (attempt < _maxUploadAttempts) {
          await _showProgressNotification(
            notificationId,
            uploadBase,
            'Upload stalled — retrying ($attempt)...',
          );
          // Linear backoff: 2s, 4s. Lets a flaky connection settle.
          await Future<void>.delayed(Duration(seconds: 2 * attempt));
        }
      }
      return null;
    } finally {
      _releaseNetworkSlot();
    }
  }

  /// One upload attempt. Streams [bodyBytes] in chunks for progress, with a
  /// hard timeout on both the send and the response. Always closes the sink and
  /// the client so a failed attempt can never leak resources or hang.
  Future<http.Response> _sendOnce({
    required Uri url,
    required Map<String, String> headers,
    required Uint8List bodyBytes,
    required int notificationId,
    required int uploadBase,
  }) async {
    final client = http.Client();
    try {
      final rawRequest = http.StreamedRequest('POST', url);
      rawRequest.headers.addAll(headers);
      rawRequest.contentLength = bodyBytes.length;

      const chunkSize = 64 * 1024; // 64KB chunks
      final uploadRange = 100 - uploadBase; // remaining % for the upload phase

      // Feed the body to the request sink. A failed notification must never
      // break the stream, and the sink is guaranteed to close — otherwise the
      // request (with a fixed contentLength) would wait forever for bytes.
      final feed = () async {
        int lastPercent = -1;
        try {
          for (int offset = 0; offset < bodyBytes.length; offset += chunkSize) {
            final end = (offset + chunkSize > bodyBytes.length)
                ? bodyBytes.length
                : offset + chunkSize;
            rawRequest.sink.add(bodyBytes.sublist(offset, end));

            final percent =
                uploadBase + (end * uploadRange / bodyBytes.length).round();
            if (percent != lastPercent && percent % 5 == 0) {
              lastPercent = percent;
              try {
                await _showProgressNotification(
                    notificationId, percent, 'Uploading post... $percent%');
              } catch (_) {
                // Best-effort progress — never let it abort the upload.
              }
            }
          }
          // All bytes are on the wire; the server is now processing (saving
          // media, generating thumbnails). Change the text so a 100% bar
          // doesn't look frozen while we wait for the 201.
          try {
            await _showProgressNotification(
                notificationId, 100, 'Finishing up...');
          } catch (_) {}
        } finally {
          await rawRequest.sink.close();
        }
      }()
          .catchError((_) {/* swallow — client.close() tears down the rest */});

      debugPrint('[UPLOAD] #$notificationId sending ${bodyBytes.length} bytes');
      final streamed =
          await client.send(rawRequest).timeout(_attemptTimeout);
      final response =
          await http.Response.fromStream(streamed).timeout(_attemptTimeout);
      await feed; // feeder has finished by now; surfaces nothing on success
      debugPrint('[UPLOAD] #$notificationId response ${response.statusCode}');
      return response;
    } finally {
      client.close();
    }
  }

  Future<void> _showProgressNotification(
      int notificationId, int percent, String body) async {
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
      threadIdentifier: 'upload_$notificationId',
    );

    await _notifications.show(
      notificationId,
      'Enom',
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  Future<void> _showCompletedNotification(
      int notificationId, dynamic postId) async {
    // Android (notably Samsung One UI) often refuses to turn an `ongoing`
    // progress notification into a normal one by re-showing the same id — it
    // sticks at the last frame (e.g. 100%). Cancelling first guarantees the
    // completion notification actually replaces it.
    await _notifications.cancel(notificationId);
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
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: postId != null ? 'post:$postId' : null,
    );
  }

  Future<void> _showFailedNotification(int notificationId) async {
    // Same reason as completion: cancel the ongoing progress notification so
    // the failure notice actually shows instead of leaving a frozen bar.
    await _notifications.cancel(notificationId);
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
      notificationId,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  void dispose() {
    _uploadCompleteController.close();
  }
}

/// A single processed (compressed) video plus its optional thumbnail.
class _ProcessedVideo {
  _ProcessedVideo({
    required this.videoBytes,
    required this.videoName,
    this.thumbBytes,
    this.thumbName,
  });

  final Uint8List videoBytes;
  final String videoName;
  final Uint8List? thumbBytes;
  final String? thumbName;
}
