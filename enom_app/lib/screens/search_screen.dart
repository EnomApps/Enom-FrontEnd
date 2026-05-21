import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';
import 'feed_reels_screen.dart';
import 'user_profile_screen.dart';

/// Search & Explore screen with users, posts, hashtags.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  Timer? _debounce;

  // State
  bool _isSearching = false;
  bool _hasSearched = false;

  // Results
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _hashtags = [];

  // Trending
  List<Map<String, dynamic>> _trending = [];
  bool _loadingTrending = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadTrending();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    final tags = await SearchService.getTrendingHashtags(limit: 20);
    if (mounted) {
      setState(() {
        _trending = tags;
        _loadingTrending = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _hasSearched = false;
        _users = [];
        _posts = [];
        _hashtags = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);

    final result = await SearchService.search(query);

    if (mounted) {
      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _users = result.users;
        _posts = result.posts;
        _hashtags = result.hashtags;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final goldC = AppTheme.goldColor(context);

    return Stack(
      children: [
        const EnomScreenBackground(gradientVariant: 2, particleCount: 25),
        SafeArea(
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.moodCardBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.glassBorder(context)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 14,
                    ),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.translate('search_hint'),
                      hintStyle: GoogleFonts.jost(
                        color: AppTheme.textMuted(context),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(Icons.search,
                          color: AppTheme.textMuted(context), size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close,
                                  color: AppTheme.textMuted(context), size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (q) {
                      if (q.trim().isNotEmpty) _performSearch(q.trim());
                    },
                  ),
                ),
              ),

              // Tab bar (when searching)
              if (_hasSearched) ...[
                const SizedBox(height: 8),
                TabBar(
                  controller: _tabController,
                  indicatorColor: goldC,
                  indicatorWeight: 2,
                  labelColor: goldC,
                  unselectedLabelColor: AppTheme.textMuted(context),
                  labelStyle: GoogleFonts.jost(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.jost(fontSize: 13),
                  dividerHeight: 0.5,
                  dividerColor: AppTheme.glassBorder(context),
                  tabs: [
                    Tab(text: '${l10n.translate('users')} (${_users.length})'),
                    Tab(text: '${l10n.translate('posts')} (${_posts.length})'),
                    Tab(text: '${l10n.translate('hashtags_tab')} (${_hashtags.length})'),
                  ],
                ),
              ],

              // Content
              Expanded(
                child: _isSearching
                    ? Center(
                        child: CircularProgressIndicator(
                            color: goldC, strokeWidth: 2))
                    : _hasSearched
                        ? _buildSearchResults(l10n)
                        : _buildTrendingView(l10n),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Trending View (default) ──

  Widget _buildTrendingView(AppLocalizations l10n) {
    if (_loadingTrending) {
      return Center(
        child: CircularProgressIndicator(
            color: AppTheme.goldColor(context), strokeWidth: 2),
      );
    }

    if (_trending.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined,
                size: 48,
                color: AppTheme.textMuted(context).withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              l10n.translate('search_and_explore'),
              style: GoogleFonts.jost(
                color: AppTheme.textMuted(context),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.translate('search_hint'),
              style: GoogleFonts.jost(
                color: AppTheme.textMuted(context).withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
      children: [
        Text(
          l10n.translate('trending').toUpperCase(),
          style: AppTheme.label(context, size: 10),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _trending.map((tag) {
            final name = tag['name'] as String? ??
                tag['hashtag'] as String? ??
                tag['tag'] as String? ??
                '';
            final count = tag['posts_count'] as int? ??
                tag['count'] as int? ?? 0;
            return GestureDetector(
              onTap: () {
                _searchController.text = '#$name';
                _performSearch('#$name');
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.goldColor(context).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color:
                        AppTheme.goldColor(context).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#$name',
                      style: GoogleFonts.jost(
                        color: AppTheme.goldColor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        _formatCount(count),
                        style: GoogleFonts.jost(
                          color: AppTheme.textMuted(context),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Search Results ──

  Widget _buildSearchResults(AppLocalizations l10n) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildUsersList(l10n),
        _buildPostsList(l10n),
        _buildHashtagsList(l10n),
      ],
    );
  }

  Widget _buildUsersList(AppLocalizations l10n) {
    if (_users.isEmpty) return _buildEmptyState(l10n, Icons.person_search);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: _users.length,
      itemBuilder: (_, i) {
        final user = _users[i];
        final name = user['name'] as String? ?? '';
        final username = user['username'] as String? ?? '';
        final avatar =
            (user['profile_image_url'] ?? user['profile_image']) as String?;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => UserProfileScreen(user: user)),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.moodCardBg(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.glassBorder(context)),
            ),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.glassBg(context),
                  backgroundImage: avatar != null && avatar.isNotEmpty
                      ? NetworkImage(avatar.startsWith('http')
                          ? avatar
                          : '${ApiService.baseUrl}/$avatar')
                      : null,
                  child: avatar == null || avatar.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: GoogleFonts.jost(
                            color: AppTheme.goldColor(context),
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Name + username
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.jost(
                          color: AppTheme.text1(context),
                          fontSize: 14,
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
                Icon(Icons.chevron_right,
                    color: AppTheme.textMuted(context), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostsList(AppLocalizations l10n) {
    if (_posts.isEmpty) return _buildEmptyState(l10n, Icons.article_outlined);

    // Show as grid for posts with media, list for text-only
    final mediaPosts = _posts.where((p) {
      final media = p['media'] as List<dynamic>? ?? [];
      return media.isNotEmpty;
    }).toList();

    if (mediaPosts.isNotEmpty) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 90),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: _posts.length,
        itemBuilder: (_, i) {
          final post = _posts[i];
          final media = post['media'] as List<dynamic>? ?? [];
          final content = post['content'] as String? ?? '';

          if (media.isNotEmpty) {
            // Media thumbnail grid tile
            final firstMedia = media[0] as Map<String, dynamic>? ?? {};
            final url = firstMedia['url'] as String? ??
                firstMedia['thumbnail_url'] as String? ?? '';
            final isVideo = (firstMedia['type'] as String? ?? '').contains('video');
            final fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}/$url';

            return GestureDetector(
              onTap: () => _openPostInReels(_posts, i),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    fullUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.glassBg(context),
                      child: Icon(Icons.image, color: AppTheme.textMuted(context)),
                    ),
                  ),
                  if (isVideo)
                    Positioned(
                      top: 6, right: 6,
                      child: Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                    ),
                  if (media.length > 1)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${media.length}',
                          style: GoogleFonts.jost(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ),
                ],
              ),
            );
          }

          // Text-only post
          return GestureDetector(
            onTap: () => _openPostInReels(_posts, i),
            child: Container(
              padding: const EdgeInsets.all(8),
              color: AppTheme.moodCardBg(context),
              child: Center(
                child: Text(
                  content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jost(
                    color: AppTheme.text2(context), fontSize: 11, height: 1.3,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    // All text-only posts — show as list
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: _posts.length,
      itemBuilder: (_, i) {
        final post = _posts[i];
        final user = post['user'] as Map<String, dynamic>? ?? {};
        final userName = user['name'] as String? ?? '';
        final content = post['content'] as String? ?? '';

        return GestureDetector(
          onTap: () => _openPostInReels(_posts, i),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.moodCardBg(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.glassBorder(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: GoogleFonts.jost(
                  color: AppTheme.text1(context), fontSize: 13, fontWeight: FontWeight.w600)),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(content, maxLines: 3, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jost(color: AppTheme.text2(context), fontSize: 13, height: 1.4)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _openPostInReels(List<Map<String, dynamic>> posts, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedReelsScreen(
          videoPosts: posts,
          initialIndex: index,
          showBackButton: true,
        ),
      ),
    );
  }

  Widget _buildHashtagsList(AppLocalizations l10n) {
    if (_hashtags.isEmpty) return _buildEmptyState(l10n, Icons.tag);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: _hashtags.length,
      itemBuilder: (_, i) {
        final tag = _hashtags[i];
        final name = tag['name'] as String? ??
            tag['hashtag'] as String? ??
            tag['tag'] as String? ?? '';
        final count =
            tag['posts_count'] as int? ?? tag['count'] as int? ?? 0;

        return GestureDetector(
          onTap: () => _openHashtagPosts(name),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.moodCardBg(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.glassBorder(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '#',
                      style: GoogleFonts.jost(
                        color: AppTheme.goldColor(context),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '#$name',
                        style: GoogleFonts.jost(
                          color: AppTheme.text1(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (count > 0)
                        Text(
                          '${_formatCount(count)} ${l10n.translate('posts').toLowerCase()}',
                          style: GoogleFonts.jost(
                            color: AppTheme.textMuted(context),
                            fontSize: 12,
                          ),
                        ),
                    ],
                ),
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Future<void> _openHashtagPosts(String hashtagName) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(color: AppTheme.goldColor(context)),
      ),
    );

    final result = await SearchService.getHashtagPosts(hashtagName);
    if (mounted) Navigator.pop(context); // close loading

    if (result.success && result.posts.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FeedReelsScreen(
            videoPosts: result.posts,
            initialIndex: 0,
            showBackButton: true,
          ),
        ),
      );
    } else if (mounted) {
      AppTheme.showSnackBar(context, AppLocalizations.of(context)!.translate('no_results'));
    }
  }

  Widget _buildEmptyState(AppLocalizations l10n, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40,
              color: AppTheme.textMuted(context).withValues(alpha: 0.3)),
          const SizedBox(height: 10),
          Text(
            l10n.translate('no_results'),
            style: GoogleFonts.jost(
              color: AppTheme.textMuted(context),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }
}
