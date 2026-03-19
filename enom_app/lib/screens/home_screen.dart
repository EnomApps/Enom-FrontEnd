import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/mood_detection_service.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'feed_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _user;
  bool _isLoggingOut = false;
  String _selectedMood = 'Happy';

  // Mood detection
  MoodDetectionService? _moodService;
  MoodResult _currentMood = MoodResult.none;
  bool _isMoodScanActive = false;
  bool _isMoodInitializing = false;
  String? _moodError;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await ApiService.getUser();
    if (mounted && user != null) {
      setState(() => _user = user);
    }
  }

  Future<void> _startMoodScan() async {
    if (_isMoodInitializing) return;
    setState(() {
      _isMoodInitializing = true;
      _moodError = null;
    });

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _moodError = 'Camera permission denied';
          _isMoodInitializing = false;
        });
      }
      return;
    }

    _moodService = MoodDetectionService();
    final ok = await _moodService!.initialize();

    if (!mounted) return;

    if (!ok) {
      setState(() {
        _moodError = 'Could not initialize camera';
        _isMoodInitializing = false;
      });
      return;
    }

    _moodService!.moodStream.listen((result) {
      if (mounted) {
        setState(() => _currentMood = result);
      }
    });

    _moodService!.startDetection();

    setState(() {
      _isMoodScanActive = true;
      _isMoodInitializing = false;
    });
  }

  Future<void> _stopMoodScan() async {
    _moodService?.stopDetection();
    await _moodService?.dispose();
    _moodService = null;
    if (mounted) {
      setState(() => _isMoodScanActive = false);
    }
  }

  Future<void> _handleLogout() async {
    setState(() => _isLoggingOut = true);
    await _stopMoodScan();
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
    _moodService?.stopDetection();
    _moodService?.dispose();
    super.dispose();
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
            // Mini logo mark
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.goldColor(context),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  'E',
                  style: GoogleFonts.cormorantGaramond(
                    color: AppTheme.goldColor(context),
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
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
                onTap: (index) => setState(() => _currentIndex = index),
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
                    icon: const Icon(Icons.dynamic_feed_outlined),
                    activeIcon: const Icon(Icons.dynamic_feed),
                    label: 'FEED',
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.person_outline),
                    activeIcon: const Icon(Icons.person),
                    label: 'PROFILE',
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.settings_outlined),
                    activeIcon: const Icon(Icons.settings),
                    label: 'SETTINGS',
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
        return _buildHomeTab(l10n);
      case 1:
        return const FeedScreen();
      case 2:
        return _buildProfileTab(l10n);
      case 3:
        return _buildSettingsTab(l10n);
      default:
        return _buildHomeTab(l10n);
    }
  }

  Widget _buildHomeTab(AppLocalizations l10n) {
    final userName = _user?['name'] as String? ?? '';
    final moodScore = _currentMood.score;
    final moodProgress = moodScore / 100.0;

    return Stack(
      children: [
        const EnomScreenBackground(gradientVariant: 4, particleCount: 15),

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
                          'GOOD EVENING',
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
                              ? '$userName \u2728'
                              : l10n.translate('welcome_back'),
                          style: GoogleFonts.cormorantGaramond(
                            color: AppTheme.text1(context),
                            fontSize: 26,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.goldColor(context),
                          width: 1.5,
                        ),
                        color: AppTheme.glassBg(context),
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.jost(
                            color: AppTheme.goldColor(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Mood Score Card (glassmorphic)
                _buildMoodScoreCard(moodScore, moodProgress),
                const SizedBox(height: 24),

                // How are you feeling?
                Text(
                  'HOW ARE YOU FEELING?',
                  style: AppTheme.label(context, size: 10),
                ),
                const SizedBox(height: 16),
                _buildMoodPills(),
                const SizedBox(height: 24),

                // Weekly Overview Card (glassmorphic)
                _buildWeeklyCard(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodScoreCard(int moodScore, double moodProgress) {
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
                'YOUR MOOD SCORE',
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
                        goldColors: [AppTheme.gold4, AppTheme.gold2, AppTheme.gold1],
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
                          _currentMood.mood == 'No Face'
                              ? 'Tap Scan'
                              : 'Feeling Good',
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
              if (!_isMoodScanActive) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _isMoodInitializing ? null : _startMoodScan,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.goldFill(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: goldC.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isMoodInitializing)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: goldC,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          Icon(Icons.face_retouching_natural,
                              size: 16, color: goldC),
                        const SizedBox(width: 6),
                        Text(
                          _isMoodInitializing ? 'Starting...' : 'AI Scan',
                          style: GoogleFonts.jost(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: goldC,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Camera preview when scanning
              if (_isMoodScanActive &&
                  _moodService?.cameraController != null &&
                  _moodService!.cameraController!.value.isInitialized) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: goldC, width: 1.5),
                      ),
                      child: ClipOval(
                        child: Transform.scale(
                          scaleX: -1,
                          child: CameraPreview(
                              _moodService!.cameraController!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_currentMood.emoji,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      _currentMood.mood,
                      style: GoogleFonts.jost(
                        color: AppTheme.text1(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _stopMoodScan,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Stop',
                          style: GoogleFonts.jost(
                            fontSize: 11,
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (_moodError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _moodError!,
                  style: GoogleFonts.jost(
                    color: Colors.redAccent,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodPills() {
    final moods = [
      ('\u{1F60A}', 'Happy'),
      ('\u{1F60C}', 'Calm'),
      ('\u{1F622}', 'Sad'),
      ('\u{1F621}', 'Angry'),
      ('\u{1F970}', 'Loved'),
    ];

    return Row(
      children: moods.map((m) {
        final isActive = _selectedMood == m.$2;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedMood = m.$2),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.only(
                  right: m.$2 != 'Loved' ? 10 : 0),
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
                'WEEKLY OVERVIEW',
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
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(6),
                                      topRight: Radius.circular(6),
                                      bottomLeft: Radius.circular(2),
                                      bottomRight: Radius.circular(2),
                                    ),
                                    gradient: AppTheme.goldGradient2,
                                  ),
                                  child: Stack(
                                    children: [
                                      // Top highlight
                                      Container(
                                        height: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(6),
                                            topRight: Radius.circular(6),
                                          ),
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.center,
                                            colors: [
                                              Colors.white.withValues(alpha: 0.25),
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

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc with gradient
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
