import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/post_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import 'edit_post_screen.dart';
import 'feed_screen.dart';
import 'feed_reels_screen.dart';
import 'follow_list_screen.dart';
import 'likes_list_sheet.dart';
import 'settings_screen.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onUserUpdated;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = false;
  bool _isLoggingOut = false;
  Map<String, dynamic>? _user;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  // Tab controller
  late TabController _tabController;

  // My Posts state
  final List<Map<String, dynamic>> _myPosts = [];
  final ScrollController _postsScrollController = ScrollController();
  String? _postsNextCursor;
  bool _isLoadingPosts = false;
  bool _isLoadingMorePosts = false;
  bool _postsLoaded = false;

  // Saved Posts state
  final List<Map<String, dynamic>> _savedPosts = [];
  final ScrollController _savedScrollController = ScrollController();
  int _savedCurrentPage = 1;
  int _savedLastPage = 1;
  bool _isLoadingSaved = false;
  bool _isLoadingMoreSaved = false;
  bool _savedLoaded = false;

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _countryController;
  late TextEditingController _cityController;
  late TextEditingController _regionController;
  String? _selectedGender;
  DateTime? _selectedDob;
  String? _selectedProfession;
  String? _selectedSocialPersonality;
  String? _selectedPrivacySetting;
  List<String> _selectedContentPreferences = [];
  List<String> _selectedLanguages = [];
  List<int> _selectedInterestIds = [];

  // Available interests from API
  List<Map<String, dynamic>> _availableInterests = [];

  // Follow counts from API
  int _followersCount = 0;
  int _followingCount = 0;

  static const List<String> _professions = [
    'Student', 'Entrepreneur', 'Developer', 'Designer',
    'Business Owner', 'Creator', 'Musician', 'Other',
  ];

  static const List<String> _socialPersonalities = [
    'Creator', 'Viewer', 'Influencer', 'Business', 'Community Builder',
  ];

  static const List<String> _privacySettings = [
    'public', 'private', 'friends_only',
  ];

  static const List<String> _contentPreferenceOptions = [
    'Short videos', 'Articles', 'Podcasts', 'Live streams',
    'Photos', 'Stories', 'Tutorials', 'News',
  ];

  static const List<String> _languageOptions = [
    'English', 'Hindi', 'Tamil', 'Telugu', 'Malayalam', 'Kannada',
    'Bengali', 'Marathi', 'Gujarati', 'Punjabi', 'Urdu',
    'Spanish', 'French', 'German', 'Arabic', 'Chinese',
    'Japanese', 'Korean', 'Portuguese', 'Russian',
  ];

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _initControllers();
    _fetchProfile();
    _fetchInterests();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_postsLoaded) {
        _loadMyPosts();
      }
      if (_tabController.index == 2 && !_savedLoaded) {
        _loadSavedPosts();
      }
    });
    _postsScrollController.addListener(_onPostsScroll);
    _savedScrollController.addListener(_onSavedScroll);
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _user = widget.user;
      _initControllers();
    }
  }

  void _initControllers() {
    _nameController = TextEditingController(text: _user?['name'] as String? ?? '');
    _usernameController = TextEditingController(text: _user?['username'] as String? ?? '');
    _bioController = TextEditingController(text: _user?['bio'] as String? ?? '');
    _locationController = TextEditingController(text: _user?['location'] as String? ?? '');
    _countryController = TextEditingController(text: _user?['country'] as String? ?? '');
    _cityController = TextEditingController(text: _user?['city'] as String? ?? '');
    _regionController = TextEditingController(text: _user?['region'] as String? ?? '');
    _selectedGender = _user?['gender'] as String?;
    _selectedProfession = _user?['profession'] as String?;
    _selectedSocialPersonality = _user?['social_personality'] as String?;
    _selectedPrivacySetting = _user?['privacy_setting'] as String? ?? 'public';

    final dobStr = _user?['dob'] as String?;
    _selectedDob = dobStr != null ? DateTime.tryParse(dobStr) : null;

    // Parse content_preferences
    final cpRaw = _user?['content_preferences'];
    if (cpRaw is List) {
      _selectedContentPreferences = cpRaw.map((e) => e.toString()).toList();
    } else if (cpRaw is String && cpRaw.isNotEmpty) {
      try {
        final decoded = json.decode(cpRaw);
        if (decoded is List) {
          _selectedContentPreferences = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        _selectedContentPreferences = [];
      }
    } else {
      _selectedContentPreferences = [];
    }

    // Parse languages
    final langRaw = _user?['languages'];
    if (langRaw is List) {
      _selectedLanguages = langRaw.map((e) => e.toString()).toList();
    } else if (langRaw is String && langRaw.isNotEmpty) {
      try {
        final decoded = json.decode(langRaw);
        if (decoded is List) {
          _selectedLanguages = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        _selectedLanguages = [];
      }
    } else {
      _selectedLanguages = [];
    }

    // Parse interests
    final interestsRaw = _user?['interests'];
    if (interestsRaw is List) {
      _selectedInterestIds = interestsRaw
          .map((e) => e is Map ? (e['id'] as int?) : null)
          .whereType<int>()
          .toList();
    } else {
      _selectedInterestIds = [];
    }
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.getProfile();
      if (mounted && result.success && result.user != null) {
        setState(() {
          _user = result.user;
          _isLoading = false;
        });
        _initControllers();
        _fetchFollowCounts();
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFollowCounts() async {
    final userId = _user?['id'] as int?;
    if (userId == null) return;
    try {
      final result = await SocialService.getFollowCounts(userId);
      if (mounted && result.success) {
        setState(() {
          _followersCount = result.followersCount;
          _followingCount = result.followingCount;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchInterests() async {
    try {
      final result = await AuthService.getInterests();
      if (mounted && result.success) {
        setState(() => _availableInterests = result.interests);
      }
    } catch (_) {}
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

  void _startEditing() {
    _initControllers();
    _pickedImage = null;
    _pickedImageBytes = null;
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    _pickedImage = null;
    _pickedImageBytes = null;
    setState(() => _isEditing = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked != null && mounted) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _pickedImageBytes = bytes;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        final g = AppTheme.goldColor(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: AppTheme.isDark(context) ? Brightness.dark : Brightness.light,
              primary: g,
              onPrimary: AppTheme.isDark(context) ? Colors.black : Colors.white,
              surface: AppTheme.bg(context),
              onSurface: AppTheme.text1(context),
              secondary: g,
              onSecondary: AppTheme.isDark(context) ? Colors.black : Colors.white,
              error: Colors.redAccent,
              onError: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDob = picked);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final result = await AuthService.updateProfile(
        name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        username: _usernameController.text.trim().isNotEmpty ? _usernameController.text.trim() : null,
        gender: _selectedGender,
        dob: _selectedDob != null
            ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
            : null,
        bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
        location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        profession: _selectedProfession,
        country: _countryController.text.trim().isNotEmpty ? _countryController.text.trim() : null,
        city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        region: _regionController.text.trim().isNotEmpty ? _regionController.text.trim() : null,
        contentPreferences: _selectedContentPreferences.isNotEmpty
            ? json.encode(_selectedContentPreferences)
            : null,
        socialPersonality: _selectedSocialPersonality,
        languages: _selectedLanguages.isNotEmpty
            ? json.encode(_selectedLanguages)
            : null,
        privacySetting: _selectedPrivacySetting,
        interestIds: _selectedInterestIds.isNotEmpty
            ? _selectedInterestIds.join(',')
            : null,
        imagePath: (!kIsWeb && _pickedImage != null) ? _pickedImage!.path : null,
        imageBytes: _pickedImageBytes,
        imageFileName: _pickedImage?.name,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (result.success) {
        setState(() {
          _isEditing = false;
          if (result.user != null) _user = result.user;
          _pickedImage = null;
          _pickedImageBytes = null;
        });
        widget.onUserUpdated();
        AppTheme.showSnackBar(context, result.message, isError: false);
      } else {
        AppTheme.showSnackBar(context, result.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppTheme.showSnackBar(context, 'Network error: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _postsScrollController.dispose();
    _savedScrollController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  void _onPostsScroll() {
    if (_postsScrollController.position.pixels >=
        _postsScrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMyPosts() async {
    final userId = _user?['id'] as int?;
    if (userId == null) return;

    setState(() {
      _isLoadingPosts = true;
      _postsLoaded = true;
    });

    final result = await PostService.getFeed(userId: userId);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _myPosts.clear();
        for (final p in result.posts) {
          if (p is Map<String, dynamic>) _myPosts.add(p);
        }
        _postsNextCursor = result.pagination?['next_cursor'] as String?;
        _isLoadingPosts = false;
      });
    } else {
      setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _loadMorePosts() async {
    final userId = _user?['id'] as int?;
    if (userId == null || _isLoadingMorePosts || _postsNextCursor == null) return;

    setState(() => _isLoadingMorePosts = true);

    final result = await PostService.getFeed(cursor: _postsNextCursor, userId: userId);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        for (final p in result.posts) {
          if (p is Map<String, dynamic>) _myPosts.add(p);
        }
        _postsNextCursor = result.pagination?['next_cursor'] as String?;
        _isLoadingMorePosts = false;
      });
    } else {
      setState(() => _isLoadingMorePosts = false);
    }
  }

  // ─── Saved Posts ───

  void _onSavedScroll() {
    if (_savedScrollController.position.pixels >=
        _savedScrollController.position.maxScrollExtent - 200) {
      _loadMoreSaved();
    }
  }

  Future<void> _loadSavedPosts() async {
    setState(() {
      _isLoadingSaved = true;
      _savedLoaded = true;
    });

    final result = await SocialService.getSavedPosts(page: 1);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _savedPosts.clear();
        for (final p in result.posts) {
          if (p is Map<String, dynamic>) {
            // The saved post might be wrapped: { post: {...} }
            final post = p['post'] as Map<String, dynamic>? ?? p;
            _savedPosts.add(post);
          }
        }
        _savedCurrentPage = result.pagination?['current_page'] ?? 1;
        _savedLastPage = result.pagination?['last_page'] ?? 1;
        _isLoadingSaved = false;
      });
    } else {
      setState(() => _isLoadingSaved = false);
    }
  }

  Future<void> _loadMoreSaved() async {
    if (_isLoadingMoreSaved || _savedCurrentPage >= _savedLastPage) return;

    setState(() => _isLoadingMoreSaved = true);

    final result = await SocialService.getSavedPosts(page: _savedCurrentPage + 1);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        for (final p in result.posts) {
          if (p is Map<String, dynamic>) {
            final post = p['post'] as Map<String, dynamic>? ?? p;
            _savedPosts.add(post);
          }
        }
        _savedCurrentPage = result.pagination?['current_page'] ?? _savedCurrentPage;
        _savedLastPage = result.pagination?['last_page'] ?? _savedLastPage;
        _isLoadingMoreSaved = false;
      });
    } else {
      setState(() => _isLoadingMoreSaved = false);
    }
  }

  // ─── Navigate to Followers/Following ───

  void _openFollowersList() {
    final userId = _user?['id'] as int?;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListScreen(userId: userId, title: 'Followers', isFollowers: true),
      ),
    );
  }

  void _openFollowingList() {
    final userId = _user?['id'] as int?;
    if (userId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FollowListScreen(userId: userId, title: 'Following', isFollowers: false),
      ),
    );
  }

  Future<void> _editMyPost(int index) async {
    final post = _myPosts[index];
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditPostScreen(post: post)),
    );
    if (updated == true) {
      _postsLoaded = false;
      _loadMyPosts();
    }
  }

  Future<void> _deleteMyPost(int index) async {
    final post = _myPosts[index];
    final postId = post['id'] as int;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg2(context),
        title: Text('Delete Post', style: AppTheme.body(context, size: 18, weight: FontWeight.w600)),
        content: Text('Are you sure?', style: AppTheme.body(context, size: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppTheme.text2(context))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final result = await PostService.deletePost(postId);
    if (result.success && mounted) {
      setState(() => _myPosts.removeAt(index));
      AppTheme.showSnackBar(context, 'Post deleted');
    }
  }

  void _openMenuDrawer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppTheme.bg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppTheme.glassBorder(context)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Menu',
                  style: GoogleFonts.jost(
                    color: AppTheme.text1(context),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Divider(color: AppTheme.glassBorder(context), height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _menuItem(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                    _menuItem(
                      icon: Icons.bookmark_border,
                      label: 'Saved Posts',
                      onTap: () {
                        Navigator.pop(ctx);
                        // Switch to saved tab (tab index 1 in profile)
                      },
                    ),
                    _menuItem(
                      icon: Icons.bar_chart_outlined,
                      label: 'Your Activity',
                      onTap: () {
                        Navigator.pop(ctx);
                      },
                    ),
                    const Divider(),
                    _menuItem(
                      icon: Icons.logout,
                      label: 'Logout',
                      color: Colors.redAccent,
                      onTap: () {
                        Navigator.pop(ctx);
                        _handleLogout();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? AppTheme.text1(context);
    return ListTile(
      leading: Icon(icon, color: itemColor, size: 24),
      title: Text(
        label,
        style: GoogleFonts.jost(
          color: itemColor,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading && _user == null) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.goldColor(context)),
      );
    }

    final userName = _user?['name'] as String? ?? '';
    final userUsername = _user?['username'] as String? ?? '';
    final bio = _user?['bio'] as String? ?? '';
    final postsCount = _user?['posts_count'] as int? ?? _myPosts.length;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: username + settings ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  Text(
                    userUsername.isNotEmpty ? userUsername : userName,
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 20),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.menu, color: AppTheme.text1(context), size: 26),
                    onPressed: () => _openMenuDrawer(),
                  ),
                ],
              ),
            ),

            // ── Profile header: avatar left + stats right ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  // Avatar
                  _buildProfileImage(),
                  const SizedBox(width: 24),
                  // Stats row
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatItem('$postsCount', 'posts'),
                        _buildStatItem('$_followersCount', 'followers', onTap: _openFollowersList),
                        _buildStatItem('$_followingCount', 'following', onTap: _openFollowingList),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Name + bio ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (userName.isNotEmpty)
                    Text(
                      userName,
                      style: GoogleFonts.jost(
                        color: AppTheme.text1(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      bio,
                      style: GoogleFonts.jost(
                        color: AppTheme.text1(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Edit profile + Share profile buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: _startEditing,
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppTheme.isDark(context)
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Edit profile',
                          style: GoogleFonts.jost(
                            color: AppTheme.text1(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.isDark(context)
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Share profile',
                        style: GoogleFonts.jost(
                          color: AppTheme.text1(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    height: 36,
                    width: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.isDark(context)
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.person_add_outlined, size: 18, color: AppTheme.text1(context)),
                  ),
                ],
              ),
            ),

            // ── Tab bar (icon-based like Instagram) ──
            TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.text1(context),
              indicatorWeight: 1,
              labelColor: AppTheme.text1(context),
              unselectedLabelColor: AppTheme.textMuted(context),
              tabs: [
                Tab(icon: Icon(Icons.grid_on, size: 24)),
                Tab(icon: Icon(Icons.dynamic_feed_outlined, size: 24)),
                Tab(icon: Icon(Icons.bookmark_border, size: 24)),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: My Profile (details + grid)
                  _buildProfileTabContent(l10n),
                  // Tab 2: My Posts
                  _buildMyPostsTab(),
                  // Tab 3: Saved Posts
                  _buildSavedPostsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTabContent(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          if (!_isEditing) ...[
            Text(
              _user?['email'] as String? ?? '',
              style: TextStyle(
                color: AppTheme.text2(context),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            AppTheme.goldDivider(context),
            const SizedBox(height: 20),
            _buildMenuRow(Icons.analytics_outlined, 'Mood Analytics', onTap: () {}),
            _buildMenuRow(Icons.notifications_outlined, 'Notifications', onTap: () {}),
            _buildMenuRow(Icons.shield_outlined, 'Privacy & Security', onTap: () {}),
            _buildPremiumRow(),
            AppTheme.goldDivider(context),
            const SizedBox(height: 20),
            _buildInfoCard(Icons.alternate_email, l10n.translate('username'), _user?['username'] as String?),
            _buildInfoCard(Icons.person_outline, l10n.translate('gender'), _genderDisplay(l10n)),
            _buildInfoCard(Icons.cake_outlined, l10n.translate('date_of_birth'), _dobDisplay()),
            _buildInfoCard(Icons.info_outline, l10n.translate('bio'), _user?['bio'] as String?),
            _buildInfoCard(Icons.work_outline, 'Profession', _user?['profession'] as String?),
            _buildInfoCard(Icons.location_on_outlined, l10n.translate('location'), _user?['location'] as String?),
            _buildInfoCard(Icons.flag_outlined, 'Country', _user?['country'] as String?),
            _buildInfoCard(Icons.location_city_outlined, 'City', _user?['city'] as String?),
            _buildInfoCard(Icons.map_outlined, 'Region', _user?['region'] as String?),
            _buildInfoCard(Icons.psychology_outlined, 'Social Personality', _user?['social_personality'] as String?),
            _buildInfoCard(Icons.lock_outline, 'Privacy', _privacyDisplay()),
            _buildChipsCard(Icons.video_library_outlined, 'Content Preferences', _contentPrefsDisplay()),
            _buildChipsCard(Icons.language, 'Languages', _languagesDisplay()),
            _buildChipsCard(Icons.interests_outlined, 'Interests', _interestsDisplay()),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startEditing,
                icon: const Icon(Icons.edit, size: 20),
                label: Text(
                  l10n.translate('edit_profile'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: AppTheme.primaryButton(context),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoggingOut ? null : _handleLogout,
                icon: _isLoggingOut
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.logout, size: 20, color: Colors.white),
                label: Text(
                  _isLoggingOut ? 'Logging out...' : 'Logout',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
          if (_isEditing) ...[
            const SizedBox(height: 24),
            _buildTextField(
              controller: _nameController,
              label: l10n.translate('full_name'),
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _usernameController,
              label: l10n.translate('username'),
              icon: Icons.alternate_email,
            ),
            const SizedBox(height: 16),
            _buildGenderDropdown(l10n),
            const SizedBox(height: 16),
            _buildDateField(l10n),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _bioController,
              label: l10n.translate('bio'),
              icon: Icons.info_outline,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              label: 'Profession',
              icon: Icons.work_outline,
              value: _selectedProfession,
              items: _professions,
              onChanged: (val) => setState(() => _selectedProfession = val),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _locationController,
              label: l10n.translate('location'),
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _countryController,
              label: 'Country',
              icon: Icons.flag_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _cityController,
              label: 'City',
              icon: Icons.location_city_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _regionController,
              label: 'Region',
              icon: Icons.map_outlined,
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              label: 'Social Personality',
              icon: Icons.psychology_outlined,
              value: _selectedSocialPersonality,
              items: _socialPersonalities,
              onChanged: (val) => setState(() => _selectedSocialPersonality = val),
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              label: 'Privacy Setting',
              icon: Icons.lock_outline,
              value: _selectedPrivacySetting,
              items: _privacySettings,
              onChanged: (val) => setState(() => _selectedPrivacySetting = val),
            ),
            const SizedBox(height: 16),
            _buildMultiSelectChips(
              label: 'Content Preferences',
              icon: Icons.video_library_outlined,
              options: _contentPreferenceOptions,
              selected: _selectedContentPreferences,
              onChanged: (list) => setState(() => _selectedContentPreferences = list),
            ),
            const SizedBox(height: 16),
            _buildMultiSelectChips(
              label: 'Languages',
              icon: Icons.language,
              options: _languageOptions,
              selected: _selectedLanguages,
              onChanged: (list) => setState(() => _selectedLanguages = list),
            ),
            const SizedBox(height: 16),
            if (_availableInterests.isNotEmpty)
              _buildInterestsSelector(),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancelEditing,
                      style: AppTheme.outlineButton(context),
                      child: Text(l10n.translate('cancel'), style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: AppTheme.primaryButton(context),
                      child: _isSaving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.toggleBg(context),
                              ),
                            )
                          : Text(l10n.translate('save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildMyPostsTab() {
    if (_isLoadingPosts) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.goldColor(context)),
      );
    }

    if (_myPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dynamic_feed_outlined, size: 56, color: AppTheme.goldColor(context).withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No posts yet', style: AppTheme.heading(context, size: 22)),
            const SizedBox(height: 8),
            Text('Your posts will appear here', style: AppTheme.label(context, size: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyPosts,
      color: AppTheme.goldColor(context),
      child: GridView.builder(
        controller: _postsScrollController,
        padding: const EdgeInsets.only(bottom: 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
        ),
        itemCount: _myPosts.length + (_isLoadingMorePosts ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _myPosts.length) {
            return Center(
              child: CircularProgressIndicator(
                color: AppTheme.goldColor(context),
                strokeWidth: 2,
              ),
            );
          }
          return _buildPostGridTile(index);
        },
      ),
    );
  }

  Widget _buildSavedPostsTab() {
    if (_isLoadingSaved) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.goldColor(context)),
      );
    }

    if (_savedPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 56, color: AppTheme.goldColor(context).withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No saved posts', style: AppTheme.heading(context, size: 22)),
            const SizedBox(height: 8),
            Text('Posts you save will appear here', style: AppTheme.label(context, size: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavedPosts,
      color: AppTheme.goldColor(context),
      child: GridView.builder(
        controller: _savedScrollController,
        padding: const EdgeInsets.only(bottom: 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 1.5,
          mainAxisSpacing: 1.5,
        ),
        itemCount: _savedPosts.length + (_isLoadingMoreSaved ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _savedPosts.length) {
            return Center(
              child: CircularProgressIndicator(
                color: AppTheme.goldColor(context),
                strokeWidth: 2,
              ),
            );
          }
          return _buildSavedGridTile(index);
        },
      ),
    );
  }

  Widget _buildPostGridTile(int index) {
    final post = _myPosts[index];
    final media = post['media'] as List<dynamic>? ?? [];
    final content = post['content'] as String? ?? '';

    if (media.isNotEmpty) {
      final type = _getPostMediaType(media[0]);
      final isVideo = type.contains('video');

      // For videos: use thumbnail_url from API, fallback to first non-video media
      // For images: show the image directly
      String? imageUrl;
      if (isVideo) {
        // Check thumbnail_url first (backend-generated thumbnail)
        final videoItem = media[0];
        if (videoItem is Map && videoItem['thumbnail_url'] != null && (videoItem['thumbnail_url'] as String).isNotEmpty) {
          final thumb = videoItem['thumbnail_url'] as String;
          imageUrl = thumb.startsWith('http') ? thumb : '${ApiService.baseUrl}/${thumb.replaceAll(RegExp(r'^/'), '')}';
        } else {
          // Fallback: find a non-video image in the media list
          for (final m in media) {
            if (!_getPostMediaType(m).contains('video')) {
              imageUrl = _getPostMediaUrl(m);
              break;
            }
          }
        }
      } else {
        imageUrl = _getPostMediaUrl(media[0]);
      }

      return GestureDetector(
        onTap: () => _openPostDetail(index),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                cacheWidth: 300,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.bg2(context),
                  child: Icon(Icons.broken_image_outlined, color: AppTheme.textMuted(context)),
                ),
              )
            else
              Container(
                color: AppTheme.isDark(context) ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0),
                child: Center(
                  child: Icon(
                    Icons.videocam_outlined,
                    color: AppTheme.textMuted(context),
                    size: 32,
                  ),
                ),
              ),
            if (isVideo)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 22),
              ),
            if (!isVideo && media.length > 1)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.collections, color: Colors.white, size: 18),
              ),
          ],
        ),
      );
    }

    // Text-only post
    return GestureDetector(
      onTap: () => _openPostDetail(index),
      child: Container(
        color: AppTheme.bg2(context),
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Text(
            content,
            style: GoogleFonts.jost(color: AppTheme.text1(context), fontSize: 12),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildSavedGridTile(int index) {
    final post = _savedPosts[index];
    final media = post['media'] as List<dynamic>? ?? [];
    final content = post['content'] as String? ?? '';

    if (media.isNotEmpty) {
      final type = _getPostMediaType(media[0]);
      final isVideo = type.contains('video');

      String? imageUrl;
      if (isVideo) {
        // Check thumbnail_url first (backend-generated thumbnail)
        final videoItem = media[0];
        if (videoItem is Map && videoItem['thumbnail_url'] != null && (videoItem['thumbnail_url'] as String).isNotEmpty) {
          final thumb = videoItem['thumbnail_url'] as String;
          imageUrl = thumb.startsWith('http') ? thumb : '${ApiService.baseUrl}/${thumb.replaceAll(RegExp(r'^/'), '')}';
        } else {
          for (final m in media) {
            if (!_getPostMediaType(m).contains('video')) {
              imageUrl = _getPostMediaUrl(m);
              break;
            }
          }
        }
      } else {
        imageUrl = _getPostMediaUrl(media[0]);
      }

      return GestureDetector(
        onTap: () => _openSavedPostDetail(index),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                cacheWidth: 300,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.bg2(context),
                  child: Icon(Icons.broken_image_outlined, color: AppTheme.textMuted(context)),
                ),
              )
            else
              Container(
                color: AppTheme.isDark(context) ? const Color(0xFF1A1A1A) : const Color(0xFFE0E0E0),
                child: Center(
                  child: Icon(
                    Icons.videocam_outlined,
                    color: AppTheme.textMuted(context),
                    size: 32,
                  ),
                ),
              ),
            if (isVideo)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.play_circle_fill, color: Colors.white, size: 22),
              ),
            if (!isVideo && media.length > 1)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.collections, color: Colors.white, size: 18),
              ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openSavedPostDetail(index),
      child: Container(
        color: AppTheme.bg2(context),
        padding: const EdgeInsets.all(8),
        child: Center(
          child: Text(
            content,
            style: GoogleFonts.jost(color: AppTheme.text1(context), fontSize: 12),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildSavedPostCard(int index) {
    final post = _savedPosts[index];
    final user = post['user'] as Map<String, dynamic>? ?? {};
    final userName = user['name'] as String? ?? 'Unknown';
    final userAvatar = (user['profile_image_url'] ?? user['profile_image']) as String?;
    final content = post['content'] as String? ?? '';
    final media = post['media'] as List<dynamic>? ?? [];
    final reactionsCount = post['reactions_count'] as int? ?? 0;
    final commentsCount = post['comments_count'] as int? ?? 0;
    final createdAt = post['created_at'] as String? ?? '';
    final viewsCount = post['views_count'] as int? ?? 0;

    String timeAgo = '';
    if (createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAt);
        final diff = DateTime.now().difference(date);
        if (diff.inSeconds < 60) timeAgo = 'Just now';
        else if (diff.inMinutes < 60) timeAgo = '${diff.inMinutes}m ago';
        else if (diff.inHours < 24) timeAgo = '${diff.inHours}h ago';
        else if (diff.inDays < 7) timeAgo = '${diff.inDays}d ago';
        else timeAgo = '${date.day}/${date.month}/${date.year}';
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => _openSavedPostDetail(index),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.isDark(context) ? const Color(0xFF1A1610) : const Color(0xFFFFFCF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.glassBorder(context)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.isDark(context)
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color.fromRGBO(160, 140, 100, 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.goldColor(context).withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: ClipOval(
                      child: userAvatar != null && userAvatar.isNotEmpty
                          ? Image.network(
                              userAvatar.startsWith('http') ? userAvatar : '${ApiService.baseUrl}/$userAvatar',
                              width: 36, height: 36, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                    style: GoogleFonts.jost(color: AppTheme.goldColor(context), fontSize: 14)),
                              ),
                            )
                          : Center(
                              child: Text(userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                                  style: GoogleFonts.jost(color: AppTheme.goldColor(context), fontSize: 14)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userName, style: GoogleFonts.jost(color: AppTheme.text1(context), fontSize: 13, fontWeight: FontWeight.w600)),
                        if (timeAgo.isNotEmpty)
                          Text(timeAgo, style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(Icons.bookmark, size: 20, color: AppTheme.goldColor(context)),
                ],
              ),
            ),
            if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(content, style: GoogleFonts.jost(color: AppTheme.text1(context), fontSize: 14, height: 1.5)),
              ),
            if (media.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildPostMediaGrid(media),
            ],
            // Stats row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: reactionsCount > 0 ? () => LikesListSheet.show(context, post['id'] as int) : null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite, size: 14, color: AppTheme.textMuted(context)),
                        const SizedBox(width: 4),
                        Text('$reactionsCount', style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.chat_bubble_outline, size: 14, color: AppTheme.textMuted(context)),
                  const SizedBox(width: 4),
                  Text('$commentsCount', style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 12)),
                  if (viewsCount > 0) ...[
                    const SizedBox(width: 16),
                    Icon(Icons.visibility_outlined, size: 14, color: AppTheme.textMuted(context)),
                    const SizedBox(width: 4),
                    Text('$viewsCount', style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _openSavedPostDetail(int index) {
    final post = _savedPosts[index];
    final media = post['media'] as List<dynamic>? ?? [];
    final hasVideo = media.any((item) {
      if (item is Map) {
        final type = (item['type'] ?? item['mime_type'] ?? item['file_type'] ?? 'image').toString();
        return type.contains('video');
      }
      return false;
    });

    if (hasVideo) {
      final videoPosts = _savedPosts.where((p) {
        final m = p['media'] as List<dynamic>? ?? [];
        return m.any((item) {
          if (item is Map) {
            final type = (item['type'] ?? item['mime_type'] ?? item['file_type'] ?? 'image').toString();
            return type.contains('video');
          }
          return false;
        });
      }).toList();
      final reelIndex = videoPosts.indexOf(post);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FeedReelsScreen(
            videoPosts: videoPosts,
            initialIndex: reelIndex >= 0 ? reelIndex : 0,
          ),
        ),
      );
    } else {
      final imageUrls = _getPostImageUrls(media);
      if (imageUrls.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullImageScreen(urls: imageUrls),
          ),
        );
      }
    }
  }

  Widget _buildMyPostCard(int index) {
    final post = _myPosts[index];
    final content = post['content'] as String? ?? '';
    final media = post['media'] as List<dynamic>? ?? [];
    final createdAt = post['created_at'] as String? ?? '';
    final reactionsCount = post['reactions_count'] as int? ?? 0;
    final commentsCount = post['comments_count'] as int? ?? 0;

    String timeAgo = '';
    if (createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAt);
        final diff = DateTime.now().difference(date);
        if (diff.inDays > 0) {
          timeAgo = '${diff.inDays}d ago';
        } else if (diff.inHours > 0) {
          timeAgo = '${diff.inHours}h ago';
        } else if (diff.inMinutes > 0) {
          timeAgo = '${diff.inMinutes}m ago';
        } else {
          timeAgo = 'Just now';
        }
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => _openPostDetail(index),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.isDark(context) ? const Color(0xFF1A1610) : const Color(0xFFFFFCF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.glassBorder(context)),
            boxShadow: [
              BoxShadow(
                color: AppTheme.isDark(context)
                    ? Colors.black.withValues(alpha: 0.3)
                    : const Color.fromRGBO(160, 140, 100, 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with time and delete
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: AppTheme.textMuted(context)),
                  const SizedBox(width: 6),
                  Text(timeAgo, style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 12)),
                  if (reactionsCount > 0 || commentsCount > 0) ...[
                    const SizedBox(width: 12),
                    if (reactionsCount > 0)
                      GestureDetector(
                        onTap: () => LikesListSheet.show(context, post['id'] as int),
                        child: Text('\u{2764} $reactionsCount', style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 12)),
                      ),
                    if (commentsCount > 0) ...[
                      const SizedBox(width: 8),
                      Text('\u{1F4AC} $commentsCount', style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 12)),
                    ],
                  ],
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_horiz,
                      color: AppTheme.textMuted(context),
                      size: 20,
                    ),
                    color: AppTheme.bg2(context),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onSelected: (value) {
                      if (value == 'edit') _editMyPost(index);
                      if (value == 'delete') _deleteMyPost(index);
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, color: AppTheme.goldColor(context), size: 18),
                            const SizedBox(width: 8),
                            Text('Edit Post', style: TextStyle(color: AppTheme.text1(context))),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            const SizedBox(width: 8),
                            Text('Delete Post', style: TextStyle(color: AppTheme.text1(context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Content
            if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  content,
                  style: GoogleFonts.jost(
                    color: AppTheme.text1(context),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            // Media
            if (media.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPostMediaGrid(media),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
      ),
    );
  }

  void _openPostDetail(int index) {
    final post = _myPosts[index];
    final media = post['media'] as List<dynamic>? ?? [];
    final hasVideo = media.any((item) {
      if (item is Map) {
        final type = (item['type'] ?? item['mime_type'] ?? item['file_type'] ?? 'image').toString();
        return type.contains('video');
      }
      return false;
    });

    if (hasVideo) {
      // Open in reels view with all video posts
      final videoPosts = _myPosts.where((p) {
        final m = p['media'] as List<dynamic>? ?? [];
        return m.any((item) {
          if (item is Map) {
            final type = (item['type'] ?? item['mime_type'] ?? item['file_type'] ?? 'image').toString();
            return type.contains('video');
          }
          return false;
        });
      }).toList();
      final reelIndex = videoPosts.indexOf(post);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FeedReelsScreen(
            videoPosts: videoPosts,
            initialIndex: reelIndex >= 0 ? reelIndex : 0,
          ),
        ),
      );
    } else {
      // Open image viewer for image posts
      final imageUrls = _getPostImageUrls(media);
      if (imageUrls.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullImageScreen(urls: imageUrls),
          ),
        );
      }
    }
  }

  List<String> _getPostImageUrls(List<dynamic> media) {
    return media
        .where((item) => _getPostMediaType(item).contains('image'))
        .map((item) => _getPostMediaUrl(item))
        .toList();
  }

  Widget _buildPostMediaGrid(List<dynamic> media) {
    final imageUrls = _getPostImageUrls(media);

    if (media.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildMediaWidget(media[0], double.infinity, 240, imageUrls),
        ),
      );
    }

    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildMediaWidget(media[i], 280, 240, imageUrls),
        ),
      ),
    );
  }

  String _getPostMediaUrl(dynamic item) {
    if (item is Map) {
      final url = (item['url'] ?? item['file_url'] ?? item['path'] ?? item['file_path'] ?? item['media_url'] ?? '').toString();
      return url.startsWith('http') ? url : '${ApiService.baseUrl}/${url.replaceAll(RegExp(r'^/'), '')}';
    }
    final url = item.toString();
    return url.startsWith('http') ? url : '${ApiService.baseUrl}/${url.replaceAll(RegExp(r'^/'), '')}';
  }

  String _getPostMediaType(dynamic item) {
    if (item is Map) {
      return (item['type'] ?? item['mime_type'] ?? item['file_type'] ?? 'image').toString();
    }
    return 'image';
  }

  Widget _buildMediaWidget(dynamic item, double width, double height, List<String> imageUrls) {
    final fullUrl = _getPostMediaUrl(item);
    final type = _getPostMediaType(item);

    if (type.contains('video')) {
      return Container(
        width: width == double.infinity ? double.infinity : width,
        height: height,
        color: Colors.black,
        child: FeedInlineVideoPlayer(
          url: fullUrl,
          width: width,
          height: height,
        ),
      );
    }

    final initialIndex = imageUrls.indexOf(fullUrl);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullImageScreen(
              urls: imageUrls,
              initialIndex: initialIndex >= 0 ? initialIndex : 0,
            ),
          ),
        );
      },
      child: Container(
        width: width == double.infinity ? double.infinity : width,
        height: height,
        color: AppTheme.isDark(context)
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFFAFAFA),
        child: Image.network(
          fullUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: height,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.goldColor(context),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.glassBg(context),
            child: Icon(
              Icons.broken_image_outlined,
              color: AppTheme.textMuted(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    // API may return 'profile_image_url' (full URL) or 'profile_image' (relative path)
    var profileImageUrl = _user?['profile_image_url'] as String? ?? _user?['profile_image'] as String?;
    if (profileImageUrl != null && profileImageUrl.isNotEmpty && !profileImageUrl.startsWith('http')) {
      profileImageUrl = '${ApiService.baseUrl}/storage/$profileImageUrl';
    }
    final hasNetworkImage = profileImageUrl != null && profileImageUrl.isNotEmpty;
    final hasPicked = _pickedImageBytes != null;

    final goldC = AppTheme.goldColor(context);
    final goldF = AppTheme.goldFill(context);

    Widget imageWidget;
    if (hasPicked) {
      imageWidget = Image.memory(
        _pickedImageBytes!,
        width: 86,
        height: 86,
        fit: BoxFit.cover,
      );
    } else if (hasNetworkImage) {
      imageWidget = Image.network(
        profileImageUrl,
        width: 86,
        height: 86,
        fit: BoxFit.cover,
        cacheWidth: 300,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 104,
            height: 104,
            color: AppTheme.bg2(context),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: goldC,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 104,
            height: 104,
            color: AppTheme.bg2(context),
            child: Icon(Icons.person, size: 52, color: goldC),
          );
        },
      );
    } else {
      imageWidget = Container(
        width: 86,
        height: 86,
        color: AppTheme.bg2(context),
        child: Icon(Icons.person, size: 52, color: goldC),
      );
    }

    return Stack(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [goldC, goldC.withValues(alpha: 0.5)],
            ),
            boxShadow: [
              BoxShadow(
                color: goldF,
                blurRadius: 24,
                spreadRadius: 6,
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.bg(context),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(child: imageWidget),
          ),
        ),
        if (_isEditing)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: goldC,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt, size: 20, color: AppTheme.toggleBg(context)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.jost(
              color: AppTheme.text1(context),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.jost(
              color: AppTheme.text1(context),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuRow(IconData icon, String title, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.goldColor(context), size: 22),
        title: Text(
          title,
          style: TextStyle(color: AppTheme.text1(context), fontSize: 14),
        ),
        trailing: Icon(Icons.chevron_right, color: AppTheme.text2(context), size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Widget _buildPremiumRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 4),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        leading: Icon(Icons.workspace_premium, color: AppTheme.goldColor(context), size: 22),
        title: Text(
          'ENOM Premium',
          style: TextStyle(color: AppTheme.text1(context), fontSize: 14),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.goldFill(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.goldColor(context).withValues(alpha: 0.3)),
          ),
          child: Text(
            'UPGRADE',
            style: GoogleFonts.dmSans(
              color: AppTheme.goldColor(context),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        onTap: () {},
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String? value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.goldColor(context), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.label(context, size: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value != null && value.isNotEmpty ? value : '—',
                  style: TextStyle(
                    color: value != null && value.isNotEmpty
                        ? AppTheme.text1(context)
                        : AppTheme.text2(context),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsCard(IconData icon, String label, List<String> items) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.goldColor(context), size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: AppTheme.label(context, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text('—', style: TextStyle(color: AppTheme.text2(context), fontSize: 15))
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: items.map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.goldFill(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.goldColor(context).withValues(alpha: 0.3)),
                ),
                child: Text(
                  item,
                  style: TextStyle(color: AppTheme.text1(context), fontSize: 13),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: AppTheme.text1(context)),
      decoration: AppTheme.inputDecoration(context, hint: label, prefixIcon: icon),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      dropdownColor: AppTheme.isDark(context) ? const Color(0xFF121212) : Colors.white,
      style: TextStyle(color: AppTheme.text1(context)),
      decoration: AppTheme.inputDecoration(context, hint: label, prefixIcon: icon),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildGenderDropdown(AppLocalizations l10n) {
    return _buildDropdownField(
      label: l10n.translate('gender'),
      icon: Icons.wc_outlined,
      value: _selectedGender,
      items: const ['male', 'female', 'other'],
      onChanged: (val) => setState(() => _selectedGender = val),
    );
  }

  Widget _buildDateField(AppLocalizations l10n) {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextField(
          style: TextStyle(color: AppTheme.text1(context)),
          controller: TextEditingController(
            text: _selectedDob != null
                ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
                : '',
          ),
          decoration: AppTheme.inputDecoration(
            context,
            hint: l10n.translate('date_of_birth'),
            prefixIcon: Icons.cake_outlined,
            suffixIcon: Icon(Icons.calendar_today, color: AppTheme.text2(context), size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectChips({
    required String label,
    required IconData icon,
    required List<String> options,
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
  }) {
    final goldC = AppTheme.goldColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.inputBg(context),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.inputBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: goldC.withValues(alpha: 0.7), size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(color: AppTheme.text2(context), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              return FilterChip(
                label: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? AppTheme.toggleBg(context) : AppTheme.text1(context),
                    fontSize: 13,
                  ),
                ),
                selected: isSelected,
                selectedColor: goldC,
                backgroundColor: AppTheme.cardBg(context),
                checkmarkColor: AppTheme.toggleBg(context),
                side: BorderSide(
                  color: isSelected
                      ? goldC
                      : AppTheme.cardBorder(context),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (val) {
                  final updated = List<String>.from(selected);
                  if (val) {
                    updated.add(option);
                  } else {
                    updated.remove(option);
                  }
                  onChanged(updated);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSelector() {
    final goldC = AppTheme.goldColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.inputBg(context),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.inputBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.interests_outlined, color: goldC.withValues(alpha: 0.7), size: 22),
              const SizedBox(width: 10),
              Text(
                'Interests (max 10)',
                style: TextStyle(color: AppTheme.text2(context), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableInterests.map((interest) {
              final id = interest['id'] as int;
              final name = interest['name'] as String? ?? '';
              final isSelected = _selectedInterestIds.contains(id);
              return FilterChip(
                label: Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? AppTheme.toggleBg(context) : AppTheme.text1(context),
                    fontSize: 13,
                  ),
                ),
                selected: isSelected,
                selectedColor: goldC,
                backgroundColor: AppTheme.cardBg(context),
                checkmarkColor: AppTheme.toggleBg(context),
                side: BorderSide(
                  color: isSelected
                      ? goldC
                      : AppTheme.cardBorder(context),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      if (_selectedInterestIds.length < 10) {
                        _selectedInterestIds.add(id);
                      } else {
                        AppTheme.showSnackBar(context, 'Maximum 10 interests allowed', isError: true);
                      }
                    } else {
                      _selectedInterestIds.remove(id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String? _genderDisplay(AppLocalizations l10n) {
    final gender = _user?['gender'] as String?;
    if (gender == null) return null;
    switch (gender) {
      case 'male':
        return l10n.translate('male');
      case 'female':
        return l10n.translate('female');
      case 'other':
        return l10n.translate('other_gender');
      default:
        return gender;
    }
  }

  String? _dobDisplay() {
    final dob = _user?['dob'] as String?;
    if (dob == null) return null;
    final date = DateTime.tryParse(dob);
    if (date == null) return dob;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String? _privacyDisplay() {
    final p = _user?['privacy_setting'] as String?;
    if (p == null) return null;
    switch (p) {
      case 'friends_only':
        return 'Friends Only';
      default:
        return p[0].toUpperCase() + p.substring(1);
    }
  }

  List<String> _contentPrefsDisplay() {
    final raw = _user?['content_preferences'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  List<String> _languagesDisplay() {
    final raw = _user?['languages'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  List<String> _interestsDisplay() {
    final raw = _user?['interests'];
    if (raw is List) {
      return raw.map((e) => e is Map ? (e['name']?.toString() ?? '') : e.toString()).toList();
    }
    return [];
  }
}
