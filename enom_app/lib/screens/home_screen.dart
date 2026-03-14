import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _user;
  bool _isLoggingOut = false;

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
            const SizedBox(width: 12),
            Text(
              'ENOM',
              style: GoogleFonts.playfairDisplay(
                color: AppTheme.goldColor(context),
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined,
                color: AppTheme.goldColor(context)),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppTheme.goldColor(context)),
            color: AppTheme.isDark(context)
                ? const Color(0xFF1A1A1A)
                : Colors.white,
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout,
                        color: AppTheme.goldColor(context), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.translate('logout'),
                      style: TextStyle(color: AppTheme.text1(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoggingOut
          ? Center(
              child: CircularProgressIndicator(
                  color: AppTheme.goldColor(context)),
            )
          : _buildBody(l10n),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.navBg(context),
          border: Border(
            top: BorderSide(color: AppTheme.cardBorder(context), width: 0.5),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            canvasColor: AppTheme.navBg(context),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            selectedItemColor: AppTheme.goldColor(context),
            unselectedItemColor: AppTheme.text2(context),
            backgroundColor: Colors.transparent,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            selectedLabelStyle:
                GoogleFonts.dmSans(fontSize: 10, letterSpacing: 1),
            unselectedLabelStyle:
                GoogleFonts.dmSans(fontSize: 10, letterSpacing: 1),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const Icon(Icons.home),
                label: l10n.translate('home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.emoji_emotions_outlined),
                activeIcon: const Icon(Icons.emoji_emotions),
                label: l10n.translate('mood'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.people_outline),
                activeIcon: const Icon(Icons.people),
                label: l10n.translate('connect'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: const Icon(Icons.person),
                label: l10n.translate('profile'),
              ),
            ],
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
        return _buildExploreTab(l10n);
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

    return Stack(
      children: [
        const GradientBackground(variant: 4),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                // Greeting row with avatar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GOOD EVENING',
                            style: AppTheme.label(context, size: 11)
                                .copyWith(letterSpacing: 3),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userName.isNotEmpty
                                ? '$userName \u2728'
                                : l10n.translate('welcome_back'),
                            style: AppTheme.heading(context, size: 18),
                          ),
                        ],
                      ),
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
                        color: AppTheme.goldFill(context),
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : 'U',
                          style: GoogleFonts.playfairDisplay(
                            color: AppTheme.goldColor(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Mood Score Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: AppTheme.cardDecoration(context),
                  child: Column(
                    children: [
                      Text(
                        'YOUR MOOD SCORE',
                        style: AppTheme.label(context, size: 10)
                            .copyWith(letterSpacing: 3),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CustomPaint(
                          painter: _MoodRingPainter(
                            progress: 0.78,
                            color: AppTheme.goldColor(context),
                            trackColor: AppTheme.cardBorder(context),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '78',
                                  style: AppTheme.heading(context, size: 28),
                                ),
                                Text(
                                  'Feeling Good',
                                  style: AppTheme.label(context, size: 9)
                                      .copyWith(letterSpacing: 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AppTheme.goldDivider(context),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Mood Emoji Row
                Text(
                  'HOW ARE YOU FEELING?',
                  style: AppTheme.label(context, size: 10)
                      .copyWith(letterSpacing: 3),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildMoodChip('\u{1F60A}', 'Happy'),
                      const SizedBox(width: 10),
                      _buildMoodChip('\u{1F60C}', 'Calm'),
                      const SizedBox(width: 10),
                      _buildMoodChip('\u{1F622}', 'Sad'),
                      const SizedBox(width: 10),
                      _buildMoodChip('\u{1F621}', 'Angry'),
                      const SizedBox(width: 10),
                      _buildMoodChip('\u{1F970}', 'Loved'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Weekly Bar Chart Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'WEEKLY OVERVIEW',
                        style: AppTheme.label(context, size: 10)
                            .copyWith(letterSpacing: 3),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 120,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _buildBar('M', 0.6),
                            _buildBar('T', 0.8),
                            _buildBar('W', 0.5),
                            _buildBar('T', 0.9),
                            _buildBar('F', 0.7),
                            _buildBar('S', 0.4),
                            _buildBar('S', 0.75),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Featured card
                Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.goldColor(context),
                        AppTheme.goldColor(context).withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppTheme.goldColor(context).withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'ENOM',
                          style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.translate('tagline'),
                          style: GoogleFonts.dmSans(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Quick actions grid
                Text(
                  'QUICK ACTIONS',
                  style: AppTheme.label(context, size: 10)
                      .copyWith(letterSpacing: 3),
                ),
                const SizedBox(height: 14),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.3,
                  children: [
                    _buildQuickAction(
                        Icons.shopping_bag_outlined, l10n.translate('shop')),
                    _buildQuickAction(
                        Icons.favorite_outline, l10n.translate('wishlist')),
                    _buildQuickAction(
                        Icons.local_offer_outlined, l10n.translate('offers')),
                    _buildQuickAction(
                        Icons.history, l10n.translate('history')),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoodChip(String emoji, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTheme.label(context, size: 9).copyWith(letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(String day, double height) {
    final gold = AppTheme.goldColor(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 22,
          height: 90 * height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                gold,
                gold.withValues(alpha: 0.4),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          day,
          style: AppTheme.label(context, size: 10).copyWith(letterSpacing: 0),
        ),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.goldColor(context), size: 32),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTheme.body(context, size: 14, weight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreTab(AppLocalizations l10n) {
    return Stack(
      children: [
        const GradientBackground(variant: 4),
        SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_emotions_outlined,
                    size: 64,
                    color: AppTheme.goldColor(context).withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text(
                  l10n.translate('mood'),
                  style: AppTheme.heading(context, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'Coming soon',
                  style: AppTheme.label(context, size: 12),
                ),
              ],
            ),
          ),
        ),
      ],
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

/// Circular ring painter for mood score
class _MoodRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _MoodRingPainter({
    required this.progress,
    required this.color,
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
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MoodRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
