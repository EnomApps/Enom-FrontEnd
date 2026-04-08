import 'dart:io';
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

  /// Create from API response JSON (kept for compatibility).
  factory MoodResult.fromJson(Map<String, dynamic> json) {
    final mood = json['mood'] as String? ?? 'Neutral';
    return MoodResult(
      mood: mood,
      emoji: json['emoji'] as String? ?? _emojiForMood(mood),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.8,
      score: (json['score'] as num?)?.toInt() ?? 50,
    );
  }

  static String _emojiForMood(String mood) {
    return switch (mood.toLowerCase()) {
      'happy' => '\u{1F60A}',
      'sad' => '\u{1F622}',
      'angry' => '\u{1F621}',
      'surprised' => '\u{1F632}',
      'calm' => '\u{1F60C}',
      'neutral' => '\u{1F610}',
      _ => '\u{1F60A}',
    };
  }

  Map<String, dynamic> toJson() => {
        'mood': mood,
        'emoji': emoji,
        'confidence': confidence,
        'score': score,
      };
}

/// On-device mood detection using Google ML Kit Face Detection.
class MoodDetectionService {
  static FaceDetector? _detector;

  static FaceDetector get _faceDetector {
    _detector ??= FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: true,
        enableLandmarks: true,
        performanceMode: FaceDetectorMode.accurate,
      ),
    );
    return _detector!;
  }

  /// Analyze a captured image file and return a MoodResult.
  static Future<MoodResult?> detectMood(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) return null;

      // Use the largest face (most prominent)
      final face = faces.reduce(
        (a, b) => (a.boundingBox.width * a.boundingBox.height) >=
                (b.boundingBox.width * b.boundingBox.height)
            ? a
            : b,
      );

      return _analyzeFace(face);
    } catch (e) {
      return null;
    }
  }

  /// Determine mood from ML Kit face classification values.
  static MoodResult _analyzeFace(Face face) {
    final smileProb = face.smilingProbability ?? -1;
    final leftEyeOpen = face.leftEyeOpenProbability ?? -1;
    final rightEyeOpen = face.rightEyeOpenProbability ?? -1;
    final headAngleY = face.headEulerAngleY ?? 0; // left/right tilt
    final headAngleZ = face.headEulerAngleZ ?? 0; // tilt

    String mood;
    String emoji;
    double confidence;
    int score;

    if (smileProb >= 0.8) {
      // Big smile → Happy
      mood = 'Happy';
      emoji = '\u{1F60A}';
      confidence = smileProb;
      score = 85 + ((smileProb - 0.8) * 75).round().clamp(0, 15);
    } else if (smileProb >= 0.4) {
      // Mild smile → Calm / Content
      mood = 'Calm';
      emoji = '\u{1F60C}';
      confidence = smileProb;
      score = 60 + ((smileProb - 0.4) * 62).round().clamp(0, 25);
    } else if (smileProb >= 0 && smileProb < 0.1) {
      // No smile at all
      if (leftEyeOpen >= 0 && rightEyeOpen >= 0) {
        final avgEyeOpen = (leftEyeOpen + rightEyeOpen) / 2;

        if (avgEyeOpen > 0.85) {
          // Eyes wide open, no smile → Surprised
          mood = 'Surprised';
          emoji = '\u{1F632}';
          confidence = avgEyeOpen;
          score = 65 + ((avgEyeOpen - 0.85) * 233).round().clamp(0, 20);
        } else if (avgEyeOpen < 0.3) {
          // Eyes mostly closed, no smile → Sad
          mood = 'Sad';
          emoji = '\u{1F622}';
          confidence = 1.0 - avgEyeOpen;
          score = 25 + (avgEyeOpen * 50).round().clamp(0, 15);
        } else {
          // Normal eyes, no smile → could be angry or neutral
          if (headAngleZ.abs() > 10 || headAngleY.abs() > 20) {
            mood = 'Angry';
            emoji = '\u{1F621}';
            confidence = 0.6;
            score = 30;
          } else {
            mood = 'Neutral';
            emoji = '\u{1F610}';
            confidence = 0.7;
            score = 50;
          }
        }
      } else {
        mood = 'Neutral';
        emoji = '\u{1F610}';
        confidence = 0.5;
        score = 50;
      }
    } else {
      // Low smile probability (0.1 - 0.4)
      mood = 'Neutral';
      emoji = '\u{1F610}';
      confidence = 0.6;
      score = 45;
    }

    return MoodResult(
      mood: mood,
      emoji: emoji,
      confidence: confidence.clamp(0.0, 1.0),
      score: score.clamp(0, 100),
    );
  }

  /// Release ML Kit resources.
  static Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}
