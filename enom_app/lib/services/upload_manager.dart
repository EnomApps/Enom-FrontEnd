import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  /// The actual network upload now runs in the native background_downloader
  /// engine (Android WorkManager + foreground service / iOS URLSession), NOT in
  /// this Dart isolate. That is what lets an upload keep going — and its
  /// progress notification keep moving — after the user swipes the app away.
  /// Concurrency, retries and timeouts are handled natively by that engine.
  static const String _uploadGroup = 'enom_post_upload';

  /// How many times the native engine retries a failed/stalled upload before
  /// surfacing the error notification.
  static const int _uploadRetries = 3;

  /// Maps an enqueued upload task id → the bookkeeping needed to finalize it
  /// when its status update arrives (cache the post, refresh the feed, clear
  /// the compression notification). Survives only while the app is alive; the
  /// native engine drives the upload + notification regardless.
  final Map<String, int> _taskNotificationIds = {};

  /// Videos at or below this size upload as-is, skipping compression. A clip
  /// this small is already modestly encoded (e.g. a 22-min, 55MB video is
  /// ~0.33 Mbps) — re-encoding it costs 10-30 min on-device for little to no
  /// size win and is exactly what made the progress bar appear frozen. Only
  /// genuinely large, high-bitrate files are worth the compression time.
  static const int _skipCompressionBytes = 100 * 1024 * 1024; // 100 MB

  /// Hard cap on a single video compression. If the native encoder stalls past
  /// this, we cancel it and upload the original instead of hanging the progress
  /// bar forever.
  static const Duration _compressTimeout = Duration(minutes: 8);

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

  /// Latest progress for each in-flight upload, keyed by notificationId. A
  /// heartbeat timer re-posts these so a progress notification the user swipes
  /// away reappears within a second or two, and never looks frozen while the
  /// server is processing (Android 14+ lets users dismiss even `ongoing`
  /// notifications, so re-posting is the only reliable way to keep it visible
  /// without a foreground service).
  final Map<int, ({int percent, String body, bool indeterminate})>
      _liveProgress = {};
  Timer? _progressHeartbeat;
  static const Duration _heartbeatInterval = Duration(milliseconds: 1500);

  /// Bridge to the native Android foreground service that owns the upload
  /// progress notification. On Android the progress bar is rendered by that
  /// service (sticky, un-swipeable, survives the app being closed); on iOS we
  /// fall back to the per-upload local notification + heartbeat below.
  static const MethodChannel _fgsChannel = MethodChannel('enom/upload_fgs');
  bool get _useForegroundService =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether the foreground service is currently running. The first tick of a
  /// batch must `start` it (foreground-only on Android 12+); later ticks
  /// `update` the notification (background-safe).
  bool _fgsRunning = false;

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

    // The actual post upload runs in the native background_downloader engine so
    // it survives the app being swiped away. These notifications are rendered
    // and kept moving by the OS even when our Dart code isn't running — that is
    // what fixes "the bar freezes when I close the app mid-upload". The progress
    // text uses the {progress} placeholder, which the native side substitutes.
    FileDownloader().configureNotification(
      running: const TaskNotification('Uploading post', 'Uploading… {progress}'),
      complete: const TaskNotification('Upload complete', 'Your post is live'),
      error: const TaskNotification('Upload failed', 'Please try again'),
      progressBar: true,
    );
    // Persist tasks so they (and their updates) reconnect after a restart, and
    // listen for completion/failure to refresh the feed while the app is alive.
    await FileDownloader().trackTasks();
    FileDownloader().updates.listen(_onTaskUpdate);

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
      final token = await ApiService.getToken();

      // Resolve every media item to a FILE ON DISK and build the multipart file
      // list for the upload task. The native uploader streams straight from
      // these paths — nothing is held in memory (no more OOM risk), and the
      // upload keeps running even after the app is swiped away.
      final files = <(String, String, String)>[]; // (field, absPath, mime)
      final count = mediaFilePaths?.length ?? 0;
      for (int i = 0; i < count; i++) {
        final type = (mediaTypes != null && i < mediaTypes.length)
            ? mediaTypes[i]
            : 'image';
        final path = mediaFilePaths![i];
        if (path == null) continue;

        if (type == 'video') {
          // Compress only large videos (serialized — VideoCompress is a
          // process-global singleton), then upload the resulting file plus a
          // thumbnail the backend pairs by order.
          final v = await _compressVideoExclusive(
            notificationId: notificationId,
            filePath: path,
          );
          files.add(('media[]', v.videoPath, _mimeForPath(v.videoPath)));
          if (v.thumbPath != null) {
            files.add(('thumbnails[]', v.thumbPath!, 'image/jpeg'));
          }
        } else {
          // Images are already compressed by image_picker.
          files.add(('media[]', path, _mimeForPath(path)));
        }
      }

      // Compression (if any) is finished — clear its notification so the native
      // upload notification takes over cleanly.
      _liveProgress.remove(notificationId);
      await _syncForegroundService();

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
      // Hashtags as individual fields: hashtags[0], hashtags[1], etc.
      if (hashtags != null && hashtags.isNotEmpty) {
        for (int i = 0; i < hashtags.length; i++) {
          fields['hashtags[$i]'] = hashtags[i];
        }
      }

      // Text-only post: there's no file to transfer, so the background engine
      // (which requires at least one file) doesn't apply. A tiny direct POST
      // finishes instantly — nothing to keep alive across an app-kill.
      if (files.isEmpty) {
        await _uploadTextOnly(
          notificationId: notificationId, token: token, fields: fields);
        return;
      }

      // Hand the upload to the native background engine. It owns the network
      // transfer, the progress notification, retries and concurrency — and all
      // of it survives the app being closed.
      final task = MultiUploadTask(
        url: '${ApiService.baseUrl}/api/posts',
        files: files,
        fields: fields,
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        httpRequestMethod: 'POST',
        group: _uploadGroup,
        updates: Updates.statusAndProgress,
        retries: _uploadRetries,
        requiresWiFi: false,
        displayName: 'post',
      );

      _taskNotificationIds[task.taskId] = notificationId;
      final enqueued = await FileDownloader().enqueue(task);
      if (!enqueued) {
        _taskNotificationIds.remove(task.taskId);
        debugPrint('[UPLOAD] #$notificationId enqueue failed');
        await _showFailedNotification(notificationId);
        _activeCount--;
        return;
      }
      debugPrint('[UPLOAD] #$notificationId enqueued as ${task.taskId}');
      // Completion / failure is finalized in [_onTaskUpdate]; the native engine
      // drives everything from here.
    } catch (_) {
      _liveProgress.remove(notificationId);
      await _syncForegroundService();
      await _showFailedNotification(notificationId);
      _activeCount--;
    }
  }

  /// Post a text-only update (no media) with a small direct multipart POST.
  /// Quick and self-contained — handles its own completion/failure notification
  /// and decrements the active count.
  Future<void> _uploadTextOnly({
    required int notificationId,
    required String? token,
    required Map<String, String> fields,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiService.baseUrl}/api/posts'),
      );
      request.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
      request.fields.addAll(fields);

      final streamed = await request.send().timeout(const Duration(minutes: 1));
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final decoded = json.decode(response.body);
          if (decoded is Map<String, dynamic>) {
            final p = decoded['post'];
            final post = (p is Map<String, dynamic>)
                ? p
                : (decoded['id'] != null ? decoded : null);
            final postId = post?['id'];
            if (post != null && postId != null) {
              _uploadedPosts[postId.toString()] = post;
            }
          }
        } catch (_) {}
        await _showTextPostComplete(notificationId);
        _uploadCompleteController.add(true);
      } else {
        await _showFailedNotification(notificationId);
      }
    } catch (_) {
      await _showFailedNotification(notificationId);
    } finally {
      if (_activeCount > 0) _activeCount--;
    }
  }

  /// Simple completion notice for a text-only post (the media path uses the
  /// native background_downloader completion notification instead).
  Future<void> _showTextPostComplete(int notificationId) async {
    _liveProgress.remove(notificationId);
    await _syncForegroundService();
    await _notifications.cancel(notificationId);
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
    const iosDetails = DarwinNotificationDetails(subtitle: 'Your post is live');
    await _notifications.show(
      notificationId,
      'Upload complete',
      'Your post is live',
      NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  /// Maps a file path's extension to a MIME type for the multipart part.
  String _mimeForPath(String path) {
    switch (path.split('.').last.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  /// Finalize an upload when its native status update arrives. The progress
  /// notification is rendered natively (survives app-kill); here we only do the
  /// Dart-side bookkeeping when the app happens to be alive: cache the new post
  /// so the feed can show it immediately, and refresh listeners.
  void _onTaskUpdate(TaskUpdate update) {
    if (update.task.group != _uploadGroup) return;
    if (update is! TaskStatusUpdate) return; // progress handled by native notif
    final status = update.status;
    if (!status.isFinalState) return;

    final taskId = update.task.taskId;
    _taskNotificationIds.remove(taskId);
    if (_activeCount > 0) _activeCount--;

    if (status == TaskStatus.complete) {
      try {
        final decoded = json.decode(update.responseBody ?? '');
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
      } catch (_) {
        // Response wasn't JSON we recognise — the post still landed (2xx);
        // the feed will pick it up on its next normal refresh.
      }
      debugPrint('[UPLOAD] task $taskId complete');
      _uploadCompleteController.add(true);
    } else {
      // failed / canceled / notFound — the native error notification already
      // informed the user. Log the full reason so we can see WHY it failed
      // (HTTP status from the server vs a file-system/connection problem).
      final code = update.responseStatusCode;
      final ex = update.exception;
      final body = update.responseBody;
      debugPrint('[UPLOAD] task $taskId FAILED status=$status '
          'httpCode=$code exception=$ex');
      if (body != null && body.isNotEmpty) {
        debugPrint('[UPLOAD] task $taskId server body: '
            '${body.length > 500 ? body.substring(0, 500) : body}');
      }
    }
  }

  /// Compress a single video under the global compression lock and extract a
  /// thumbnail, returning the file PATHS to upload (no bytes held in memory).
  Future<_ProcessedVideo> _compressVideoExclusive({
    required int notificationId,
    required String filePath,
  }) {
    final completer = Completer<_ProcessedVideo>();
    final previous = _compressionLock;

    // Chain this compression after any compression already running.
    _compressionLock = previous.then((_) async {
      String? thumbPath;

      // Grab a frame at ~1s for the thumbnail. Done before compression so we
      // sample the original quality. Best-effort — backend can derive one.
      try {
        final thumbFile = await VideoCompress.getFileThumbnail(
          filePath,
          quality: 75,
          position: 1000,
        );
        thumbPath = thumbFile.path;
      } catch (_) {
        // Thumbnail is best-effort.
      }

      // Default to uploading the original file untouched.
      String videoPath = filePath;

      int sizeBytes = 0;
      try {
        sizeBytes = await File(filePath).length();
      } catch (_) {
        // If we can't size it, treat as small and skip compression.
      }

      // Only compress genuinely large files. Anything already small uploads
      // as-is — re-encoding it is slow, barely shrinks it, and is what froze
      // the bar for long clips that were already modestly encoded.
      if (sizeBytes > _skipCompressionBytes) {
        // Show an animated indeterminate bar for the whole compression phase.
        // video_compress's progress stream is unreliable for long videos, so a
        // fixed percentage looks frozen; the bar text still reflects progress
        // when the stream does emit. Fire-and-forget (never await the platform
        // channel inside the callback) and skip duplicate percents.
        int lastCompressPercent = -1;
        final subscription = VideoCompress.compressProgress$.subscribe(
          (progress) {
            final percent = progress.round().clamp(0, 100);
            if (percent == lastCompressPercent) return;
            lastCompressPercent = percent;
            unawaited(_showProgressNotification(
                notificationId, 0, 'Compressing video… $percent%',
                indeterminate: true));
          },
        );
        unawaited(_showProgressNotification(
            notificationId, 0, 'Compressing video…',
            indeterminate: true));

        try {
          // Cap the encode: if it stalls past the timeout, cancel it and fall
          // back to the original so the upload never hangs forever.
          final info = await VideoCompress.compressVideo(
            filePath,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
            includeAudio: true,
          ).timeout(_compressTimeout, onTimeout: () {
            unawaited(VideoCompress.cancelCompression());
            return null;
          });
          final outPath = info?.file?.path;
          if (outPath != null) {
            int outSize = 0;
            try {
              outSize = await File(outPath).length();
            } catch (_) {}
            // Guard against the encoder producing a larger file (can happen for
            // already-efficient sources) — keep whichever is smaller.
            if (outSize > 0 && outSize < sizeBytes) {
              videoPath = outPath;
            }
          }
        } catch (_) {
          // Fall back to the original on any error.
        } finally {
          subscription.unsubscribe();
        }
      }

      completer.complete(_ProcessedVideo(
        videoPath: videoPath,
        thumbPath: thumbPath,
      ));
    });

    // Make sure a failure in one compression never stalls the lock chain for
    // the next upload.
    _compressionLock = _compressionLock.catchError((_) {});

    return completer.future;
  }

  /// Record the latest progress for an upload and surface it.
  ///
  /// Android: the native foreground service renders a single aggregate progress
  /// bar (sticky, un-swipeable, survives the app being closed). iOS: per-upload
  /// local notification, kept alive by the heartbeat so a swipe brings it back.
  Future<void> _showProgressNotification(
      int notificationId, int percent, String body,
      {bool indeterminate = false}) async {
    _liveProgress[notificationId] =
        (percent: percent, body: body, indeterminate: indeterminate);
    if (_useForegroundService) {
      await _syncForegroundService();
    } else {
      _ensureHeartbeat();
      await _renderProgress(notificationId, percent, body,
          indeterminate: indeterminate);
    }
  }

  /// Reconcile the Android foreground-service progress notification to the
  /// aggregate of all in-flight uploads. Starts/updates the service while any
  /// upload is active and stops it once the last finishes. Best-effort — a
  /// channel error must never break an upload. No-op off Android.
  Future<void> _syncForegroundService() async {
    if (!_useForegroundService) return;
    try {
      if (_liveProgress.isEmpty) {
        if (_fgsRunning) {
          await _fgsChannel.invokeMethod('stop');
          _fgsRunning = false;
        }
        return;
      }
      final values = _liveProgress.values.toList();
      final count = values.length;
      final sum = values.fold<int>(0, (a, e) => a + e.percent);
      final avg = (sum / count).round().clamp(0, 100);
      // While any upload is still compressing, show an animated indeterminate
      // bar — video_compress's progress stream is unreliable for long videos,
      // so a fixed percentage there is what looked frozen.
      final compressing = values.any((e) => e.indeterminate);
      final title = count == 1 ? 'Uploading post' : 'Uploading $count posts';
      // The bar sits at 100 while the server finishes processing; the text says
      // so instead of looking stuck at 100%.
      final text = compressing
          ? 'Compressing video…'
          : (avg >= 100 ? 'Finishing up…' : '$avg%');
      // First tick starts the service (foreground-only); later ticks just
      // refresh the notification (background-safe).
      await _fgsChannel.invokeMethod(_fgsRunning ? 'update' : 'start', {
        'title': title,
        'text': text,
        'progress': avg,
        'indeterminate': compressing,
      });
      _fgsRunning = true;
    } catch (_) {
      // Best-effort — never let the progress UI abort an upload.
    }
  }

  /// Builds and posts the progress notification. Never throws — a failed
  /// progress update must never surface as an error or abort the upload.
  Future<void> _renderProgress(
      int notificationId, int percent, String body,
      {bool indeterminate = false}) async {
    try {
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
        indeterminate: indeterminate,
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
    } catch (_) {
      // Best-effort — swallow so progress updates never abort an upload.
    }
  }

  /// Start the heartbeat that re-posts every active progress notification, so
  /// one the user swipes away reappears within [_heartbeatInterval]. Self-stops
  /// once no uploads are in flight.
  void _ensureHeartbeat() {
    _progressHeartbeat ??= Timer.periodic(_heartbeatInterval, (_) {
      if (_liveProgress.isEmpty) {
        _progressHeartbeat?.cancel();
        _progressHeartbeat = null;
        return;
      }
      // Snapshot to avoid concurrent-modification if an upload finishes mid-tick.
      for (final entry in _liveProgress.entries.toList()) {
        unawaited(_renderProgress(
            entry.key, entry.value.percent, entry.value.body,
            indeterminate: entry.value.indeterminate));
      }
    });
  }

  Future<void> _showFailedNotification(int notificationId) async {
    // Drop this upload from the live set and reconcile the foreground service /
    // heartbeat, same as the completion path.
    _liveProgress.remove(notificationId);
    await _syncForegroundService();
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

/// A single processed video plus its optional thumbnail, as file paths on disk
/// ready to hand to the native uploader.
class _ProcessedVideo {
  _ProcessedVideo({
    required this.videoPath,
    this.thumbPath,
  });

  final String videoPath;
  final String? thumbPath;
}
