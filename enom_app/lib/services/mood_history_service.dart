import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'mood_detection_service.dart';
import 'api_service.dart';

/// A single mood history entry with all metadata.
class MoodEntry {
  final String? id; // Server-side entry ID (for corrections/deletes)
  final String mood;
  final String emoji;
  final double confidence;
  final int score;
  final String source; // 'camera' or 'manual'
  final DateTime timestamp;

  const MoodEntry({
    this.id,
    required this.mood,
    required this.emoji,
    required this.confidence,
    required this.score,
    this.source = 'camera',
    required this.timestamp,
  });

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    final mood = json['mood'] as String? ?? 'Neutral';
    return MoodEntry(
      id: json['id']?.toString(),
      mood: mood,
      emoji: json['emoji'] as String? ?? _emojiForMood(mood),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      score: (json['score'] as num?)?.toInt() ?? _scoreForMood(mood),
      source: json['source'] as String? ?? 'camera',
      timestamp: DateTime.tryParse(
              json['timestamp'] as String? ??
              json['detectedAt'] as String? ??
              json['detected_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Create from API history response item.
  factory MoodEntry.fromApiEntry(Map<String, dynamic> json) {
    final mood = json['mood'] as String? ?? 'Neutral';
    return MoodEntry(
      id: json['id']?.toString(),
      mood: mood,
      emoji: _emojiForMood(mood),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      score: (json['score'] as num?)?.toInt() ?? _scoreForMood(mood),
      source: json['source'] as String? ?? 'camera',
      timestamp: DateTime.tryParse(
              json['detectedAt'] as String? ??
              json['detected_at'] as String? ??
              json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'mood': mood,
        'emoji': emoji,
        'confidence': confidence,
        'score': score,
        'source': source,
        'timestamp': timestamp.toIso8601String(),
      };

  /// API request format for POST /api/v1/mood/history
  Map<String, dynamic> toApiRequest() => {
        'mood': mood,
        'confidence': confidence,
        'source': source,
        'detectedAt': timestamp.toIso8601String(),
      };

  String get dateKey => DateFormat('yyyy-MM-dd').format(timestamp);

  static String _emojiForMood(String mood) {
    return switch (mood.toLowerCase()) {
      'happy' => '\u{1F60A}',
      'low' || 'sad' => '\u{1F614}',
      'angry' => '\u{1F621}',
      'neutral' => '\u{1F610}',
      _ => '\u{1F610}',
    };
  }

  static int _scoreForMood(String mood) {
    return switch (mood.toLowerCase()) {
      'happy' => 90,
      'neutral' => 50,
      'low' || 'sad' => 30,
      'angry' => 25,
      _ => 50,
    };
  }
}

/// Manages mood history — local storage + API sync.
///
/// API Endpoints used:
/// - POST   /api/v1/mood/history              — Create entry
/// - GET    /api/v1/mood/history              — Get paginated history
/// - DELETE /api/v1/mood/history/{entry_id}   — Delete entry
/// - PUT    /api/v1/mood/history/{entry_id}/correct — Correct mood
/// - POST   /api/v1/mood/history/batch        — Batch sync offline entries
/// - GET    /api/v1/mood/trend                — Mood trend summary
/// - GET    /api/v1/mood/analytics/trends     — 7d/30d/90d trends
/// - GET    /api/v1/mood/analytics/export     — CSV export
class MoodHistoryService {
  static const String _historyKey = 'mood_history';
  static const int _maxEntries = 2000;

  // ── Save ──

  /// Save a mood entry locally and to the API.
  /// Returns the server entry ID if sync succeeds.
  static Future<String?> saveMood(MoodResult mood, {String source = 'camera'}) async {
    final entry = MoodEntry(
      mood: mood.mood,
      emoji: MoodEntry._emojiForMood(mood.mood),
      confidence: mood.confidence,
      score: MoodEntry._scoreForMood(mood.mood),
      source: source,
      timestamp: DateTime.now(),
    );

    // Save locally first
    await _saveLocal(entry);

    // Sync to API
    return _createOnApi(entry);
  }

  /// POST /api/v1/mood/history — Create mood entry on server.
  static Future<String?> _createOnApi(MoodEntry entry) async {
    try {
      final response = await ApiService.post(
        '/api/v1/mood/history',
        entry.toApiRequest(),
        auth: true,
      );
      final status = response['statusCode'] as int;
      final body = response['body'];
      debugPrint('[MOOD_HISTORY] POST status=$status');
      if (status == 200 && body is Map) {
        return body['id']?.toString();
      }
    } catch (e) {
      debugPrint('[MOOD_HISTORY] Save error: $e');
    }
    return null;
  }

  // ── Correct ──

  /// PUT /api/v1/mood/history/{entry_id}/correct — Correct a detected mood.
  static Future<bool> correctMood(String entryId, String newMood, double confidence) async {
    try {
      final response = await ApiService.put(
        '/api/v1/mood/history/$entryId/correct',
        {
          'mood': newMood,
          'confidence': confidence,
          'source': 'manual',
          'detectedAt': DateTime.now().toIso8601String(),
        },
        auth: true,
      );
      return (response['statusCode'] as int) == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Delete ──

  /// DELETE /api/v1/mood/history/{entry_id}
  static Future<bool> deleteEntry(String entryId) async {
    try {
      final response = await ApiService.delete(
        '/api/v1/mood/history/$entryId',
        auth: true,
      );
      return (response['statusCode'] as int) == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Read (Local) ──

  static Future<List<MoodEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => MoodEntry.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final entries = await getEntries();
    return entries.map((e) => e.toJson()).toList();
  }

  static Future<List<MoodEntry>> getEntriesForDate(DateTime date) async {
    final entries = await getEntries();
    return entries.where((e) =>
        e.timestamp.year == date.year &&
        e.timestamp.month == date.month &&
        e.timestamp.day == date.day).toList();
  }

  static Future<Map<int, List<MoodEntry>>> getMonthEntries(int year, int month) async {
    final entries = await getEntries();
    final map = <int, List<MoodEntry>>{};
    for (final entry in entries) {
      if (entry.timestamp.year == year && entry.timestamp.month == month) {
        map.putIfAbsent(entry.timestamp.day, () => []).add(entry);
      }
    }
    return map;
  }

  static Future<Map<int, double>> getMonthScores(int year, int month) async {
    final monthEntries = await getMonthEntries(year, month);
    return monthEntries.map((day, entries) {
      final avg = entries.map((e) => e.score).reduce((a, b) => a + b) / entries.length;
      return MapEntry(day, avg);
    });
  }

  static Future<Map<int, String>> getMonthMoods(int year, int month) async {
    final monthEntries = await getMonthEntries(year, month);
    return monthEntries.map((day, entries) {
      final counts = <String, int>{};
      for (final e in entries) {
        counts[e.mood] = (counts[e.mood] ?? 0) + 1;
      }
      final dominant = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      return MapEntry(day, dominant);
    });
  }

  static Future<List<MoodEntry>> getTodayMoods() async {
    return getEntriesForDate(DateTime.now());
  }

  // ── Trends (Local fallback) ──

  static Future<List<double>> getTrendScores(int days) async {
    final entries = await getEntries();
    final now = DateTime.now();
    final scores = <double>[];

    for (int i = days - 1; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayEntries = entries.where((e) =>
          e.timestamp.year == day.year &&
          e.timestamp.month == day.month &&
          e.timestamp.day == day.day).toList();

      if (dayEntries.isEmpty) {
        scores.add(-1);
      } else {
        final avg = dayEntries.map((e) => e.score).reduce((a, b) => a + b) / dayEntries.length;
        scores.add(avg);
      }
    }
    return scores;
  }

  static Future<List<double>> getWeeklyScores() async {
    final scores = await getTrendScores(7);
    return scores.map((s) => s < 0 ? 0.0 : s / 100.0).toList();
  }

  // ── API Sync ──

  /// GET /api/v1/mood/history — Fetch history from server and merge with local.
  static Future<void> syncFromApi() async {
    try {
      final response = await ApiService.get(
        '/api/v1/mood/history?limit=100',
        auth: true,
      );
      final status = response['statusCode'] as int;
      final body = response['body'];

      debugPrint('[MOOD_HISTORY] GET history status=$status');

      if (status == 200 && body is Map) {
        final List<dynamic> remoteList;
        if (body['data'] is List) {
          remoteList = body['data'] as List<dynamic>;
        } else if (body['entries'] is List) {
          remoteList = body['entries'] as List<dynamic>;
        } else if (body['history'] is List) {
          remoteList = body['history'] as List<dynamic>;
        } else {
          remoteList = [];
        }

        if (remoteList.isEmpty) return;

        final remoteEntries = remoteList
            .map((e) => MoodEntry.fromApiEntry(e as Map<String, dynamic>))
            .toList();

        // Merge with local — deduplicate by timestamp
        final localEntries = await getEntries();
        final allKeys = <String>{};
        final merged = <MoodEntry>[];

        for (final entry in [...localEntries, ...remoteEntries]) {
          final key = '${entry.mood}_${entry.timestamp.toIso8601String()}';
          if (allKeys.add(key)) {
            merged.add(entry);
          }
        }

        merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        final trimmed = merged.length > _maxEntries
            ? merged.sublist(0, _maxEntries)
            : merged;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _historyKey,
          jsonEncode(trimmed.map((e) => e.toJson()).toList()),
        );
      }
    } catch (e) {
      debugPrint('[MOOD_HISTORY] Sync error: $e');
    }
  }

  /// POST /api/v1/mood/history/batch — Batch sync offline entries.
  static Future<void> batchSync() async {
    try {
      final entries = await getEntries();
      // Only sync entries without server ID (not yet synced)
      final unsynced = entries.where((e) => e.id == null).take(50).toList();
      if (unsynced.isEmpty) return;

      final response = await ApiService.post(
        '/api/v1/mood/history/batch',
        {
          'entries': unsynced.map((e) => e.toApiRequest()).toList(),
        },
        auth: true,
      );
      debugPrint('[MOOD_HISTORY] Batch sync: ${response['statusCode']}');
    } catch (e) {
      debugPrint('[MOOD_HISTORY] Batch sync error: $e');
    }
  }

  // ── Analytics API ──

  /// GET /api/v1/mood/analytics/trends — Get trend data from server.
  static Future<Map<String, dynamic>?> getAnalyticsTrends({
    String period = '7d',
  }) async {
    try {
      final tzOffset = DateTime.now().timeZoneOffset.inHours;
      final response = await ApiService.get(
        '/api/v1/mood/analytics/trends?period=$period&tz_offset=$tzOffset',
        auth: true,
      );
      if ((response['statusCode'] as int) == 200) {
        return response['body'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  /// GET /api/v1/mood/trend — Get mood trend summary.
  static Future<Map<String, dynamic>?> getMoodTrend({
    String? startDate,
    String? endDate,
  }) async {
    try {
      var url = '/api/v1/mood/trend';
      final params = <String>[];
      if (startDate != null) params.add('startDate=$startDate');
      if (endDate != null) params.add('endDate=$endDate');
      if (params.isNotEmpty) url += '?${params.join('&')}';

      final response = await ApiService.get(url, auth: true);
      if ((response['statusCode'] as int) == 200) {
        return response['body'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  // ── CSV Export ──

  /// GET /api/v1/mood/analytics/export — Export from server as CSV.
  /// Falls back to local export if API fails.
  static Future<String> exportCsv({String? startDate, String? endDate}) async {
    // Try API export first
    try {
      var url = '/api/v1/mood/analytics/export?format=csv&scope=user';
      if (startDate != null) url += '&startDate=$startDate';
      if (endDate != null) url += '&endDate=$endDate';

      final response = await ApiService.get(url, auth: true);
      if ((response['statusCode'] as int) == 200) {
        final body = response['body'];
        if (body is String && body.contains(',')) {
          // Server returned CSV directly
          final dir = await getApplicationDocumentsDirectory();
          final file = File('${dir.path}/enom_mood_history.csv');
          await file.writeAsString(body);
          return file.path;
        }
      }
    } catch (_) {}

    // Fallback: generate locally
    return _exportLocalCsv();
  }

  static Future<String> _exportLocalCsv() async {
    final entries = await getEntries();
    final buffer = StringBuffer();
    buffer.writeln('Date,Time,Mood,Emoji,Score,Confidence,Source');

    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:mm:ss');

    for (final entry in entries) {
      buffer.writeln(
        '${dateFmt.format(entry.timestamp)},'
        '${timeFmt.format(entry.timestamp)},'
        '${entry.mood},'
        '${entry.emoji},'
        '${entry.score},'
        '${(entry.confidence * 100).round()}%,'
        '${entry.source}',
      );
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/enom_mood_history.csv');
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  // ── Internal ──

  static Future<void> _saveLocal(MoodEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    final list = raw != null
        ? (jsonDecode(raw) as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList()
        : <Map<String, dynamic>>[];
    list.add(entry.toJson());

    final cutoff = DateTime.now().subtract(const Duration(days: 365));
    final filtered = list.where((e) {
      final ts = DateTime.tryParse(e['timestamp'] as String? ?? '');
      return ts != null && ts.isAfter(cutoff);
    }).toList();

    if (filtered.length > _maxEntries) {
      filtered.removeRange(0, filtered.length - _maxEntries);
    }

    await prefs.setString(_historyKey, jsonEncode(filtered));
  }
}
