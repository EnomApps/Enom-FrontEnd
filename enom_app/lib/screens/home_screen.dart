import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : const Color(0xFFF5F5F5);
    final appBarColor = isDark ? Colors.black : Colors.white;
    final navBarBg = isDark ? const Color(0xFF0A0A0A) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              'assets/images/enom_logo.gif',
              width: 36,
              height: 36,
            ),
            const SizedBox(width: 12),
            const Text(
              'ENOM',
              style: TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined,
                color: Color(0xFFD4AF37)),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFFD4AF37)),
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
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
                    const Icon(Icons.logout, color: Color(0xFFD4AF37), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      l10n.translate('logout'),
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoggingOut
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
            )
          : _buildBody(l10n),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: navBarBg,
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: const Color(0xFFD4AF37),
          unselectedItemColor: isDark
              ? Colors.white.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.4),
          backgroundColor: navBarBg,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: l10n.translate('home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.explore_outlined),
              activeIcon: const Icon(Icons.explore),
              label: l10n.translate('explore'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: l10n.translate('profile'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: l10n.translate('settings'),
            ),
          ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final userName = _user?['name'] as String? ?? '';
    final greeting = userName.isNotEmpty
        ? '${l10n.translate('welcome_back')}\n$userName'
        : l10n.translate('welcome_back');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Text(
            greeting,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Featured card
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFFD4AF37), Color(0xFF8B7536)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'ENOM',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.translate('tagline'),
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Quick actions grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: [
              _buildQuickAction(Icons.shopping_bag_outlined, l10n.translate('shop')),
              _buildQuickAction(Icons.favorite_outline, l10n.translate('wishlist')),
              _buildQuickAction(Icons.local_offer_outlined, l10n.translate('offers')),
              _buildQuickAction(Icons.history, l10n.translate('history')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 32),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreTab(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_outlined,
              size: 64, color: const Color(0xFFD4AF37).withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            l10n.translate('explore'),
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(AppLocalizations l10n) {
    return ProfileScreen(
      user: _user,
      onUserUpdated: _loadUser,
    );
  }

  Widget _buildSettingsTab(AppLocalizations l10n) {
    return const SettingsScreen();
  }
}
