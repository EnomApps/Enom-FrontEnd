import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import 'feed_reels_screen.dart';
import 'feed_screen.dart';
import 'likes_list_sheet.dart';

/// Public profile screen for viewing another user's profile.
class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const UserProfileScreen({super.key, required this.user});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Map<String, dynamic> _user;
  bool _isFollowing = false;
  bool _followLoading = false;

  // User's posts
  final List<Map<String, dynamic>> _posts = [];
  final ScrollController _scrollController = ScrollController();
  String? _nextCursor;
  bool _isLoading = false;
  bool _isLoadingMore = false;

  int get _userId => (_user['id'] ?? _user['user_id']) as int;

  @override
  void initState() {
    super.initState();
    _user = Map.from(widget.user);
    _isFollowing = _user['is_following'] as bool? ?? false;
    _loadPosts();
    _checkFollowStatus();
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

  Future<void> _checkFollowStatus() async {
    final result = await SocialService.getFollowStatus(_userId);
    if (mounted && result.success) {
      setState(() => _isFollowing = result.isFollowing);
    }
  }

  Future<void> _toggleFollow() async {
    setState(() => _followLoading = true);
    final was = _isFollowing;
    setState(() => _isFollowing = !was);

    final result = await SocialService.toggleFollow(_userId);
    if (mounted) {
      setState(() {
        _isFollowing = result.success ? result.isFollowing : was;
        _followLoading = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);

    final result = await PostService.getFeed(userId: _userId);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _posts.clear();
        for (final p in result.posts) {
          if (p is Map<String, dynamic>) _posts.add(p);
        }
        _nextCursor = result.pagination?['next_cursor'] as String?;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextCursor == null) return;
    setState(() => _isLoadingMore = true);

    final result = await PostService.getFeed(cursor: _nextCursor, userId: _userId);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        for (final p in result.posts) {
          if (p is Map<String, dynamic>) _posts.add(p);
        }
        _nextCursor = result.pagination?['next_cursor'] as String?;
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _user['name'] as String? ?? 'Unknown';
    final username = _user['username'] as String? ?? '';
    final avatar = (_user['profile_image_url'] ?? _user['profile_image']) as String?;
    final bio = _user['bio'] as String? ?? '';
    final followersCount = _user['followers_count'] as int? ?? 0;
    final followingCount = _user['following_count'] as int? ?? 0;
    final postsCount = _user['posts_count'] as int? ?? _posts.length;

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
        title: Text(name, style: AppTheme.label(context, size: 12)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const EnomScreenBackground(gradientVariant: 2, particleCount: 30),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadPosts,
              color: AppTheme.goldColor(context),
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // Profile header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Column(
                        children: [
                          // Avatar
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.goldColor(context).withValues(alpha: 0.5),
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: avatar != null && avatar.isNotEmpty
                                  ? Image.network(
                                      avatar.startsWith('http') ? avatar : '${ApiService.baseUrl}/$avatar',
                                      width: 80, height: 80, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _avatarFallback(name, 28),
                                    )
                                  : _avatarFallback(name, 28),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(name, style: AppTheme.heading(context, size: 20)),
                          if (username.isNotEmpty)
                            Text('@$username', style: GoogleFonts.jost(
                              color: AppTheme.goldColor(context),
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                            )),
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(bio, textAlign: TextAlign.center, style: GoogleFonts.jost(
                              color: AppTheme.text2(context),
                              fontSize: 13,
                              height: 1.4,
                            )),
                          ],
                          const SizedBox(height: 16),

                          // Stats row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStat('$postsCount', 'Posts'),
                              Container(width: 1, height: 28, color: AppTheme.glassBorder(context)),
                              _buildStat('$followersCount', 'Followers'),
                              Container(width: 1, height: 28, color: AppTheme.glassBorder(context)),
                              _buildStat('$followingCount', 'Following'),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Follow button
                          GestureDetector(
                            onTap: _followLoading ? null : _toggleFollow,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: _isFollowing ? null : AppTheme.goldGradient2,
                                color: _isFollowing ? AppTheme.glassBg(context) : null,
                                borderRadius: BorderRadius.circular(20),
                                border: _isFollowing ? Border.all(color: AppTheme.glassBorder(context)) : null,
                              ),
                              child: Center(
                                child: _followLoading
                                    ? SizedBox(
                                        width: 18, height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _isFollowing ? AppTheme.goldColor(context) : const Color(0xFF1A1612),
                                        ),
                                      )
                                    : Text(
                                        _isFollowing ? 'Following' : 'Follow',
                                        style: GoogleFonts.jost(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _isFollowing ? AppTheme.text2(context) : const Color(0xFF1A1612),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AppTheme.goldDivider(context),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text('POSTS', style: AppTheme.label(context, size: 10)),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),

                  // Posts
                  if (_isLoading)
                    SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator(color: AppTheme.goldColor(context))),
                    )
                  else if (_posts.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.dynamic_feed_outlined, size: 48, color: AppTheme.goldColor(context).withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('No posts yet', style: AppTheme.body(context, size: 15)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == _posts.length) {
                            return Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator(color: AppTheme.goldColor(context), strokeWidth: 2)),
                            );
                          }
                          return _buildPostCard(_posts[index]);
                        },
                        childCount: _posts.length + (_isLoadingMore ? 1 : 0),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Text(value, style: AppTheme.heading(context, size: 16)),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.label(context)),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final content = post['content'] as String? ?? '';
    final media = post['media'] as List<dynamic>? ?? [];
    final reactionsCount = post['reactions_count'] as int? ?? 0;
    final commentsCount = post['comments_count'] as int? ?? 0;
    final viewsCount = post['views_count'] as int? ?? 0;
    final createdAt = post['created_at'] as String? ?? '';

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
      onTap: () => _openPostDetail(post),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppTheme.isDark(context) ? const Color(0xFF1A1610) : const Color(0xFFFFFCF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.glassBorder(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (timeAgo.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(timeAgo, style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 11)),
                ),
              if (content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(content, style: GoogleFonts.jost(color: AppTheme.text1(context), fontSize: 14, height: 1.5)),
                ),
              if (media.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildMediaGrid(media),
              ],
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

  void _openPostDetail(Map<String, dynamic> post) {
    final media = post['media'] as List<dynamic>? ?? [];
    final hasVideo = media.any((item) {
      if (item is Map) {
        final type = (item['type'] ?? item['mime_type'] ?? item['file_type'] ?? 'image').toString();
        return type.contains('video');
      }
      return false;
    });

    if (hasVideo) {
      final videoPosts = _posts.where((p) {
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
      final imageUrls = media
          .where((item) {
            if (item is Map) {
              final type = (item['type'] ?? item['mime_type'] ?? 'image').toString();
              return !type.contains('video');
            }
            return true;
          })
          .map((item) {
            final url = (item is Map
                ? (item['url'] ?? item['file_url'] ?? item['path'] ?? item['media_url'] ?? '')
                : item).toString();
            return url.startsWith('http') ? url : '${ApiService.baseUrl}/${url.replaceAll(RegExp(r'^/'), '')}';
          })
          .toList();
      if (imageUrls.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullImageScreen(urls: imageUrls),
          ),
        );
      }
    }
  }

  Widget _buildMediaGrid(List<dynamic> media) {
    if (media.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildMediaItem(media[0]),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: media.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildMediaItem(media[i]),
        ),
      ),
    );
  }

  Widget _buildMediaItem(dynamic item) {
    String url = '';
    String type = 'image';
    if (item is Map) {
      url = (item['url'] ?? item['file_url'] ?? item['path'] ?? item['media_url'] ?? '').toString();
      type = (item['type'] ?? item['mime_type'] ?? 'image').toString();
    }
    final fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}/${url.replaceAll(RegExp(r'^/'), '')}';

    if (type.contains('video')) {
      // Use thumbnail_url from API if available
      String? thumbUrl;
      if (item is Map && item['thumbnail_url'] != null && (item['thumbnail_url'] as String).isNotEmpty) {
        final thumb = item['thumbnail_url'] as String;
        thumbUrl = thumb.startsWith('http') ? thumb : '${ApiService.baseUrl}/${thumb.replaceAll(RegExp(r'^/'), '')}';
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumbUrl != null)
            Image.network(
              thumbUrl,
              width: 240,
              height: 200,
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, __, ___) => Container(
                width: 240, height: 200,
                color: Colors.black,
                child: const Center(child: Icon(Icons.play_circle_outline, size: 48, color: Colors.white54)),
              ),
            )
          else
            Container(
              width: 240,
              height: 200,
              color: Colors.black,
            ),
          const Center(child: Icon(Icons.play_circle_fill, size: 40, color: Colors.white70)),
        ],
      );
    }

    return Image.network(
      fullUrl,
      width: 240,
      height: 200,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        width: 240, height: 200,
        color: AppTheme.glassBg(context),
        child: Icon(Icons.broken_image_outlined, color: AppTheme.textMuted(context)),
      ),
    );
  }

  Widget _avatarFallback(String name, double fontSize) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: GoogleFonts.jost(color: AppTheme.goldColor(context), fontSize: fontSize, fontWeight: FontWeight.w500),
      ),
    );
  }
}
