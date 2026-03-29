import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import 'likes_list_sheet.dart';
import 'share_sheet.dart';
import 'threaded_comments_sheet.dart';
import 'user_profile_screen.dart';

/// TikTok / Instagram Reels style vertical feed for both images and videos.
class FeedReelsScreen extends StatefulWidget {
  /// List of all feed posts (images + videos).
  final List<Map<String, dynamic>> videoPosts;

  /// Index of the post the user tapped on in the feed.
  final int initialIndex;

  /// Whether to show the back arrow (false when used as a tab).
  final bool showBackButton;

  /// Extra bottom padding to account for bottom nav bar when used as a tab.
  final double bottomPadding;

  const FeedReelsScreen({
    super.key,
    required this.videoPosts,
    required this.initialIndex,
    this.showBackButton = true,
    this.bottomPadding = 0,
  });

  @override
  State<FeedReelsScreen> createState() => _FeedReelsScreenState();
}

class _FeedReelsScreenState extends State<FeedReelsScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<Map<String, dynamic>> _videoPosts;
  String? _nextCursor;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _videoPosts = List.from(widget.videoPosts);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // Immersive mode
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Start loading more posts from the API
    _loadMorePosts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Vertical swipeable video pages
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _videoPosts.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return _ReelVideoPage(
                post: _videoPosts[index],
                isActive: index == _currentIndex,
                onCommentTap: (onCommentAdded) => _showComments(_videoPosts[index], onCommentAdded),
                bottomPadding: widget.bottomPadding,
              );
            },
          ),

          // Top bar — back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 16,
            child: Row(
              children: [
                if (widget.showBackButton)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                const Spacer(),
                Text(
                  'Reels',
                  style: GoogleFonts.jost(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 40), // balance
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore) return;
    _isLoadingMore = true;

    final result = await PostService.getFeed(cursor: _nextCursor);
    if (!mounted) return;

    if (result.success) {
      _nextCursor = result.pagination?['next_cursor'] as String?;
      final newPosts = <Map<String, dynamic>>[];
      for (final p in result.posts) {
        if (p is Map<String, dynamic>) {
          // Only include posts with media (skip text-only)
          final media = p['media'] as List<dynamic>? ?? [];
          if (media.isEmpty) continue;
          // Avoid duplicates
          final exists = _videoPosts.any((vp) => vp['id'] == p['id']);
          if (!exists) newPosts.add(p);
        }
      }
      if (newPosts.isNotEmpty) {
        setState(() => _videoPosts.addAll(newPosts));
      }
    }
    _isLoadingMore = false;
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    // Load more when 2 posts away from the end
    if (index >= _videoPosts.length - 2 && _nextCursor != null) {
      _loadMorePosts();
    }
  }

  void _showComments(Map<String, dynamic> post, VoidCallback onCommentAdded) {
    final postId = post['id'] as int;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ThreadedCommentsSheet(
        postId: postId,
        darkMode: true,
        onCommentAdded: onCommentAdded,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Individual Reel Video Page
// ─────────────────────────────────────────────

class _ReelVideoPage extends StatefulWidget {
  final Map<String, dynamic> post;
  final bool isActive;
  final void Function(VoidCallback onCommentAdded) onCommentTap;
  final double bottomPadding;

  const _ReelVideoPage({
    required this.post,
    required this.isActive,
    required this.onCommentTap,
    this.bottomPadding = 0,
  });

  @override
  State<_ReelVideoPage> createState() => _ReelVideoPageState();
}

class _ReelVideoPageState extends State<_ReelVideoPage> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isPaused = false;
  bool _showPauseIcon = false;

  // Media type detection
  bool _isVideoPost = false;
  List<String> _imageUrls = [];

  // Reaction state
  bool _isLiked = false;
  int _likesCount = 0;
  int _commentsCount = 0;

  // Social state
  bool _isFollowing = false;
  bool _isSaved = false;
  int _viewsCount = 0;
  bool _viewRecorded = false;
  bool _isOwner = false;

  // Image page indicator
  int _currentImageIndex = 0;
  final PageController _imagePageController = PageController();

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post['user_reaction'] != null;
    _likesCount = widget.post['reactions_count'] as int? ?? 0;
    _commentsCount = widget.post['comments_count'] as int? ?? 0;
    _isFollowing = widget.post['is_following'] as bool? ?? false;
    _isSaved = widget.post['is_saved'] as bool? ?? false;
    _viewsCount = widget.post['views_count'] as int? ?? 0;
    _isOwner = widget.post['is_owner'] as bool? ?? false;
    _detectMediaType();
    if (_isVideoPost) {
      _initVideo();
    }
    if (widget.isActive) _recordView();
    if (!_isOwner) _checkFollowStatus();
    _loadCurrentUserId();
  }

  void _detectMediaType() {
    final media = widget.post['media'] as List<dynamic>? ?? [];
    _isVideoPost = false;
    _imageUrls = [];

    for (final item in media) {
      if (item is Map) {
        final type = (item['type'] ?? item['mime_type'] ?? item['file_type'] ?? 'image').toString();
        final url = (item['url'] ?? item['file_url'] ?? item['path'] ?? item['file_path'] ?? item['media_url'] ?? '').toString();
        final fullUrl = url.startsWith('http')
            ? url
            : '${ApiService.baseUrl}/${url.replaceAll(RegExp(r'^/'), '')}';

        if (type.contains('video')) {
          _isVideoPost = true;
        } else {
          _imageUrls.add(fullUrl);
        }
      }
    }
  }

  void _initVideo() {
    final videoUrl = _getVideoUrl(widget.post);
    if (videoUrl == null) return;

    _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller!.setLooping(true);
          if (widget.isActive) {
            _controller!.play();
          }
        }
      }).catchError((_) {
        if (mounted) setState(() => _hasError = true);
      });
  }

  String? _getVideoUrl(Map<String, dynamic> post) {
    final media = post['media'] as List<dynamic>? ?? [];
    for (final item in media) {
      if (item is Map) {
        final type = (item['type'] ?? item['mime_type'] ?? item['file_type'] ?? 'image').toString();
        if (type.contains('video')) {
          final url = (item['url'] ?? item['file_url'] ?? item['path'] ?? item['file_path'] ?? item['media_url'] ?? '').toString();
          return url.startsWith('http')
              ? url
              : '${ApiService.baseUrl}/${url.replaceAll(RegExp(r'^/'), '')}';
        }
      }
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant _ReelVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (_isVideoPost) {
          _controller?.play();
          _isPaused = false;
        }
        _recordView();
      } else {
        if (_isVideoPost) _controller?.pause();
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isVideoPost || _controller == null || !_initialized) return;

    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _isPaused = true;
        _showPauseIcon = true;
      } else {
        _controller!.play();
        _isPaused = false;
        _showPauseIcon = true;
      }
    });

    // Hide pause icon after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showPauseIcon = false);
    });
  }

  void _recordView() {
    if (_viewRecorded) return;
    _viewRecorded = true;
    final postId = widget.post['id'] as int;
    SocialService.recordView(postId);
  }

  Future<void> _loadCurrentUserId() async {
    final currentUser = await ApiService.getUser();
    if (!mounted || currentUser == null) return;
    final currentUserId = currentUser['id'] as int?;
    final user = widget.post['user'] as Map<String, dynamic>? ?? {};
    final postUserId = user['id'] as int?;
    if (currentUserId != null && currentUserId == postUserId) {
      setState(() => _isOwner = true);
    }
  }

  Future<void> _checkFollowStatus() async {
    final user = widget.post['user'] as Map<String, dynamic>? ?? {};
    final userId = user['id'] as int?;
    if (userId == null) return;

    final result = await SocialService.getFollowStatus(userId);
    if (mounted && result.success) {
      setState(() => _isFollowing = result.isFollowing);
    }
  }

  Future<void> _toggleFollow() async {
    final user = widget.post['user'] as Map<String, dynamic>? ?? {};
    final userId = user['id'] as int?;
    if (userId == null) return;

    final was = _isFollowing;
    setState(() => _isFollowing = !was);

    final result = await SocialService.toggleFollow(userId);
    if (mounted && result.success) {
      setState(() => _isFollowing = result.isFollowing);
    } else if (mounted) {
      setState(() => _isFollowing = was);
    }
  }

  Future<void> _toggleSave() async {
    final postId = widget.post['id'] as int;
    final was = _isSaved;
    setState(() => _isSaved = !was);

    final result = await SocialService.toggleSave(postId);
    if (mounted && result.success) {
      setState(() => _isSaved = result.isSaved);
    } else if (mounted) {
      setState(() => _isSaved = was);
    }
  }

  Future<void> _toggleLike() async {
    final postId = widget.post['id'] as int;

    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount = (_likesCount - 1).clamp(0, 999999);
      } else {
        _isLiked = true;
        _likesCount += 1;
      }
    });

    await PostService.toggleReaction(postId, 'like');
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.post['user'] as Map<String, dynamic>? ?? {};
    final userName = user['name'] as String? ?? 'Anonymous';
    final userAvatar = (user['profile_image_url'] ?? user['profile_image']) as String?;
    final content = widget.post['content'] as String? ?? '';

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Media (video or image) ──
          _buildMedia(),

          // ── Gradient overlays for readability ──
          // Bottom gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 300,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black87,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Top gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black54,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Play/Pause icon overlay (video only) ──
          if (_isVideoPost && _showPauseIcon)
            Center(
              child: AnimatedOpacity(
                opacity: _showPauseIcon ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

          // ── Right side action buttons (TikTok style) ──
          Positioned(
            right: 12,
            bottom: 120 + widget.bottomPadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile avatar
                _buildProfileAvatar(userAvatar, userName),
                const SizedBox(height: 24),

                // Like button — icon toggles like, count opens likes list
                GestureDetector(
                  onTap: _toggleLike,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 32,
                        color: _isLiked ? Colors.redAccent : Colors.white,
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: _likesCount > 0
                            ? () => LikesListSheet.show(
                                  context,
                                  widget.post['id'] as int,
                                  darkMode: true,
                                )
                            : null,
                        child: Text(
                          _formatCount(_likesCount),
                          style: GoogleFonts.jost(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Comment button
                _buildActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: _formatCount(_commentsCount),
                  color: Colors.white,
                  onTap: () => widget.onCommentTap(() {
                    if (mounted) setState(() => _commentsCount += 1);
                  }),
                ),
                const SizedBox(height: 20),

                // Save/Bookmark button
                _buildActionButton(
                  icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  label: _isSaved ? 'Saved' : 'Save',
                  color: _isSaved ? AppTheme.gold1 : Colors.white,
                  onTap: _toggleSave,
                ),
                const SizedBox(height: 20),

                // Share button
                _buildActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  color: Colors.white,
                  onTap: () => ShareSheet.show(
                    context,
                    widget.post['id'] as int,
                    darkMode: true,
                  ),
                ),

                // Views count
                if (_viewsCount > 0) ...[
                  const SizedBox(height: 20),
                  _buildActionButton(
                    icon: Icons.visibility_outlined,
                    label: _formatCount(_viewsCount),
                    color: Colors.white,
                    onTap: () {},
                  ),
                ],
              ],
            ),
          ),

          // ── Bottom user info & caption ──
          Positioned(
            left: 16,
            right: 80,
            bottom: 40 + widget.bottomPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Username
                GestureDetector(
                  onTap: _isOwner
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(user: user),
                            ),
                          ),
                  child: Row(
                    children: [
                      Text(
                        '@$userName',
                        style: GoogleFonts.jost(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jost(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Video progress bar at very bottom (only for video posts) ──
          if (_isVideoPost && _initialized && _controller != null)
            Positioned(
              bottom: widget.bottomPadding,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                _controller!,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: VideoProgressColors(
                  playedColor: AppTheme.gold1,
                  bufferedColor: Colors.white24,
                  backgroundColor: Colors.white12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    // ── Image post ──
    if (!_isVideoPost) {
      if (_imageUrls.isEmpty) {
        return const Center(
          child: Icon(Icons.image_not_supported, size: 48, color: Colors.white70),
        );
      }

      if (_imageUrls.length == 1) {
        return SizedBox.expand(
          child: Image.network(
            _imageUrls[0],
            fit: BoxFit.contain,
            cacheWidth: 1080,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.gold1,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, size: 48, color: Colors.white70),
            ),
          ),
        );
      }

      // Multiple images — swipeable
      return Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _imagePageController,
            itemCount: _imageUrls.length,
            onPageChanged: (i) => setState(() => _currentImageIndex = i),
            itemBuilder: (_, i) => Image.network(
              _imageUrls[i],
              fit: BoxFit.contain,
              cacheWidth: 1080,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.gold1,
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, size: 48, color: Colors.white70),
              ),
            ),
          ),
          // Page indicator dots
          Positioned(
            bottom: 100,
            left: 0,
            right: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_imageUrls.length, (i) {
                return Container(
                  width: _currentImageIndex == i ? 8 : 6,
                  height: _currentImageIndex == i ? 8 : 6,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == i
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                );
              }),
            ),
          ),
        ],
      );
    }

    // ── Video post ──
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.white70),
            SizedBox(height: 12),
            Text(
              'Failed to load video',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (!_initialized || _controller == null) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.gold1,
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.size.width == 0 ? 360 : _controller!.value.size.width,
          height: _controller!.value.size.height == 0 ? 640 : _controller!.value.size.height,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(String? avatarUrl, String name) {
    final user = widget.post['user'] as Map<String, dynamic>? ?? {};
    return GestureDetector(
      onTap: _isOwner
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserProfileScreen(user: user),
                ),
              ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _isFollowing ? AppTheme.gold1 : Colors.white,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl.startsWith('http')
                          ? avatarUrl
                          : '${ApiService.baseUrl}/$avatarUrl',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      cacheWidth: 144,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey[800],
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Container(
                        width: 48,
                        height: 48,
                        color: Colors.grey[800],
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: GoogleFonts.jost(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: Colors.grey[800],
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: GoogleFonts.jost(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
            ),
          ),
          // Follow/Following icon at bottom of avatar (hide for own posts)
          if (!_isOwner)
            Positioned(
              bottom: -6,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: _isFollowing ? Colors.grey[700] : AppTheme.gold1,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1.5),
                ),
                child: Icon(
                  _isFollowing ? Icons.check : Icons.add,
                  size: 14,
                  color: _isFollowing ? Colors.white : Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }


  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.jost(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}

