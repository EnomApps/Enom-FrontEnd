import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/mood_detection_service.dart';
import '../services/mood_history_service.dart';
import '../services/notification_api_service.dart';
import '../services/notification_service.dart';
import 'camera_permission_screen.dart';
import 'mood_history_screen.dart';
import 'mood_scan_screen.dart';
import 'notification_screen.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'feed_screen.dart';
import 'reels_tab.dart';
import 'search_screen.dart';
import 'create_post_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // PageView page index (0..4). Bottom-nav highlight is derived from this.
  // Pages: 0=Home, 1=Mood (hidden swipe-reveal), 2=Reels, 3=Search, 4=Profile.
  int _pageIndex = 0;
  late final PageController _pageCtrl;

  GlobalKey _feedKey = GlobalKey();
  Map<String, dynamic>? _user;
  bool _isLoggingOut = false;
  String _selectedMood = 'Happy';

  // Mood detection
  bool _isMoodInitializing = false;
  MoodResult? _finalMood;

  // Weekly mood history
  List<double> _weeklyScores = [0, 0, 0, 0, 0, 0, 0];

  // Unread notification count
  int _unreadNotifCount = 0;

  // Feed type for dropdown
  String _feedType = 'following'; // 'following', 'for_you', 'favorites'

  // Back-press-to-exit: tracks last back press for the "press again to exit" pattern.
  DateTime? _lastBackPress;

  // Animated app-bar height: 1.0 = fully visible, 0.0 = fully hidden.
  // Hidden when scrolling down, shown when scrolling up (Instagram-style).
  late final AnimationController _appBarAnim;
  static const double _appBarHeight = 40.0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _appBarAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _loadUser();
    _requestNotificationPermission();
    _loadWeeklyScores();
    _loadUnreadCount();
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.status;
    if (status.isDenied) {
      await Permission.notification.request();
    }
  }

  Future<void> _loadWeeklyScores() async {
    final scores = await MoodHistoryService.getWeeklyScoresFromApi();
    if (mounted) {
      setState(() => _weeklyScores = scores);
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final result = await NotificationApiService.getNotifications(page: 1);
      if (result.success) {
        // Reconcile the launcher-icon badge to the server count (single source
        // of truth) even if this screen is no longer mounted.
        await NotificationService.updateBadge(result.unreadCount);
        if (mounted) {
          setState(() => _unreadNotifCount = result.unreadCount);
        }
      }
    } catch (_) {}
  }

  String? _getProfileImageUrl() {
    var url = _user?['profile_image_url'] as String? ?? _user?['profile_image'] as String?;
    if (url != null && url.isNotEmpty && !url.startsWith('http')) {
      url = '${ApiService.baseUrl}/storage/$url';
    }
    return (url != null && url.isNotEmpty) ? url : null;
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
      _loadWeeklyScores(); // Refresh chart after new mood
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
    _appBarAnim.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Bottom-nav ↔ PageView mapping ──
  // Bottom-nav order (7 items): 0=Home, 1=Reels, 2=Mood, 3=Messages*, 4=Dating*,
  // 5=Search, 6=Profile  (* = coming soon — intercepted).
  // PageView pages follow the same order, just skipping the intercepted ones:
  //   page 0=Home, 1=Reels, 2=Mood, 3=Search, 4=Profile
  int _pageForNav(int nav) {
    switch (nav) {
      case 0:
        return 0; // Home
      case 1:
        return 1; // Reels
      case 2:
        return 2; // Mood
      case 5:
        return 3; // Search
      case 6:
        return 4; // Profile
      default:
        return _pageIndex; // Messages/Dating intercept — stay where we are.
    }
  }

  int _navForPage(int page) {
    switch (page) {
      case 0:
        return 0; // Home
      case 1:
        return 1; // Reels
      case 2:
        return 2; // Mood
      case 3:
        return 5; // Search
      case 4:
        return 6; // Profile
      default:
        return 0;
    }
  }

  /// Hide/show the top app bar based on user scroll direction (Instagram style).
  /// Only react to vertical scrolls — horizontal PageView swipes are ignored.
  bool _onScrollNotification(UserScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n.direction == ScrollDirection.reverse) {
      // User swiping up (going deeper into feed) → hide.
      _appBarAnim.reverse();
    } else if (n.direction == ScrollDirection.forward) {
      // User swiping down (back towards top) → show.
      _appBarAnim.forward();
    }
    return false;
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // If not on the Home page, swipe back to Home instead of exiting.
        if (_pageIndex != 0) {
          _pageCtrl.animateToPage(
            0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          );
          return;
        }
        // Modern "press back again to exit" pattern — two taps within 2s exits.
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  l10n.translate('press_back_to_exit'),
                  style: GoogleFonts.jost(
                    color: AppTheme.text1(context),
                    fontSize: 14,
                  ),
                ),
                backgroundColor: AppTheme.bg2(context),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              ),
            );
          return;
        }
        SystemNavigator.pop();
      },
      child: AnimatedBuilder(
        animation: _appBarAnim,
        builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.bg(context),
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
        preferredSize: Size.fromHeight(_appBarHeight * _appBarAnim.value),
        child: ClipRect(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: _appBarAnim.value.clamp(0.0, 1.0),
          child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: _appBarHeight,
          automaticallyImplyLeading: false,
          title: GestureDetector(
            onTap: _showFeedTypeSheet,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppTheme.logo(context, size: 24),
                const SizedBox(width: 6),
                Text(
                  'ENOM',
                  style: GoogleFonts.cormorantGaramond(
                    color: AppTheme.text1(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.text1(context), size: 20),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.add_box_outlined,
                  color: AppTheme.text2(context), size: 22),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CreatePostScreen())),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            IconButton(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(Icons.notifications_outlined,
                      color: AppTheme.text2(context), size: 22),
                  if (_unreadNotifCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.red,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const NotificationScreen()));
                _loadUnreadCount();
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
            const SizedBox(width: 4),
          ],
        ),
        ),
        ),
      ),
      body: NotificationListener<UserScrollNotification>(
        onNotification: _onScrollNotification,
        child: _isLoggingOut
          ? Center(
              child: CircularProgressIndicator(
                  color: AppTheme.goldColor(context)),
            )
          : _buildBody(l10n),
      ),
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
                currentIndex: _navForPage(_pageIndex),
                onTap: (index) {
                  // Messages (3) and Dating (4) — intercept with the coming-soon
                  // sheet and stay on the current page.
                  if (index == 3) {
                    _showComingSoonSheet(
                      title: l10n.translate('messages'),
                      icon: Icons.forum_outlined,
                    );
                    return;
                  }
                  if (index == 4) {
                    _showComingSoonSheet(
                      title: l10n.translate('dating'),
                      icon: Icons.local_fire_department_outlined,
                    );
                    return;
                  }
                  final targetPage = _pageForNav(index);
                  // Tap Home while already on Home (page 0) → scroll feed to top + refresh.
                  if (index == 0 && _pageIndex == 0) {
                    try {
                      (_feedKey.currentState as dynamic).scrollToTopAndRefresh();
                    } catch (_) {}
                  }
                  if (targetPage != _pageIndex) {
                    _pageCtrl.animateToPage(
                      targetPage,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                    );
                  }
                },
                selectedItemColor: AppTheme.goldColor(context),
                unselectedItemColor: AppTheme.textMuted(context),
                backgroundColor: Colors.transparent,
                type: BottomNavigationBarType.fixed,
                elevation: 0,
                iconSize: 20,
                selectedFontSize: 9,
                unselectedFontSize: 9,
                showUnselectedLabels: true,
                selectedLabelStyle:
                    GoogleFonts.jost(fontSize: 8, letterSpacing: 1.0),
                unselectedLabelStyle:
                    GoogleFonts.jost(fontSize: 8, letterSpacing: 1.0),
                items: [
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.home_outlined, size: 20),
                    activeIcon: const Icon(Icons.home, size: 20),
                    label: l10n.translate('home').toUpperCase(),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.play_circle_outline, size: 20),
                    activeIcon: const Icon(Icons.play_circle_filled, size: 20),
                    label: l10n.translate('reels').toUpperCase(),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.sentiment_satisfied_alt_outlined, size: 20),
                    activeIcon: const Icon(Icons.sentiment_satisfied_alt, size: 20),
                    label: l10n.translate('mood').toUpperCase(),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.forum_outlined, size: 20),
                    activeIcon: const Icon(Icons.forum, size: 20),
                    label: l10n.translate('messages').toUpperCase(),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.local_fire_department_outlined, size: 20),
                    activeIcon: const Icon(Icons.local_fire_department, size: 20),
                    label: l10n.translate('dating').toUpperCase(),
                  ),
                  BottomNavigationBarItem(
                    icon: const Icon(Icons.search_outlined, size: 20),
                    activeIcon: const Icon(Icons.search, size: 20),
                    label: l10n.translate('search').toUpperCase(),
                  ),
                  BottomNavigationBarItem(
                    icon: _buildProfileNavIcon(false),
                    activeIcon: _buildProfileNavIcon(true),
                    label: l10n.translate('profile').toUpperCase(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    ),
    );
  }

  void _showFeedTypeSheet() {
    final l10n = AppLocalizations.of(context)!;
    final goldC = AppTheme.goldColor(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _feedTypeOption(ctx, 'following', Icons.people_outline,
                    l10n.translate('following'), goldC),
                _feedTypeOption(ctx, 'for_you', Icons.auto_awesome_outlined,
                    l10n.translate('for_you'), goldC),
                _feedTypeOption(ctx, 'favorites', Icons.favorite_border,
                    l10n.translate('favorites'), goldC),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _feedTypeOption(BuildContext ctx, String type, IconData icon,
      String label, Color goldC) {
    final isSelected = _feedType == type;
    return ListTile(
      leading: Icon(icon,
          color: isSelected ? goldC : AppTheme.text2(context), size: 22),
      title: Text(
        label,
        style: GoogleFonts.jost(
          color: isSelected ? goldC : AppTheme.text1(context),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 15,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: goldC, size: 20)
          : null,
      onTap: () {
        Navigator.pop(ctx);
        if (_feedType != type) {
          setState(() {
            _feedType = type;
            _feedKey = GlobalKey();
          });
        }
      },
    );
  }

  Widget _buildProfileNavIcon(bool isActive) {
    final imageUrl = _getProfileImageUrl();
    final size = 20.0;
    final borderColor = isActive
        ? AppTheme.goldColor(context)
        : Colors.transparent;

    if (imageUrl != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 2),
        ),
        child: ClipOval(
          child: Image.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 3).toInt(),
            errorBuilder: (_, __, ___) => Icon(
              isActive ? Icons.person_rounded : Icons.person_outline_rounded,
              size: size,
            ),
          ),
        ),
      );
    }

    return Icon(
      isActive ? Icons.person_rounded : Icons.person_outline_rounded,
    );
  }

  void _showComingSoonSheet({required String title, required IconData icon}) {
    final l10n = AppLocalizations.of(context)!;
    final goldC = AppTheme.goldColor(context);
    final isDark = AppTheme.isDark(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.7,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [AppTheme.darkBg2, AppTheme.darkBg]
                  : [AppTheme.lightBg2, AppTheme.lightBg],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: goldC.withValues(alpha: 0.25), width: 1),
          ),
          child: SingleChildScrollView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(28, 14, 28, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted(context).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Glowing icon halo
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        goldC.withValues(alpha: 0.35),
                        goldC.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppTheme.goldGradient2,
                        boxShadow: [
                          BoxShadow(
                            color: goldC.withValues(alpha: 0.4),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 38, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Sparkles row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: goldC),
                    const SizedBox(width: 6),
                    Text(
                      l10n.translate('coming_soon').toUpperCase(),
                      style: GoogleFonts.jost(
                        color: goldC,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.auto_awesome, size: 14, color: goldC),
                  ],
                ),
                const SizedBox(height: 14),
                // Feature title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cormorantGaramond(
                    color: AppTheme.text1(context),
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                // Tagline
                Text(
                  l10n.translate('coming_soon_message'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jost(
                    color: AppTheme.text2(context),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Got it button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: goldC,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      l10n.translate('got_it').toUpperCase(),
                      style: GoogleFonts.jost(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    // Instagram-style swipeable tabs. Page order matches the bottom nav
    // (skipping the intercepted Messages/Dating items): Home → Reels → Mood
    // → Search → Profile.
    return PageView(
      controller: _pageCtrl,
      onPageChanged: (page) => setState(() => _pageIndex = page),
      children: [
        FeedScreen(key: _feedKey, feedType: _feedType),
        const ReelsTab(),
        _buildHomeTab(l10n),
        const SearchScreen(),
        _buildProfileTab(l10n),
      ],
    );
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
    final heights = _weeklyScores.map((s) => s > 0 ? s.clamp(0.05, 1.0) : 0.05).toList();

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)!.translate('weekly_overview').toUpperCase(),
                    style: AppTheme.label(context, size: 10),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MoodHistoryScreen())),
                    child: Text(
                      AppLocalizations.of(context)!.translate('view_history'),
                      style: GoogleFonts.jost(
                        color: AppTheme.goldColor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
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

