import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Detected mood result from facial expression analysis.
class MoodResult {
  final String mood;
  final String emoji;
  final double confidence;
  final int score;

  const MoodResult({
    required this.mood,
    required this.emoji,
    required this.confidence,
    required this.score,
  });

  static const MoodResult none = MoodResult(
    mood: 'No Face',
    emoji: '\u{1F636}',
    confidence: 0,
    score: 0,
  );
}

/// Scan progress event emitted during quick scan.
class ScanProgress {
  final double progress; // 0.0 to 1.0
  final MoodResult? latestMood;
  final bool isDone;
  final MoodResult? finalResult;

  const ScanProgress({
    required this.progress,
    this.latestMood,
    this.isDone = false,
    this.finalResult,
  });
}

/// Fast face mood detection service using photo capture (reliable on all devices).
class MoodDetectionService {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isInitialized = false;
  Timer? _captureTimer;
  bool _isBusy = false;

  final StreamController<ScanProgress> _scanController =
      StreamController<ScanProgress>.broadcast();

  Stream<ScanProgress> get scanStream => _scanController.stream;
  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;

  static const _scanDuration = Duration(seconds: 5);
  static const _captureInterval = Duration(milliseconds: 600);

  Future<bool> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.accurate,
          minFaceSize: 0.1,
        ),
      );

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('MoodDetectionService init error: $e');
      return false;
    }
  }

  /// Start a quick 5-second scan using photo captures.
  void startQuickScan() {
    if (!_isInitialized || _cameraController == null) return;

    final allResults = <MoodResult>[];
    final startTime = DateTime.now();

    // Capture a photo every 600ms and analyze it
    _captureTimer = Timer.periodic(_captureInterval, (timer) async {
      if (_isBusy) return;
      _isBusy = true;

      try {
        final elapsed = DateTime.now().difference(startTime);
        final progress =
            (elapsed.inMilliseconds / _scanDuration.inMilliseconds)
                .clamp(0.0, 1.0);

        // Take a picture
        final XFile photo = await _cameraController!.takePicture();
        final inputImage = InputImage.fromFilePath(photo.path);
        final faces = await _faceDetector!.processImage(inputImage);

        // Clean up temp file
        try {
          await File(photo.path).delete();
        } catch (_) {}

        MoodResult mood = MoodResult.none;
        if (faces.isNotEmpty) {
          final face = faces.reduce((a, b) =>
              a.boundingBox.width * a.boundingBox.height >
                      b.boundingBox.width * b.boundingBox.height
                  ? a
                  : b);
          mood = _classifyMood(face);
          if (mood.mood != 'No Face') {
            allResults.add(mood);
          }
        }

        debugPrint(
            'Scan: ${faces.length} faces, mood=${mood.mood}, progress=${(progress * 100).round()}%');

        _scanController.add(ScanProgress(
          progress: progress,
          latestMood: mood,
        ));

        // Time's up
        if (elapsed >= _scanDuration) {
          timer.cancel();
          _captureTimer = null;
          final finalMood = _computeFinalMood(allResults);
          _scanController.add(ScanProgress(
            progress: 1.0,
            latestMood: finalMood,
            isDone: true,
            finalResult: finalMood,
          ));
        }
      } catch (e) {
        debugPrint('Capture error: $e');
      } finally {
        _isBusy = false;
      }
    });
  }

  /// Pick the dominant mood from all collected samples.
  MoodResult _computeFinalMood(List<MoodResult> results) {
    if (results.isEmpty) return MoodResult.none;

    final counts = <String, int>{};
    final bestPerMood = <String, MoodResult>{};

    for (final r in results) {
      counts[r.mood] = (counts[r.mood] ?? 0) + 1;
      final existing = bestPerMood[r.mood];
      if (existing == null || r.confidence > existing.confidence) {
        bestPerMood[r.mood] = r;
      }
    }

    final topMood =
        counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return bestPerMood[topMood]!;
  }

  MoodResult _classifyMood(Face face) {
    final smileProb = face.smilingProbability ?? -1;
    final leftEyeOpen = face.leftEyeOpenProbability ?? -1;
    final rightEyeOpen = face.rightEyeOpenProbability ?? -1;

    debugPrint(
        'Face data: smile=$smileProb, leftEye=$leftEyeOpen, rightEye=$rightEyeOpen');

    // No classification data available
    if (smileProb < 0 && leftEyeOpen < 0) {
      return const MoodResult(
        mood: 'Neutral',
        emoji: '\u{1F610}',
        confidence: 0.5,
        score: 50,
      );
    }

    final eyeAvg = (leftEyeOpen >= 0 && rightEyeOpen >= 0)
        ? (leftEyeOpen + rightEyeOpen) / 2
        : -1.0;

    // Happy: smiling
    if (smileProb > 0.55) {
      return MoodResult(
        mood: 'Happy',
        emoji: '\u{1F60A}',
        confidence: smileProb,
        score: (70 + (smileProb * 30)).round(),
      );
    }

    // Surprised: eyes very wide open, low smile
    if (eyeAvg > 0.85 && smileProb >= 0 && smileProb < 0.3) {
      return MoodResult(
        mood: 'Surprised',
        emoji: '\u{1F632}',
        confidence: eyeAvg,
        score: 65,
      );
    }

    // Sad: low smile, eyes partially closed
    if (smileProb >= 0 && smileProb < 0.25 && eyeAvg >= 0 && eyeAvg < 0.5) {
      return MoodResult(
        mood: 'Sad',
        emoji: '\u{1F622}',
        confidence: 1.0 - smileProb,
        score: (15 + (smileProb * 20)).round(),
      );
    }

    // Angry: no smile, eyes narrowed
    if (smileProb >= 0 && smileProb < 0.2 && eyeAvg >= 0.3 && eyeAvg < 0.65) {
      return MoodResult(
        mood: 'Angry',
        emoji: '\u{1F621}',
        confidence: 1.0 - smileProb,
        score: 25,
      );
    }

    // Calm: slight smile, relaxed eyes
    if (smileProb > 0.25 && smileProb <= 0.55 && eyeAvg > 0.5) {
      return MoodResult(
        mood: 'Calm',
        emoji: '\u{1F60C}',
        confidence: smileProb,
        score: (55 + (smileProb * 25)).round(),
      );
    }

    // Neutral
    return MoodResult(
      mood: 'Neutral',
      emoji: '\u{1F610}',
      confidence: 0.5,
      score: 50,
    );
  }

  Future<void> dispose() async {
    _captureTimer?.cancel();
    _captureTimer = null;
    await _faceDetector?.close();
    await _cameraController?.dispose();
    await _scanController.close();
    _faceDetector = null;
    _cameraController = null;
    _isInitialized = false;
  }
}
