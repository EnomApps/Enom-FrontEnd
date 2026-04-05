import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import 'user_profile_screen.dart';

/// Screen that shows a list of followers or following users.
class FollowListScreen extends StatefulWidget {
  final int userId;
  final String title; // 'Followers' or 'Following'
  final bool isFollowers; // true = followers, false = following

  const FollowListScreen({
    super.key,
    required this.userId,
    required this.title,
    required this.isFollowers,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final List<Map<String, dynamic>> _users = [];
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  int _lastPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  // Track follow state per user id
  final Map<int, bool> _followStates = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    final result = widget.isFollowers
        ? await SocialService.getFollowers(widget.userId, page: 1)
        : await SocialService.getFollowing(widget.userId, page: 1);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _users.clear();
        for (final u in result.users) {
          if (u is Map<String, dynamic>) {
            _users.add(u);
          }
        }
        _currentPage = result.pagination?['current_page'] ?? 1;
        _lastPage = result.pagination?['last_page'] ?? 1;
        _isLoading = false;
      });
      // Fetch follow status for each user
      _fetchFollowStatuses();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchFollowStatuses() async {
    final userIds = _users
        .map((u) => (u['id'] ?? u['user_id']) as int?)
        .whereType<int>()
        .toList();
    if (userIds.isEmpty) return;
    final statuses = await SocialService.batchFollowStatus(userIds);
    if (mounted) {
      setState(() => _followStates.addAll(statuses));
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _currentPage >= _lastPage) return;

    setState(() => _isLoadingMore = true);

    final result = widget.isFollowers
        ? await SocialService.getFollowers(widget.userId, page: _currentPage + 1)
        : await SocialService.getFollowing(widget.userId, page: _currentPage + 1);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        for (final u in result.users) {
          if (u is Map<String, dynamic>) {
            _users.add(u);
          }
        }
        _currentPage = result.pagination?['current_page'] ?? _currentPage;
        _lastPage = result.pagination?['last_page'] ?? _lastPage;
        _isLoadingMore = false;
      });
      _fetchFollowStatuses();
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _toggleFollow(int userId) async {
    final current = _followStates[userId] ?? false;
    setState(() => _followStates[userId] = !current);

    final result = await SocialService.toggleFollow(userId);
    if (mounted && result.success) {
      setState(() => _followStates[userId] = result.isFollowing);
    } else if (mounted) {
      setState(() => _followStates[userId] = current);
    }
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: AppTheme.text1(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title, style: AppTheme.label(context, size: 12)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const EnomScreenBackground(gradientVariant: 2, particleCount: 30),
          SafeArea(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: AppTheme.goldColor(context)))
                : _users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 56, color: AppTheme.goldColor(context).withValues(alpha: 0.4)),
                            const SizedBox(height: 16),
                            Text(l10n.translate(widget.isFollowers ? 'no_followers_yet' : 'no_following_yet'), style: AppTheme.heading(context, size: 22)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        color: AppTheme.goldColor(context),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          itemCount: _users.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _users.length) {
                              return Padding(
                                padding: const EdgeInsets.all(24),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.goldColor(context),
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            return _buildUserTile(index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(int index) {
    final user = _users[index];
    final name = (user['name'] ?? 'Unknown') as String;
    final username = (user['username'] ?? '') as String;
    final avatar = (user['profile_image_url'] ?? user['profile_image']) as String?;
    final userId = (user['id'] ?? user['user_id']) as int?;
    final isFollowing = userId != null ? (_followStates[userId] ?? false) : false;
    final isMe = user['is_me'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.moodCardBg(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder(context)),
      ),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: isMe
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(user: user),
                      ),
                    ),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.goldColor(context).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: avatar != null && avatar.isNotEmpty
                    ? Image.network(
                        avatar.startsWith('http') ? avatar : '${ApiService.baseUrl}/$avatar',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        cacheWidth: 144,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: AppTheme.goldColor(context),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => _avatarFallback(name),
                      )
                    : _avatarFallback(name),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name & username
          Expanded(
            child: GestureDetector(
              onTap: isMe
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserProfileScreen(user: user),
                        ),
                      ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: GoogleFonts.jost(
                        color: AppTheme.textMuted(context),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Follow/Unfollow button
          if (!isMe && userId != null)
            GestureDetector(
              onTap: () => _toggleFollow(userId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isFollowing ? null : AppTheme.goldGradient2,
                  color: isFollowing ? AppTheme.glassBg(context) : null,
                  borderRadius: BorderRadius.circular(20),
                  border: isFollowing
                      ? Border.all(color: AppTheme.glassBorder(context))
                      : null,
                ),
                child: Text(
                  isFollowing ? 'Following' : 'Follow',
                  style: GoogleFonts.jost(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isFollowing
                        ? AppTheme.text2(context)
                        : const Color(0xFF1A1612),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: GoogleFonts.jost(
          color: AppTheme.goldColor(context),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
