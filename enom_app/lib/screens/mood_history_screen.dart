import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../services/mood_history_service.dart';
import '../theme/app_theme.dart';
import 'mood_result_screen.dart';

/// MOOD-304 — Mood History Screen.
/// Calendar heatmap, entry list, 7/30-day trend charts, CSV export.
class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({super.key});

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _trendTab;

  // Calendar state
  late DateTime _displayedMonth;
  Map<int, String> _monthMoods = {};
  Map<int, double> _monthScores = {};

  // Entries
  List<MoodEntry> _recentEntries = [];
  bool _isLoading = true;

  // Trends
  List<double> _trend7 = [];
  List<double> _trend30 = [];

  @override
  void initState() {
    super.initState();
    _trendTab = TabController(length: 2, vsync: this);
    _displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);
    _loadAll();
  }

  @override
  void dispose() {
    _trendTab.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadMonth(),
      _loadEntries(),
      _loadTrends(),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadMonth() async {
    final moods = await MoodHistoryService.getMonthMoods(
        _displayedMonth.year, _displayedMonth.month);
    final scores = await MoodHistoryService.getMonthScores(
        _displayedMonth.year, _displayedMonth.month);
    if (mounted) {
      setState(() {
        _monthMoods = moods;
        _monthScores = scores;
      });
    }
  }

  Future<void> _loadEntries() async {
    final entries = await MoodHistoryService.getEntries();
    if (mounted) setState(() => _recentEntries = entries.take(50).toList());
  }

  Future<void> _loadTrends() async {
    final t7 = await MoodHistoryService.getTrendScores(7);
    final t30 = await MoodHistoryService.getTrendScores(30);
    if (mounted) {
      setState(() {
        _trend7 = t7;
        _trend30 = t30;
      });
    }
  }

  Future<void> _refresh() async {
    await MoodHistoryService.syncFromApi();
    await _loadAll();
  }

  void _prevMonth() {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1);
    });
    _loadMonth();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = DateTime(_displayedMonth.year, _displayedMonth.month + 1);
    if (next.isBefore(DateTime(now.year, now.month + 1))) {
      setState(() => _displayedMonth = next);
      _loadMonth();
    }
  }

  void _showDayDetail(int day) async {
    final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
    final entries = await MoodHistoryService.getEntriesForDate(date);
    if (!mounted || entries.isEmpty) return;

    final l10n = AppLocalizations.of(context)!;
    final dateFmt = DateFormat.yMMMMd();
    final timeFmt = DateFormat.jm();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        builder: (_, sc) => Container(
          decoration: BoxDecoration(
            color: AppTheme.bg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppTheme.glassBorder(context)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  dateFmt.format(date),
                  style: GoogleFonts.jost(
                    color: AppTheme.text1(context),
                    fontSize: 16, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Divider(color: AppTheme.glassBorder(context), height: 1),
              Expanded(
                child: ListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.all(16),
                  itemCount: entries.length,
                  itemBuilder: (_, i) => _buildEntryTile(entries[i], timeFmt, l10n),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportCsv() async {
    final path = await MoodHistoryService.exportCsv();
    if (mounted) {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path)], text: 'ENOM Mood History'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final goldC = AppTheme.goldColor(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppTheme.text1(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('mood_history'),
          style: GoogleFonts.cormorantGaramond(
            color: AppTheme.text1(context),
            fontSize: 22, fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppTheme.text2(context)),
            color: AppTheme.bg(context),
            onSelected: (val) {
              if (val == 'export') _exportCsv();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 18, color: goldC),
                    const SizedBox(width: 10),
                    Text(l10n.translate('export_csv'),
                        style: TextStyle(color: AppTheme.text1(context))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: goldC,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: goldC))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                children: [
                  // Calendar heatmap
                  _buildCalendarHeatmap(l10n),
                  const SizedBox(height: 24),

                  // Trend charts
                  _buildTrendSection(l10n),
                  const SizedBox(height: 24),

                  // Recent entries
                  _buildRecentSection(l10n),
                ],
              ),
      ),
    );
  }

  // ── Calendar Heatmap ──

  Widget _buildCalendarHeatmap(AppLocalizations l10n) {
    final now = DateTime.now();
    final monthFmt = DateFormat.yMMMM();
    final isCurrentMonth = _displayedMonth.year == now.year &&
        _displayedMonth.month == now.month;
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday; // 1=Mon
    final goldC = AppTheme.goldColor(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.moodCardBg(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.glassBorder(context)),
          ),
          child: Column(
            children: [
              // Month navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: goldC),
                    onPressed: _prevMonth,
                  ),
                  Text(
                    monthFmt.format(_displayedMonth),
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 16, fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right,
                        color: isCurrentMonth ? AppTheme.textMuted(context) : goldC),
                    onPressed: isCurrentMonth ? null : _nextMonth,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Day-of-week headers
              Row(
                children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                    .map((d) => Expanded(
                          child: Center(
                            child: Text(d,
                                style: GoogleFonts.jost(
                                  color: AppTheme.textMuted(context),
                                  fontSize: 11, letterSpacing: 1,
                                )),
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 8),

              // Day cells
              ...List.generate(6, (week) {
                return Row(
                  children: List.generate(7, (weekday) {
                    final cellIndex = week * 7 + weekday;
                    final day = cellIndex - (firstWeekday - 1) + 1;

                    if (day < 1 || day > daysInMonth) {
                      return const Expanded(child: SizedBox(height: 40));
                    }

                    final isToday = isCurrentMonth && day == now.day;
                    final mood = _monthMoods[day];
                    final hasData = mood != null;

                    return Expanded(
                      child: GestureDetector(
                        onTap: hasData ? () => _showDayDetail(day) : null,
                        child: Container(
                          height: 40,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: hasData
                                ? _moodColor(mood).withValues(alpha: 0.25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(color: goldC, width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: hasData
                                ? Text(
                                    _moodEmoji(mood),
                                    style: const TextStyle(fontSize: 16),
                                  )
                                : Text(
                                    '$day',
                                    style: GoogleFonts.jost(
                                      color: AppTheme.textMuted(context),
                                      fontSize: 12,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── Trend Charts ──

  Widget _buildTrendSection(AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.moodCardBg(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.glassBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.translate('mood_trends').toUpperCase(),
                style: AppTheme.label(context, size: 10),
              ),
              const SizedBox(height: 12),

              // Tab bar: 7-day / 30-day
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.glassBg(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _trendTab,
                  indicator: BoxDecoration(
                    color: AppTheme.goldColor(context).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.goldColor(context).withValues(alpha: 0.4)),
                  ),
                  labelColor: AppTheme.goldColor(context),
                  unselectedLabelColor: AppTheme.textMuted(context),
                  labelStyle: GoogleFonts.jost(fontSize: 12, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.jost(fontSize: 12),
                  dividerHeight: 0,
                  tabs: [
                    Tab(text: l10n.translate('seven_days')),
                    Tab(text: l10n.translate('thirty_days')),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Chart
              SizedBox(
                height: 160,
                child: AnimatedBuilder(
                  animation: _trendTab,
                  builder: (_, __) {
                    final data = _trendTab.index == 0 ? _trend7 : _trend30;
                    return _buildLineChart(data);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLineChart(List<double> data) {
    if (data.isEmpty || data.every((s) => s < 0)) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.translate('no_mood_data'),
          style: GoogleFonts.jost(
            color: AppTheme.textMuted(context), fontSize: 13,
          ),
        ),
      );
    }

    final goldC = AppTheme.goldColor(context);
    final spots = <FlSpot>[];
    for (int i = 0; i < data.length; i++) {
      if (data[i] >= 0) {
        spots.add(FlSpot(i.toDouble(), data[i]));
      }
    }

    if (spots.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context)!.translate('no_mood_data'),
          style: GoogleFonts.jost(
            color: AppTheme.textMuted(context), fontSize: 13,
          ),
        ),
      );
    }

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppTheme.glassBorder(context),
            strokeWidth: 0.5,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 25,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}',
                style: GoogleFonts.jost(
                  color: AppTheme.textMuted(context),
                  fontSize: 9,
                ),
              ),
            ),
          ),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: goldC,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: goldC,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  goldC.withValues(alpha: 0.25),
                  goldC.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppTheme.isDark(context)
                ? const Color(0xFF2A2A2A)
                : Colors.white,
            getTooltipItems: (spots) => spots.map((s) {
              return LineTooltipItem(
                '${s.y.toInt()}',
                GoogleFonts.jost(
                  color: goldC,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ── Recent Entries ──

  Widget _buildRecentSection(AppLocalizations l10n) {
    if (_recentEntries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.moodCardBg(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.glassBorder(context)),
        ),
        child: Column(
          children: [
            Icon(Icons.sentiment_neutral_outlined,
                size: 48, color: AppTheme.textMuted(context).withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              l10n.translate('no_mood_data'),
              style: GoogleFonts.jost(
                color: AppTheme.textMuted(context), fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.translate('scan_to_start'),
              style: GoogleFonts.jost(
                color: AppTheme.textMuted(context).withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    final timeFmt = DateFormat.jm();

    // Group by date
    final grouped = <String, List<MoodEntry>>{};
    for (final entry in _recentEntries) {
      grouped.putIfAbsent(entry.dateKey, () => []).add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate('recent_entries').toUpperCase(),
          style: AppTheme.label(context, size: 10),
        ),
        const SizedBox(height: 12),
        ...grouped.entries.take(10).map((group) {
          final date = DateTime.parse(group.key);
          final dateFmt = DateFormat.MMMEd();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Text(
                  dateFmt.format(date),
                  style: GoogleFonts.jost(
                    color: AppTheme.textMuted(context),
                    fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1,
                  ),
                ),
              ),
              ...group.value.map((entry) =>
                  _buildEntryTile(entry, timeFmt, l10n)),
              const SizedBox(height: 8),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildEntryTile(MoodEntry entry, DateFormat timeFmt, AppLocalizations l10n) {
    final moodColor = _moodColor(entry.mood);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.moodCardBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder(context)),
      ),
      child: Row(
        children: [
          // Emoji
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: moodColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(entry.emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          // Mood + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.mood,
                  style: GoogleFonts.jost(
                    color: AppTheme.text1(context),
                    fontSize: 14, fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  timeFmt.format(entry.timestamp),
                  style: GoogleFonts.jost(
                    color: AppTheme.textMuted(context), fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Score + confidence
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score}',
                style: GoogleFonts.cormorantGaramond(
                  color: moodColor, fontSize: 22, fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${(entry.confidence * 100).round()}%',
                style: GoogleFonts.jost(
                  color: AppTheme.textMuted(context), fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  Color _moodColor(String mood) {
    return MoodTheme.forMood(mood).primary;
  }

  String _moodEmoji(String mood) {
    return switch (mood.toLowerCase()) {
      'happy' => '\u{1F60A}',
      'calm' => '\u{1F60C}',
      'sad' => '\u{1F622}',
      'angry' => '\u{1F621}',
      'surprised' => '\u{1F632}',
      'neutral' => '\u{1F610}',
      'low' => '\u{1F614}',
      _ => '\u{1F60A}',
    };
  }
}
