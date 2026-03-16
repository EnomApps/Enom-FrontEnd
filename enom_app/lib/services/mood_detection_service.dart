import 'dart:async';
import 'dart:ui' as ui;
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

/// Service that manages camera + ML Kit face detection for mood analysis.
class MoodDetectionService {
  CameraController? _cameraController;
  FaceDetector? _faceDetector;
  bool _isProcessing = false;
  bool _isInitialized = false;
  Timer? _processTimer;

  final StreamController<MoodResult> _moodController =
      StreamController<MoodResult>.broadcast();

  Stream<MoodResult> get moodStream => _moodController.stream;
  CameraController? get cameraController => _cameraController;
  bool get isInitialized => _isInitialized;

  Future<bool> initialize() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      // Prefer front camera
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.android
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.fast,
          minFaceSize: 0.15,
        ),
      );

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('MoodDetectionService init error: $e');
      return false;
    }
  }

  /// Start processing camera frames for mood detection.
  void startDetection() {
    if (!_isInitialized || _cameraController == null) return;

    _cameraController!.startImageStream((image) {
      if (_isProcessing) return;
      _isProcessing = true;

      _processImage(image).then((_) {
        _isProcessing = false;
      });
    });
  }

  /// Stop processing but keep camera alive.
  void stopDetection() {
    try {
      if (_cameraController?.value.isStreamingImages ?? false) {
        _cameraController?.stopImageStream();
      }
    } catch (_) {}
  }

  Future<void> _processImage(CameraImage image) async {
    if (_faceDetector == null || _cameraController == null) return;

    try {
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        debugPrint('MoodDetection: inputImage conversion returned null');
        return;
      }

      final faces = await _faceDetector!.processImage(inputImage);
      debugPrint('MoodDetection: detected ${faces.length} face(s)');

      if (faces.isEmpty) {
        _moodController.add(MoodResult.none);
        return;
      }

      // Use the largest face (closest to camera)
      final face = faces.reduce((a, b) =>
          a.boundingBox.width * a.boundingBox.height >
                  b.boundingBox.width * b.boundingBox.height
              ? a
              : b);

      final mood = _classifyMood(face);
      _moodController.add(mood);
    } catch (e) {
      debugPrint('Face processing error: $e');
    }
  }

  InputImage? _convertCameraImage(CameraImage image) {
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    final rotation =
        InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null || image.planes.isEmpty) return null;

    final width = image.width;
    final height = image.height;

    // Build a proper NV21 byte buffer (width * height * 1.5).
    // The camera plugin may split NV21 across planes with row-stride
    // padding, so we strip padding to produce a contiguous buffer.
    final Uint8List bytes;
    if (defaultTargetPlatform == TargetPlatform.android &&
        image.planes.length >= 2) {
      final yPlane = image.planes[0];
      final vuPlane = image.planes[1]; // VU interleaved for NV21

      final int yRowStride = yPlane.bytesPerRow;
      final int vuRowStride = vuPlane.bytesPerRow;

      final nv21 = Uint8List(width * height + width * (height ~/ 2));
      int offset = 0;

      // Copy Y rows, stripping any row-stride padding
      for (int row = 0; row < height; row++) {
        final rowStart = row * yRowStride;
        nv21.setRange(offset, offset + width,
            yPlane.bytes.buffer.asUint8List(yPlane.bytes.offsetInBytes + rowStart, width));
        offset += width;
      }

      // Copy VU rows
      final vuHeight = height ~/ 2;
      for (int row = 0; row < vuHeight; row++) {
        final rowStart = row * vuRowStride;
        nv21.setRange(offset, offset + width,
            vuPlane.bytes.buffer.asUint8List(vuPlane.bytes.offsetInBytes + rowStart, width));
        offset += width;
      }

      bytes = nv21;
    } else {
      bytes = image.planes.first.bytes;
    }

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: ui.Size(width.toDouble(), height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: width, // contiguous, no padding
      ),
    );
  }

  MoodResult _classifyMood(Face face) {
    final smileProb = face.smilingProbability ?? -1;
    final leftEyeOpen = face.leftEyeOpenProbability ?? -1;
    final rightEyeOpen = face.rightEyeOpenProbability ?? -1;
    final headEulerY = face.headEulerAngleY ?? 0; // left/right tilt
    final headEulerZ = face.headEulerAngleZ ?? 0; // tilt

    // Can't classify without expression data
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

    // Happy: big smile
    if (smileProb > 0.75) {
      return MoodResult(
        mood: 'Happy',
        emoji: '\u{1F60A}',
        confidence: smileProb,
        score: (70 + (smileProb * 30)).round(),
      );
    }

    // Surprised: eyes very wide open, low smile
    if (eyeAvg > 0.85 && smileProb < 0.3) {
      return MoodResult(
        mood: 'Surprised',
        emoji: '\u{1F632}',
        confidence: eyeAvg,
        score: 65,
      );
    }

    // Sad: low smile, eyes partially closed
    if (smileProb < 0.2 && eyeAvg >= 0 && eyeAvg < 0.5) {
      return MoodResult(
        mood: 'Sad',
        emoji: '\u{1F622}',
        confidence: 1.0 - smileProb,
        score: (15 + (smileProb * 20)).round(),
      );
    }

    // Angry: no smile, eyes narrowed, possible head tilt
    if (smileProb < 0.15 && eyeAvg >= 0.3 && eyeAvg < 0.65) {
      return MoodResult(
        mood: 'Angry',
        emoji: '\u{1F621}',
        confidence: 1.0 - smileProb,
        score: 25,
      );
    }

    // Calm: slight smile, relaxed eyes
    if (smileProb > 0.3 && smileProb <= 0.75 && eyeAvg > 0.5) {
      return MoodResult(
        mood: 'Calm',
        emoji: '\u{1F60C}',
        confidence: smileProb,
        score: (55 + (smileProb * 25)).round(),
      );
    }

    // Neutral: default
    return MoodResult(
      mood: 'Neutral',
      emoji: '\u{1F610}',
      confidence: 0.5,
      score: 50,
    );
  }

  Future<void> dispose() async {
    _processTimer?.cancel();
    stopDetection();
    await _faceDetector?.close();
    await _cameraController?.dispose();
    await _moodController.close();
    _faceDetector = null;
    _cameraController = null;
    _isInitialized = false;
  }
}
