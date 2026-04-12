import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'mood_detection_service.dart';
import 'api_service.dart';

/// A single mood history entry with all metadata.
class MoodEntry {
  final String mood;
  final String emoji;
  final double confidence;
  final int score;
  final DateTime timestamp;

  const MoodEntry({
    required this.mood,
    required this.emoji,
    required this.confidence,
    required this.score,
    required this.timestamp,
  });

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      mood: json['mood'] as String? ?? 'Neutral',
      emoji: json['emoji'] as String? ?? '\u{1F610}',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      score: (json['score'] as num?)?.toInt() ?? 50,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'mood': mood,
        'emoji': emoji,
        'confidence': confidence,
        'score': score,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Date key for grouping (yyyy-MM-dd).
  String get dateKey => DateFormat('yyyy-MM-dd').format(timestamp);
}

/// Manages mood history — local storage (up to 365 days) + API sync.
class MoodHistoryService {
  static const String _historyKey = 'mood_history';
  static const int _maxEntries = 2000; // ~5-6 entries/day × 365 days

  // ── Save ──

  /// Save a mood entry to local storage and attempt API sync.
  static Future<void> saveMood(MoodResult mood) async {
    final entry = MoodEntry(
      mood: mood.mood,
      emoji: mood.emoji,
      confidence: mood.confidence,
      score: mood.score,
      timestamp: DateTime.now(),
    );

    await _saveLocal(entry);
    _syncToApi(entry);
  }

  // ── Read ──

  /// Get all mood history as MoodEntry objects.
  static Future<List<MoodEntry>> getEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => MoodEntry.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // newest first
  }

  /// Get raw history (backward compat).
  static Future<List<Map<String, dynamic>>> getHistory() async {
    final entries = await getEntries();
    return entries.map((e) => e.toJson()).toList();
  }

  /// Get entries for a specific date.
  static Future<List<MoodEntry>> getEntriesForDate(DateTime date) async {
    final entries = await getEntries();
    return entries.where((e) =>
        e.timestamp.year == date.year &&
        e.timestamp.month == date.month &&
        e.timestamp.day == date.day).toList();
  }

  /// Get entries for a specific month (for calendar heatmap).
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

  /// Get average score per day for a month (for heatmap colors).
  static Future<Map<int, double>> getMonthScores(int year, int month) async {
    final monthEntries = await getMonthEntries(year, month);
    return monthEntries.map((day, entries) {
      final avg = entries.map((e) => e.score).reduce((a, b) => a + b) / entries.length;
      return MapEntry(day, avg);
    });
  }

  /// Get dominant mood per day for a month (for heatmap).
  static Future<Map<int, String>> getMonthMoods(int year, int month) async {
    final monthEntries = await getMonthEntries(year, month);
    return monthEntries.map((day, entries) {
      // Most frequent mood for that day
      final counts = <String, int>{};
      for (final e in entries) {
        counts[e.mood] = (counts[e.mood] ?? 0) + 1;
      }
      final dominant = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      return MapEntry(day, dominant);
    });
  }

  /// Get today's moods.
  static Future<List<MoodEntry>> getTodayMoods() async {
    return getEntriesForDate(DateTime.now());
  }

  // ── Trends ──

  /// Get daily average scores for the last N days (for trend charts).
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
        scores.add(-1); // -1 = no data
      } else {
        final avg = dayEntries.map((e) => e.score).reduce((a, b) => a + b) / dayEntries.length;
        scores.add(avg);
      }
    }
    return scores;
  }

  /// Get the last 7 days of average mood scores (normalized 0-1 for chart).
  static Future<List<double>> getWeeklyScores() async {
    final scores = await getTrendScores(7);
    return scores.map((s) => s < 0 ? 0.0 : s / 100.0).toList();
  }

  // ── Sync ──

  /// Pull mood history from backend and merge with local.
  static Future<void> syncFromApi() async {
    try {
      final response = await ApiService.get('/api/mood-history');
      if (response['data'] != null) {
        final remoteEntries = (response['data'] as List<dynamic>)
            .map((e) => MoodEntry.fromJson(e as Map<String, dynamic>))
            .toList();

        // Merge: keep all unique entries by timestamp
        final localEntries = await getEntries();
        final allKeys = <String>{};
        final merged = <MoodEntry>[];

        for (final entry in [...localEntries, ...remoteEntries]) {
          final key = entry.timestamp.toIso8601String();
          if (allKeys.add(key)) {
            merged.add(entry);
          }
        }

        merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // Trim to max and save
        final trimmed = merged.length > _maxEntries
            ? merged.sublist(0, _maxEntries)
            : merged;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          _historyKey,
          jsonEncode(trimmed.map((e) => e.toJson()).toList()),
        );
      }
    } catch (_) {
      // Sync failure is non-fatal
    }
  }

  // ── CSV Export ──

  /// Export mood history as CSV and return the file path.
  static Future<String> exportCsv() async {
    final entries = await getEntries();
    final buffer = StringBuffer();
    buffer.writeln('Date,Time,Mood,Emoji,Score,Confidence');

    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:mm:ss');

    for (final entry in entries) {
      buffer.writeln(
        '${dateFmt.format(entry.timestamp)},'
        '${timeFmt.format(entry.timestamp)},'
        '${entry.mood},'
        '${entry.emoji},'
        '${entry.score},'
        '${(entry.confidence * 100).round()}%',
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

    // Keep entries within 365 days and max count
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

  static Future<void> _syncToApi(MoodEntry entry) async {
    try {
      await ApiService.post('/api/mood-history', entry.toJson());
    } catch (_) {
      // Silently fail — local save is the source of truth
    }
  }
}
