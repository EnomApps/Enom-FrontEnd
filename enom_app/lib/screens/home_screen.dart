import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/mood_detection_service.dart';
import 'camera_permission_screen.dart';
import 'mood_scan_screen.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'feed_screen.dart';
import 'reels_tab.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final GlobalKey _feedKey = GlobalKey();
  Map<String, dynamic>? _user;
  bool _isLoggingOut = false;
  String _selectedMood = 'Happy';

  // Mood detection
  bool _isMoodInitializing = false;
  MoodResult? _finalMood;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _requestNotificationPermission();
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getUser();
    if (mounted && user != null) {
      setState(() => _user = user);
    }
  }

  Future<void> _startQuickScan() async {
    if (_isMoodInitializing) return;
    setState(() {
      _isMoodInitializing = true;
      _finalMood = null;
    });

    // Check if camera is already granted — skip permission screen
    final existingStatus = await Permission.camera.status;
    if (!existingStatus.isGranted) {
      if (!mounted) return;
      final permResult = await Navigator.push<CameraPermissionResult>(
        context,
        MaterialPageRoute(
          builder: (_) => const CameraPermissionScreen(),
        ),
      );
      if (permResult != CameraPermissionResult.granted) {
        if (mounted) setState(() => _isMoodInitializing = false);
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isMoodInitializing = false);

    // Navigate to mood scan screen and wait for result
    final result = await Navigator.push<MoodResult>(
      context,
      MaterialPageRoute(builder: (_) => const MoodScanScreen()),
    );

    if (mounted && result != null) {
      setState(() {
        _finalMood = result;
        if (result.mood == 'Happy' ||
            result.mood == 'Calm' ||
            result.mood == 'Sad' ||
            result.mood == 'Angry') {
          _selectedMood = result.mood;
        }
      });
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoggingOut = true);
    await AuthService.logout();

    if (!mounted) return;
    setState(() => _isLoggingOut = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  String _getTimeGreeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.translate('good_morning');
    if (hour < 17) return l10n.translate('good_afternoon');
    return l10n.translate('good_evening');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            AppTheme.logo(context, size: 36),
            const SizedBox(width: 10),
            Text(
              'ENOM',
              style: GoogleFonts.cormorantGaramond(
                color: AppTheme.text1(context),
                fontSize: 22,
                fontWeight: FontWeight.w500,
                letterSpacing: 6,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined,
                color: AppTheme.text2(context)),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoggingOut
          ? Center(
              child: CircularProgressIndicator(
                  color: AppTheme.goldColor(context)),
            )
          : _buildBody(l10n),
      extendBody: true,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.navBg(context),
              border: Border(
                top: BorderSide(
                    color: AppTheme.glassBorder(context), width: 0.5),
              ),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                canvasColor: Colors.transparent,
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  if (index == 0 && _currentIndex == 0) {
                    // Re-tapped home tab — scroll to top and refresh
                    try {
                      (_feedKey.currentState as dynamic).scrollToTopAndRefresh();
                    } catch (_) {}
                  }
                  setState(() => _currentIndex = index);
                },
                selectedItemColor: AppTheme.goldColor(context),
                unselectedItemColor: AppTheme.textMuted(context),
                backgroundColor: Colors.transparent,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                selectedLabelStyle:
                    GoogleFonts.jost(fontSize: 9, letterSpacing: 2),
                unselectedLabelStyle:
                    GoogleFonts.jost(fontSize: 9, letterSpacing: 2),
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.home_outlined),
                    activeIcon: const Icon(Icons.home),
                    label: l10n.translate('home').toUpperCase(),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.play_circle_outline),
                    activeIcon: const Icon(Icons.play_circle_filled),
                    label: l10n.translate('reels').toUpperCase(),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.bar_chart_outlined),
                    activeIcon: const Icon(Icons.bar_chart),
                    label: l10n.translate('stats').toUpperCase(),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.search_outlined),
                    activeIcon: const Icon(Icons.search),
                    label: l10n.translate('search').toUpperCase(),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.person_outline_rounded),
                    activeIcon: const Icon(Icons.person_rounded),
                    label: l10n.translate('profile').toUpperCase(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    switch (_currentIndex) {
      case 0:
        return FeedScreen(key: _feedKey);
      case 1:
        return const ReelsTab();
      case 2:
        return _buildHomeTab(l10n);
      case 3:
        return const SearchScreen();
      case 4:
        return _buildProfileTab(l10n);
      default:
        return const FeedScreen();
    }
  }

  Widget _buildHomeTab(AppLocalizations l10n) {
    final userName = _user?['name'] as String? ?? '';
    final displayMood = _finalMood ?? MoodResult.none;
    final moodScore = displayMood.score;
    final moodProgress = moodScore / 100.0;

    return Stack(
      children: [
        const EnomScreenBackground(gradientVariant: 4, particleCount: 45),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Greeting bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTimeGreeting(l10n).toUpperCase(),
                          style: GoogleFonts.jost(
                            color: AppTheme.goldColor(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          userName.isNotEmpty
                              ? userName
                              : l10n.translate('welcome_back'),
                          style: GoogleFonts.cormorantGaramond(
                            color: AppTheme.text1(context),
                            fontSize: 28,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.goldColor(context),
                          width: 1.5,
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppTheme.goldColor(context)
                                .withValues(alpha: 0.15),
                            AppTheme.glassBg(context),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.cormorantGaramond(
                            color: AppTheme.goldColor(context),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Mood Score Card
                _buildMoodScoreCard(moodScore, moodProgress, l10n),
                const SizedBox(height: 20),

                // Final result card (visible after scan completes)
                if (_finalMood != null) _buildResultCard(),
                if (_finalMood != null) const SizedBox(height: 20),

                // How are you feeling?
                Text(
                  l10n.translate('how_are_you_feeling').toUpperCase(),
                  style: AppTheme.label(context, size: 10),
                ),
                const SizedBox(height: 16),
                _buildMoodPills(),
                const SizedBox(height: 24),

                // Weekly Overview
                _buildWeeklyCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Mood Score Card ──────────────────────────────────────────

  Widget _buildMoodScoreCard(int moodScore, double moodProgress, AppLocalizations l10n) {
    final goldC = AppTheme.goldColor(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            color: AppTheme.moodCardBg(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.glassBorder(context)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.isDark(context)
                    ? Colors.black.withValues(alpha: 0.4)
                    : const Color.fromRGBO(160, 140, 100, 0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top edge highlight
              Container(
                height: 1,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      AppTheme.glassHighlight(context),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              Text(
                l10n.translate('your_mood_score').toUpperCase(),
                style: AppTheme.label(context, size: 10),
              ),
              const SizedBox(height: 20),

              // Mood ring
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(140, 140),
                      painter: _MoodRingPainter(
                        progress: moodProgress,
                        goldColors: [
                          AppTheme.gold4,
                          AppTheme.gold2,
                          AppTheme.gold1
                        ],
                        trackColor: AppTheme.glassBg(context),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$moodScore',
                          style: GoogleFonts.cormorantGaramond(
                            color: AppTheme.text1(context),
                            fontSize: 48,
                            fontWeight: FontWeight.w300,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _finalMood != null && _finalMood!.mood != 'No Face'
                              ? _finalMood!.mood
                              : l10n.translate('tap_scan'),
                          style: GoogleFonts.jost(
                            color: AppTheme.goldColor(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Gold line
              Container(
                width: 40,
                height: 2,
                decoration: BoxDecoration(
                  gradient: AppTheme.goldGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Scan button
              ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _isMoodInitializing ? null : _startQuickScan,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          goldC.withValues(alpha: 0.15),
                          goldC.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: goldC.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isMoodInitializing)
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: goldC,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          Icon(Icons.face_retouching_natural,
                              size: 18, color: goldC),
                        const SizedBox(width: 8),
                        Text(
                          _isMoodInitializing
                              ? l10n.translate('opening_camera')
                              : _finalMood != null
                                  ? l10n.translate('scan_again')
                                  : l10n.translate('start_ai_scan'),
                          style: GoogleFonts.jost(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: goldC,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

            ],
          ),
        ),
      ),
    );
  }

  // ─── Result Card (shown after scan) ───────────────────────────

  Widget _buildResultCard() {
    final goldC = AppTheme.goldColor(context);
    final mood = _finalMood!;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.moodCardBg(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.glassBorder(context)),
          ),
          child: Column(
            children: [
              Text(
                AppLocalizations.of(context)!.translate('scan_result').toUpperCase(),
                style: AppTheme.label(context, size: 10),
              ),
              const SizedBox(height: 16),
              // Big emoji
              Text(mood.emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              // Mood name
              Text(
                mood.mood.toUpperCase(),
                style: GoogleFonts.cormorantGaramond(
                  color: AppTheme.text1(context),
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              // Confidence + score row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatChip(
                    AppLocalizations.of(context)!.translate('score'),
                    '${mood.score}',
                    goldC,
                  ),
                  const SizedBox(width: 16),
                  _buildStatChip(
                    AppLocalizations.of(context)!.translate('confidence'),
                    '${(mood.confidence * 100).round()}%',
                    goldC,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Mood message
              Text(
                _getMoodMessage(mood.mood),
                textAlign: TextAlign.center,
                style: GoogleFonts.jost(
                  color: AppTheme.text2(context),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color goldC) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: goldC.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: goldC.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.cormorantGaramond(
              color: goldC,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.jost(
              color: AppTheme.textMuted(context),
              fontSize: 9,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _getMoodMessage(String mood) {
    final l10n = AppLocalizations.of(context)!;
    switch (mood) {
      case 'Happy':
        return l10n.translate('mood_msg_happy');
      case 'Calm':
        return l10n.translate('mood_msg_calm');
      case 'Sad':
        return l10n.translate('mood_msg_sad');
      case 'Angry':
        return l10n.translate('mood_msg_angry');
      case 'Surprised':
        return l10n.translate('mood_msg_surprised');
      case 'Neutral':
        return l10n.translate('mood_msg_neutral');
      default:
        return l10n.translate('mood_msg_default');
    }
  }

  // ─── Mood Pills ───────────────────────────────────────────────

  Widget _buildMoodPills() {
    final l10n = AppLocalizations.of(context)!;
    final moods = [
      ('\u{1F60A}', l10n.translate('mood_happy')),
      ('\u{1F60C}', l10n.translate('mood_calm')),
      ('\u{1F622}', l10n.translate('mood_sad')),
      ('\u{1F621}', l10n.translate('mood_angry')),
      ('\u{1F970}', l10n.translate('mood_loved')),
    ];

    return Row(
      children: moods.map((m) {
        final isActive = _selectedMood == m.$2;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedMood = m.$2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin:
                  EdgeInsets.only(right: m.$2 != 'Loved' ? 10 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.gold1.withValues(alpha: 0.08)
                    : AppTheme.glassBg(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? AppTheme.gold1.withValues(alpha: 0.5)
                      : AppTheme.glassBorder(context),
                ),
              ),
              child: Column(
                children: [
                  Text(m.$1, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 8),
                  Text(
                    m.$2,
                    style: GoogleFonts.jost(
                      color: AppTheme.text2(context),
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── Weekly Card ──────────────────────────────────────────────

  Widget _buildWeeklyCard() {
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final heights = [0.85, 0.92, 0.45, 0.60, 0.30, 0.78, 0.88];

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.moodCardBg(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.glassBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context)!.translate('weekly_overview').toUpperCase(),
                style: AppTheme.label(context, size: 10),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 120,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: i < 6 ? 4 : 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor: heights[i],
                                child: Container(
                                  width: 32,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        const BorderRadius.only(
                                      topLeft: Radius.circular(6),
                                      topRight: Radius.circular(6),
                                      bottomLeft: Radius.circular(2),
                                      bottomRight: Radius.circular(2),
                                    ),
                                    gradient: AppTheme.goldGradient2,
                                  ),
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              const BorderRadius.only(
                                            topLeft:
                                                Radius.circular(6),
                                            topRight:
                                                Radius.circular(6),
                                          ),
                                          gradient: LinearGradient(
                                            begin:
                                                Alignment.topCenter,
                                            end: Alignment.center,
                                            colors: [
                                              Colors.white.withValues(
                                                  alpha: 0.25),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              days[i],
                              style: GoogleFonts.jost(
                                color: AppTheme.textMuted(context),
                                fontSize: 10,
                                letterSpacing: 2,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTab(AppLocalizations l10n) {
    return SafeArea(
      child: ProfileScreen(
        user: _user,
        onUserUpdated: _loadUser,
      ),
    );
  }

  Widget _buildSettingsTab(AppLocalizations l10n) {
    return const SafeArea(
      child: SettingsScreen(),
    );
  }
}

/// Mood ring painter with gold gradient
class _MoodRingPainter extends CustomPainter {
  final double progress;
  final List<Color> goldColors;
  final Color trackColor;

  _MoodRingPainter({
    required this.progress,
    required this.goldColors,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: -pi / 2,
        endAngle: -pi / 2 + 2 * pi * progress,
        colors: goldColors,
      );
      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        -pi / 2,
        2 * pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MoodRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

