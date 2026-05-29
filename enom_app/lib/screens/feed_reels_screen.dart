import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import '../widgets/double_tap_heart.dart';
import '../widgets/pinch_to_zoom.dart';
import 'likes_list_sheet.dart';
import 'share_sheet.dart';
import 'threaded_comments_sheet.dart';
import 'user_profile_screen.dart';
import 'video_actions_sheet.dart';

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
  // ignore: unused_field — held so the platform channel listener stays alive
  late final SimplePip _pip;

  @override
  void initState() {
    super.initState();
    _videoPosts = List.from(widget.videoPosts);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    // PiP lifecycle: keep the shared notifier in sync so reels overlays hide
    // (and the activity header) while in Picture-in-Picture. Holding a
    // reference keeps the channel listener alive for this screen.
    _pip = SimplePip(
      onPipEntered: () => VideoActionsSheet.pipActive.value = true,
      onPipExited: () => VideoActionsSheet.pipActive.value = false,
    );

    // Keep the screen awake while reels is open — users shouldn't get a
    // dark-screen timeout mid-video. Released in dispose.
    WakelockPlus.enable();

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
    WakelockPlus.disable();
    // Failsafe in case we leave reels while still in PiP.
    VideoActionsSheet.pipActive.value = false;
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  void _advanceToNext() {
    final next = _currentIndex + 1;
    if (next >= _videoPosts.length) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fixed 100px bottom margin for the reels area (per user request).
    const effectiveBottomPadding = 100.0;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Vertical swipeable video pages — disable scroll while pinching
          // so the gesture arena doesn't steal the 2-finger zoom.
          ValueListenableBuilder<bool>(
            valueListenable: PinchToZoom.isPinching,
            builder: (_, pinching, __) => PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              physics: pinching ? const NeverScrollableScrollPhysics() : null,
              itemCount: _videoPosts.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return _ReelVideoPage(
                  post: _videoPosts[index],
                  isActive: index == _currentIndex,
                  onCommentTap: (onCommentAdded) => _showComments(_videoPosts[index], onCommentAdded),
                  onNotInterested: () => _removePost(_videoPosts[index]),
                  onVideoEnded: _advanceToNext,
                  bottomPadding: effectiveBottomPadding,
                );
              },
            ),
          ),

          // Top bar — back button. Hidden in PiP so the floating window shows
          // only the video.
          ValueListenableBuilder<bool>(
            valueListenable: VideoActionsSheet.pipActive,
            builder: (_, pip, __) {
              final s = MediaQuery.of(context).size;
              final small = s.width < 320 || s.height < 320;
              if (pip || small) return const SizedBox.shrink();
              return Positioned(
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
              );
            },
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

  void _removePost(Map<String, dynamic> post) {
    setState(() {
      _videoPosts.remove(post);
      if (_currentIndex >= _videoPosts.length) {
        _currentIndex = (_videoPosts.length - 1).clamp(0, 1 << 30);
      }
    });
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
  final VoidCallback onNotInterested;
  final VoidCallback onVideoEnded;
  final double bottomPadding;

  const _ReelVideoPage({
    required this.post,
    required this.isActive,
    required this.onCommentTap,
    required this.onNotInterested,
    required this.onVideoEnded,
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

  // Ordered list of media items in the post (videos + images).
  List<({String url, bool isVideo})> _mediaItems = [];

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

  // Inner media page (horizontal swipe across this post's media).
  int _currentMediaIndex = 0;
  final PageController _mediaPageController = PageController();

  // Long-press menu state
  double _playbackSpeed = 1.0;
  bool _clearMode = false;
  bool _endHandled = false;

  void _onControllerTick() {
    final c = _controller;
    if (c == null || !_initialized || !widget.isActive || _endHandled) return;
    if (!VideoActionsSheet.autoScrollEnabled.value) return;
    final v = c.value;
    if (v.duration <= Duration.zero) return;
    if (v.position >= v.duration - const Duration(milliseconds: 120)) {
      _endHandled = true;
      widget.onVideoEnded();
    }
  }

  bool get _isCurrentVideo =>
      _mediaItems.isNotEmpty &&
      _currentMediaIndex < _mediaItems.length &&
      _mediaItems[_currentMediaIndex].isVideo;

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
    if (_isCurrentVideo) {
      _initVideoFor(_mediaItems[_currentMediaIndex].url);
    }
    if (widget.isActive) _recordView();
    if (!_isOwner) _checkFollowStatus();
    _loadCurrentUserId();
    // Flip looping live when the user toggles auto-scroll in the menu.
    VideoActionsSheet.autoScrollEnabled.addListener(_onAutoScrollChanged);
  }

  void _onAutoScrollChanged() {
    final c = _controller;
    if (c == null || !_initialized) return;
    c.setLooping(!VideoActionsSheet.autoScrollEnabled.value);
    _endHandled = false;
  }

  void _detectMediaType() {
    final media = widget.post['media'] as List<dynamic>? ?? [];
    _mediaItems = [];

    for (final item in media) {
      if (item is Map) {
        final type = (item['type'] ?? item['mime_type'] ?? item['file_type'] ?? 'image').toString();
        final url = (item['url'] ?? item['file_url'] ?? item['path'] ?? item['file_path'] ?? item['media_url'] ?? '').toString();
        final fullUrl = url.startsWith('http')
            ? url
            : '${ApiService.baseUrl}/${url.replaceAll(RegExp(r'^/'), '')}';
        _mediaItems.add((url: fullUrl, isVideo: type.contains('video')));
      }
    }
  }

  void _initVideoFor(String videoUrl) {
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _controller = controller;
    _initialized = false;
    _hasError = false;
    _endHandled = false;
    controller.addListener(_onControllerTick);
    controller.initialize().then((_) {
      // If dispose ran (or the user swiped to another inner page) before init
      // completed, _controller no longer points at us — dispose the orphan.
      if (!mounted || _controller != controller) {
        controller.dispose();
        return;
      }
      setState(() => _initialized = true);
      // Loop unless auto-scroll is on — then play once and advance on end.
      controller.setLooping(!VideoActionsSheet.autoScrollEnabled.value);
      if (widget.isActive) {
        controller.play();
      }
    }).catchError((_) {
      if (mounted && _controller == controller) {
        setState(() => _hasError = true);
      }
    });
  }

  void _onInnerPageChanged(int index) {
    final old = _controller;
    setState(() {
      _currentMediaIndex = index;
      _controller = null;
      _initialized = false;
      _hasError = false;
      _isPaused = false;
      _showPauseIcon = false;
    });
    old?.removeListener(_onControllerTick);
    old?.dispose();
    if (_isCurrentVideo) {
      _initVideoFor(_mediaItems[_currentMediaIndex].url);
    }
  }

  @override
  void didUpdateWidget(covariant _ReelVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (_isCurrentVideo) {
          _controller?.play();
          _isPaused = false;
        }
        _recordView();
      } else {
        if (_isCurrentVideo) _controller?.pause();
      }
    }
  }

  @override
  void dispose() {
    VideoActionsSheet.autoScrollEnabled.removeListener(_onAutoScrollChanged);
    // Null out the field BEFORE disposing so any in-flight `initialize().then`
    // callback sees `_controller != controller` and bails out.
    final c = _controller;
    _controller = null;
    c?.removeListener(_onControllerTick);
    c?.dispose();
    _mediaPageController.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (!_isCurrentVideo || _controller == null || !_initialized) return;

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
    widget.post['is_following'] = !was;

    final result = await SocialService.toggleFollow(userId);
    if (mounted && result.success) {
      setState(() => _isFollowing = result.isFollowing);
      widget.post['is_following'] = result.isFollowing;
    } else if (mounted) {
      setState(() => _isFollowing = was);
      widget.post['is_following'] = was;
    }
  }

  Future<void> _toggleSave() async {
    final postId = widget.post['id'] as int;
    final was = _isSaved;
    setState(() => _isSaved = !was);
    widget.post['is_saved'] = !was;

    final result = await SocialService.toggleSave(postId);
    if (mounted && result.success) {
      setState(() => _isSaved = result.isSaved);
      widget.post['is_saved'] = result.isSaved;
    } else if (mounted) {
      setState(() => _isSaved = was);
      widget.post['is_saved'] = was;
    }
  }

  Future<void> _toggleLike() async {
    final postId = widget.post['id'] as int;

    // Save previous state for rollback
    final wasLiked = _isLiked;
    final prevCount = _likesCount;
    final prevReaction = widget.post['user_reaction'];

    setState(() {
      if (_isLiked) {
        _isLiked = false;
        _likesCount = (_likesCount - 1).clamp(0, 999999);
      } else {
        _isLiked = true;
        _likesCount += 1;
      }
    });
    // Mirror into the post Map so the upstream screen (feed/profile) shows
    // the updated state when the reels route pops.
    widget.post['user_reaction'] = _isLiked ? 'like' : null;
    widget.post['reactions_count'] = _likesCount;

    final result = await PostService.toggleReaction(postId, 'like');
    if (!result.success && mounted) {
      // Revert on failure
      setState(() {
        _isLiked = wasLiked;
        _likesCount = prevCount;
      });
      widget.post['user_reaction'] = prevReaction;
      widget.post['reactions_count'] = prevCount;
      debugPrint('[Reels] toggleReaction FAILED for postId=$postId: ${result.message}');
    }
  }

  void _showActionsSheet() {
    if (!_isCurrentVideo) return;
    final url = _mediaItems[_currentMediaIndex].url;
    VideoActionsSheet.show(
      context,
      postId: widget.post['id'] as int,
      videoUrl: url,
      controller: _controller,
      currentSpeed: _playbackSpeed,
      clearMode: _clearMode,
      onSpeedChanged: (s) {
        if (mounted) setState(() => _playbackSpeed = s);
      },
      onClearModeToggled: () {
        if (mounted) setState(() => _clearMode = !_clearMode);
      },
      onNotInterested: widget.onNotInterested,
    );
  }

  /// Instagram-style double-tap: only ever LIKES; never un-likes.
  /// The heart animation always plays (handled by [DoubleTapHeart]).
  void _doubleTapLike() {
    if (!_isLiked) _toggleLike();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.post['user'] as Map<String, dynamic>? ?? {};
    final userName = user['name'] as String? ?? 'Anonymous';
    final userAvatar = (user['profile_image_url'] ?? user['profile_image']) as String?;
    final content = widget.post['content'] as String? ?? '';

    // Reserve room at the bottom for the home-screen bottom-nav so video,
    // username row, right-rail icons, and progress bar all sit cleanly
    // above it. In route mode (no nav) bottomPadding is 0 → no effect.
    final mqSize = MediaQuery.of(context).size;
    // PiP windows on Android are tiny; treat any viewport <320 in either
    // dimension as PiP-equivalent so we hide overlays during the resize
    // transition (before the platform callback fires).
    final smallViewport = mqSize.width < 320 || mqSize.height < 320;
    return ValueListenableBuilder<bool>(
      valueListenable: VideoActionsSheet.pipActive,
      builder: (_, pip, __) {
        final hideUi = _clearMode || pip || smallViewport;
        // In PiP, drop the bottom nav-bar reservation so the video fills the
        // whole floating window.
        final bottomPad = hideUi ? 0.0 : widget.bottomPadding;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomPad),
          child: DoubleTapHeart(
      onTap: _togglePlayPause,
      onDoubleTap: _doubleTapLike,
      onLongPress: _showActionsSheet,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Media (video or image) ──
          _buildMedia(),

          // ── Gradient overlays for readability ──
          if (!hideUi) ...[
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

            // Top gradient — minimal to maximize reel visibility
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 60,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black38,
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],

          // ── Play/Pause icon overlay (video only) ──
          if (_isCurrentVideo && _showPauseIcon)
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

          // ── Right side action buttons (compact, TikTok/Reels style) ──
          if (!hideUi)
          Positioned(
            right: 10,
            bottom: 80,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Profile avatar
                _buildProfileAvatar(userAvatar, userName),
                const SizedBox(height: 18),

                // Like — heart toggles reaction, count opens the
                // Likes-and-plays sheet.
                _buildLikeAction(),
                const SizedBox(height: 14),

                // Comment
                _buildCompactAction(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: _commentsCount > 0 ? _formatCount(_commentsCount) : '',
                  color: Colors.white,
                  onTap: () => widget.onCommentTap(() {
                    if (mounted) {
                      setState(() => _commentsCount += 1);
                      widget.post['comments_count'] = _commentsCount;
                    }
                  }),
                ),
                const SizedBox(height: 14),

                // Messaging
                _buildCompactAction(
                  icon: Icons.send_outlined,
                  label: '',
                  color: Colors.white,
                  onTap: () {},
                ),
                const SizedBox(height: 14),

                // Save/Bookmark
                _buildCompactAction(
                  icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
                  label: '',
                  color: _isSaved ? AppTheme.gold1 : Colors.white,
                  onTap: _toggleSave,
                ),
                const SizedBox(height: 14),

                // Share
                _buildCompactAction(
                  icon: Icons.share_outlined,
                  label: '',
                  color: Colors.white,
                  onTap: () => ShareSheet.show(
                    context,
                    widget.post['id'] as int,
                    darkMode: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Views moved into the Likes-and-plays sheet; no longer
                // shown as a standalone right-rail action.

                // Dating / Connect
                _buildCompactAction(
                  icon: Icons.local_fire_department_outlined,
                  label: '',
                  color: Colors.orangeAccent,
                  onTap: () {},
                ),
              ],
            ),
          ),

          // ── Bottom user info & caption ──
          if (!hideUi)
          Positioned(
            left: 14,
            right: 56,
            bottom: 50,
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

          // ── Video progress bar — sits flush against the bottom edge of
          // the padded reels box, which itself stops above the bottom-nav.
          if (!hideUi && _isCurrentVideo && _initialized && _controller != null)
            Positioned(
              bottom: 0,
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
          ),
        );
      },
    );
  }

  Widget _buildMedia() {
    if (_mediaItems.isEmpty) {
      return const Center(
        child: Icon(Icons.image_not_supported, size: 48, color: Colors.white70),
      );
    }

    if (_mediaItems.length == 1) {
      return _buildSingleMedia(0);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: PinchToZoom.isPinching,
          builder: (_, pinching, __) => PageView.builder(
            controller: _mediaPageController,
            physics: pinching ? const NeverScrollableScrollPhysics() : null,
            itemCount: _mediaItems.length,
            onPageChanged: _onInnerPageChanged,
            itemBuilder: (_, i) => _buildSingleMedia(i),
          ),
        ),
        // Page indicator dots
        Positioned(
          bottom: 100,
          left: 0,
          right: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_mediaItems.length, (i) {
              return Container(
                width: _currentMediaIndex == i ? 8 : 6,
                height: _currentMediaIndex == i ? 8 : 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentMediaIndex == i
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

  Widget _buildSingleMedia(int index) {
    final item = _mediaItems[index];
    if (item.isVideo) {
      // Only the currently visible media page owns a VideoPlayerController;
      // adjacent pages render a lightweight placeholder until swiped to.
      if (index != _currentMediaIndex) {
        return Container(
          color: Colors.black,
          alignment: Alignment.center,
          child: const Icon(Icons.play_circle_outline, size: 48, color: Colors.white24),
        );
      }
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
      return PinchToZoom(
        child: SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: _controller!.value.size.width == 0 ? 360 : _controller!.value.size.width,
              height: _controller!.value.size.height == 0 ? 640 : _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
      );
    }

    // Image
    return PinchToZoom(
      child: SizedBox.expand(
        child: Image.network(
          item.url,
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _isFollowing ? AppTheme.gold1 : Colors.white,
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? Image.network(
                      avatarUrl.startsWith('http')
                          ? avatarUrl
                          : '${ApiService.baseUrl}/$avatarUrl',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      cacheWidth: 108,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 36,
                          height: 36,
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
                        width: 36,
                        height: 36,
                        color: Colors.grey[800],
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: GoogleFonts.jost(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    )
                  : Container(
                      width: 36,
                      height: 36,
                      color: Colors.grey[800],
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: GoogleFonts.jost(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
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


  /// Compact action button — smaller icon + optional count label.
  /// Like control with split tap targets — heart toggles, count opens the
  /// Likes-and-plays sheet (Instagram-style).
  Widget _buildLikeAction() {
    final hasCount = _likesCount > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggleLike,
          child: Icon(
            _isLiked ? Icons.favorite : Icons.favorite_border,
            size: 24,
            color: _isLiked ? Colors.redAccent : Colors.white,
          ),
        ),
        if (hasCount) ...[
          const SizedBox(height: 2),
          GestureDetector(
            onTap: () => LikesListSheet.show(
              context,
              widget.post['id'] as int,
              darkMode: true,
              likesCount: _likesCount,
              viewsCount: _viewsCount,
            ),
            child: Text(
              _formatCount(_likesCount),
              style: GoogleFonts.jost(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactAction({
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
          Icon(icon, size: 24, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.jost(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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

