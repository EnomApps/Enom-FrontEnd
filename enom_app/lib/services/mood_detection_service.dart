import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'api_service.dart';

/// Detected mood result from facial expression analysis.
class MoodResult {
  final String mood;
  final String emoji;
  final double confidence;
  final int score;
  final Map<String, double>? allScores;
  final String? requestId;
  final int? processingTimeMs;

  const MoodResult({
    required this.mood,
    required this.emoji,
    required this.confidence,
    required this.score,
    this.allScores,
    this.requestId,
    this.processingTimeMs,
  });

  static const MoodResult none = MoodResult(
    mood: 'No Face',
    emoji: '\u{1F636}',
    confidence: 0,
    score: 0,
  );

  factory MoodResult.fromApiResponse(Map<String, dynamic> json) {
    final mood = json['mood'] as String? ?? 'Neutral';
    final confidence = (json['confidence'] as num?)?.toDouble() ?? 0.5;

    Map<String, double>? allScores;
    if (json['all_scores'] is Map) {
      allScores = (json['all_scores'] as Map).map(
        (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
      );
    }

    return MoodResult(
      mood: mood,
      emoji: _emojiForMood(mood),
      confidence: confidence.clamp(0.0, 1.0),
      score: _scoreForMood(mood, confidence),
      allScores: allScores,
      requestId: json['requestId'] as String?,
      processingTimeMs: (json['processing_time_ms'] as num?)?.toInt(),
    );
  }

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
      'sad' || 'low' => '\u{1F614}',
      'angry' => '\u{1F621}',
      'surprised' => '\u{1F632}',
      'calm' => '\u{1F60C}',
      'neutral' => '\u{1F610}',
      _ => '\u{1F60A}',
    };
  }

  static int _scoreForMood(String mood, double confidence) {
    final base = switch (mood.toLowerCase()) {
      'happy' => 85,
      'calm' => 70,
      'neutral' => 50,
      'surprised' => 65,
      'low' || 'sad' => 30,
      'angry' => 25,
      _ => 50,
    };
    return (base + (confidence * 15)).round().clamp(0, 100);
  }

  Map<String, dynamic> toJson() => {
        'mood': mood,
        'emoji': emoji,
        'confidence': confidence,
        'score': score,
      };
}

/// Result wrapper that carries error details for display.
class MoodDetectionResult {
  final MoodResult? mood;
  final String? error;

  const MoodDetectionResult({this.mood, this.error});
}

/// API-based mood detection service.
class MoodDetectionService {
  static Future<MoodDetectionResult> detectMoodWithDetails(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        return const MoodDetectionResult(error: 'Image file not found');
      }

      final rawBytes = await file.readAsBytes();
      debugPrint('[MOOD_API] Raw image: ${(rawBytes.length / 1024).round()}KB');

      // Process image: fix rotation, flip front camera mirror, re-encode as JPEG
      final processedBytes = await compute(_processImage, rawBytes);
      if (processedBytes == null) {
        return const MoodDetectionResult(error: 'Could not process captured image');
      }

      final sizeKB = (processedBytes.length / 1024).round();
      debugPrint('[MOOD_API] Processed image: ${sizeKB}KB');

      if (processedBytes.length > 1024 * 1024) {
        return MoodDetectionResult(error: 'Image too large (${sizeKB}KB). Max 1MB.');
      }

      final base64Image = base64Encode(processedBytes);

      // Get auth token
      final token = await ApiService.getToken();
      if (token == null || token.isEmpty) {
        return const MoodDetectionResult(error: 'Not authenticated. Please login again.');
      }

      final uri = Uri.parse('${ApiService.baseUrl}/api/v1/mood/detect');
      debugPrint('[MOOD_API] POST $uri | ${sizeKB}KB | token: ${token.length > 10 ? '${token.substring(0, 10)}...' : token}');

      final http.Response response;
      try {
        response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'image': base64Image}),
        ).timeout(const Duration(seconds: 60));
      } catch (e) {
        final errMsg = e.toString();
        if (errMsg.contains('TimeoutException')) {
          return const MoodDetectionResult(error: 'Request timed out. Check your connection.');
        }
        if (errMsg.contains('SocketException') || errMsg.contains('Connection refused')) {
          return const MoodDetectionResult(error: 'Cannot reach server. Check your internet.');
        }
        return MoodDetectionResult(error: 'Network error: $errMsg');
      }

      debugPrint('[MOOD_API] Status: ${response.statusCode}');
      debugPrint('[MOOD_API] Body: ${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        return MoodDetectionResult(
          error: 'Invalid server response (status ${response.statusCode})',
        );
      }

      if (response.statusCode == 200) {
        Map<String, dynamic> moodData;
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('mood')) {
            moodData = decoded;
          } else if (decoded['data'] is Map) {
            moodData = decoded['data'] as Map<String, dynamic>;
          } else if (decoded['result'] is Map) {
            moodData = decoded['result'] as Map<String, dynamic>;
          } else {
            return MoodDetectionResult(
              error: 'Unexpected API response: ${decoded.keys.toList()}',
            );
          }
        } else {
          return MoodDetectionResult(
            error: 'API returned non-JSON: ${decoded.runtimeType}',
          );
        }

        debugPrint('[MOOD_API] Mood: ${moodData['mood']}, Confidence: ${moodData['confidence']}');
        return MoodDetectionResult(mood: MoodResult.fromApiResponse(moodData));
      }

      // Error responses
      String errorMsg;
      String? errorCode;
      if (decoded is Map) {
        errorMsg = (decoded['message'] ?? decoded['error'] ?? decoded['detail'] ?? '').toString();
        errorCode = decoded['error_code']?.toString() ?? decoded['code']?.toString();
        if (decoded['errors'] is Map) {
          final errors = decoded['errors'] as Map;
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            errorMsg = firstError.first.toString();
          }
        }
      } else {
        errorMsg = response.body.length > 200
            ? response.body.substring(0, 200)
            : response.body;
      }

      final detail = errorCode != null ? '[$errorCode] $errorMsg' : errorMsg;

      return switch (response.statusCode) {
        401 => MoodDetectionResult(error: 'Auth failed (401): $detail'),
        422 => MoodDetectionResult(error: '(422) $detail\n\nImage: ${sizeKB}KB JPEG\nURL: $uri'),
        429 => const MoodDetectionResult(error: 'Rate limited. Wait a moment and try again.'),
        _ => MoodDetectionResult(error: 'Server error ${response.statusCode}: $detail'),
      };
    } catch (e) {
      return MoodDetectionResult(error: 'Unexpected error: $e');
    }
  }

  static Future<MoodResult?> detectMood(String imagePath) async {
    final result = await detectMoodWithDetails(imagePath);
    return result.mood;
  }

  static Future<void> dispose() async {}
}

/// Runs in isolate — fix EXIF rotation and compress JPEG.
/// NOTE: We do NOT flip the image — the API's face detection model
/// should handle front-camera (mirrored) images as-is.
Uint8List? _processImage(Uint8List rawBytes) {
  try {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return null;

    // Apply EXIF orientation so the image is upright
    final oriented = img.bakeOrientation(decoded);

    // Re-encode as clean JPEG with 85% quality
    return Uint8List.fromList(img.encodeJpg(oriented, quality: 85));
  } catch (e) {
    // If image processing fails, return raw bytes as fallback
    return rawBytes;
  }
}
