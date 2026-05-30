import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/api_service.dart';
import '../services/block_report_service.dart';
import '../services/post_service.dart';
import '../services/social_service.dart';
import '../services/upload_manager.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/double_tap_heart.dart';
import '../widgets/pinch_to_zoom.dart';
import 'create_post_screen.dart';
import 'edit_post_screen.dart';
import 'feed_reels_screen.dart';
import 'threaded_comments_sheet.dart';
import 'likes_list_sheet.dart';
import 'share_sheet.dart';
import 'user_profile_screen.dart';

class FeedScreen extends StatefulWidget {
  final String feedType; // 'following', 'for_you', 'favorites'
  const FeedScreen({super.key, this.feedType = 'following'});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<Map<String, dynamic>> _posts = [];
  final ScrollController _scrollController = ScrollController();
  int? _currentUserId;
  final Map<int, bool> _followStates = {}; // userId → isFollowing
  String? _nextCursor;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  StreamSubscription<bool>? _uploadSub;
  final Set<int> _viewedPostIds = {}; // Track which posts have been viewed

  // Local cache: postId → reaction type (e.g. 'like') for posts the user has liked
  // This compensates for the backend not returning user_reaction in the feed.
  static final Map<int, String?> _likeCache = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadFeed();
    _scrollController.addListener(_onScroll);

    // Listen for background upload completion and auto-refresh feed
    _uploadSub = UploadManager.instance.onUploadComplete.listen((_) {
      if (mounted) _onRefresh();
    });
  }

  @override
  void dispose() {
    _uploadSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll to top and refresh — called when user re-taps the Home tab.
  void scrollToTopAndRefresh() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _onRefresh();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    if (widget.feedType == 'for_you') {
      final result = await PostService.getForYouFeed();
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _posts.clear();
          for (final p in result.posts) {
            if (p is Map<String, dynamic>) {
              _applyLikeCache(p);
              _posts.add(p);
            }
          }
          _nextCursor = result.nextCursor;
          _isLoading = false;
        });
        _fetchFollowStatuses(_posts);
      } else {
        setState(() { _isLoading = false; _hasError = true; });
      }
    } else if (widget.feedType == 'favorites') {
      final result = await SocialService.getSavedPosts();
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _posts.clear();
          for (final p in result.posts) {
            if (p is Map<String, dynamic>) {
              _applyLikeCache(p);
              _posts.add(p);
            }
          }
          _nextCursor = null;
          _isLoading = false;
        });
      } else {
        setState(() { _isLoading = false; _hasError = true; });
      }
    } else {
      final result = await PostService.getFeed();
      if (!mounted) return;
      if (result.success) {
        setState(() {
          _posts.clear();
          for (final p in result.posts) {
            if (p is Map<String, dynamic>) {
              _applyLikeCache(p);
              _posts.add(p);
            }
          }
          _nextCursor = result.pagination?['next_cursor'] as String?;
          _isLoading = false;
        });
        _fetchFollowStatuses(_posts);
      } else {
        setState(() { _isLoading = false; _hasError = true; });
      }
    }
  }

  /// Fetch follow status for all unique non-owner users in posts.
  Future<void> _fetchFollowStatuses(List<Map<String, dynamic>> posts) async {
    final userIds = <int>[];
    for (final post in posts) {
      final user = post['user'] as Map<String, dynamic>? ?? {};
      final uid = user['id'] as int?;
      final isOwner = (post['is_owner'] as bool? ?? false) ||
          (_currentUserId != null && uid == _currentUserId);
      if (uid != null && !isOwner && !_followStates.containsKey(uid)) {
        userIds.add(uid);
      }
    }
    if (userIds.isEmpty) return;

    final statuses = await SocialService.batchFollowStatus(userIds);
    if (mounted) {
      setState(() => _followStates.addAll(statuses));
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextCursor == null) return;

    setState(() => _isLoadingMore = true);

    if (widget.feedType == 'for_you') {
      final result = await PostService.getForYouFeed(cursor: _nextCursor);
      if (!mounted) return;
      if (result.success) {
        final newPosts = <Map<String, dynamic>>[];
        setState(() {
          for (final p in result.posts) {
            if (p is Map<String, dynamic>) {
              _applyLikeCache(p);
              _posts.add(p);
              newPosts.add(p);
            }
          }
          _nextCursor = result.nextCursor;
          _isLoadingMore = false;
        });
        _fetchFollowStatuses(newPosts);
      } else {
        setState(() => _isLoadingMore = false);
      }
    } else {
      final result = await PostService.getFeed(cursor: _nextCursor);
      if (!mounted) return;
      if (result.success) {
        final newPosts = <Map<String, dynamic>>[];
        setState(() {
          for (final p in result.posts) {
            if (p is Map<String, dynamic>) {
              _applyLikeCache(p);
              _posts.add(p);
              newPosts.add(p);
            }
          }
          _nextCursor = result.pagination?['next_cursor'] as String?;
          _isLoadingMore = false;
        });
        _fetchFollowStatuses(newPosts);
      } else {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    _nextCursor = null;
    await _loadFeed();
  }

  void _navigateToCreatePost() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreatePostScreen()));
    if (created == true) {
      _onRefresh();
    }
  }

  void _openUserProfile(Map<String, dynamic> user) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileScreen(user: user)),
    );
  }

  Future<void> _loadCurrentUser() async {
    final user = await ApiService.getUser();
    if (user != null && mounted) {
      setState(() => _currentUserId = user['id'] as int?);
    }
  }

  /// Apply cached like state to a post if the backend didn't return it.
  void _applyLikeCache(Map<String, dynamic> post) {
    final postId = post['id'] as int?;
    if (postId == null) return;
    // If the backend returned a user_reaction, trust it and update our cache
    if (post['user_reaction'] != null) {
      _likeCache[postId] = post['user_reaction'] as String;
    } else if (_likeCache.containsKey(postId)) {
      // Backend didn't return it but we have a cached value
      final cached = _likeCache[postId];
      if (cached != null) {
        post['user_reaction'] = cached;
      }
    }
  }

  /// Record a view for a post (once per session).
  void _recordView(int postId) {
    if (_viewedPostIds.contains(postId)) return;
    _viewedPostIds.add(postId);
    SocialService.recordView(postId);
  }

  /// Toggle follow on a user from a post card.
  Future<void> _toggleFollow(int index) async {
    final post = _posts[index];
    final user = post['user'] as Map<String, dynamic>? ?? {};
    final userId = user['id'] as int?;
    if (userId == null) return;

    // Optimistic update
    final wasFollowing = _followStates[userId] ?? false;
    setState(() => _followStates[userId] = !wasFollowing);

    final result = await SocialService.toggleFollow(userId);
    if (mounted) {
      setState(() => _followStates[userId] = result.success ? result.isFollowing : wasFollowing);
    }
  }

  /// Toggle save/bookmark on a post.
  Future<void> _toggleSave(int index) async {
    final post = _posts[index];
    final postId = post['id'] as int;

    final wasSaved = post['is_saved'] as bool? ?? false;
    setState(() => post['is_saved'] = !wasSaved);

    final result = await SocialService.toggleSave(postId);
    if (mounted && result.success) {
      setState(() => post['is_saved'] = result.isSaved);
    } else if (mounted) {
      setState(() => post['is_saved'] = wasSaved);
    }
  }

  /// Instagram-style double-tap: only ever LIKES; never un-likes.
  /// The heart animation always plays (handled by [DoubleTapHeart]).
  void _doubleTapLike(int index) {
    if (index < 0 || index >= _posts.length) return;
    final post = _posts[index];
    if (post['user_reaction'] == null) {
      _toggleReaction(index, 'like');
    }
  }

  Future<void> _toggleReaction(int index, String type) async {
    final post = _posts[index];
    final postId = post['id'] as int;

    // Save previous state for rollback
    final prevReaction = post['user_reaction'];
    final prevCount = post['reactions_count'] as int? ?? 0;

    // Optimistic update
    setState(() {
      final userReaction = post['user_reaction'];
      if (userReaction == type) {
        post['user_reaction'] = null;
        post['reactions_count'] = ((post['reactions_count'] ?? 1) as int) - 1;
      } else {
        if (userReaction == null) {
          post['reactions_count'] = ((post['reactions_count'] ?? 0) as int) + 1;
        }
        post['user_reaction'] = type;
      }
    });

    final result = await PostService.toggleReaction(postId, type);
    if (result.success) {
      // Update local cache with current state
      _likeCache[postId] = post['user_reaction'] as String?;
    } else if (mounted) {
      // Revert on failure
      setState(() {
        post['user_reaction'] = prevReaction;
        post['reactions_count'] = prevCount;
      });
      debugPrint('[Feed] toggleReaction FAILED for postId=$postId: ${result.message}');
    }
  }

  Future<void> _editPost(int index) async {
    final post = _posts[index];
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditPostScreen(post: post)),
    );
    if (updated == true) {
      _onRefresh();
    }
  }

  Future<void> _deletePost(int index) async {
    final post = _posts[index];
    final postId = post['id'] as int;

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: AppTheme.bg2(context),
            title: Text(
              AppLocalizations.of(context)!.translate('delete_post'),
              style: AppTheme.body(context, size: 18, weight: FontWeight.w600),
            ),
            content: Text(
              AppLocalizations.of(context)!.translate('are_you_sure'),
              style: AppTheme.body(context, size: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  AppLocalizations.of(context)!.translate('cancel'),
                  style: TextStyle(color: AppTheme.text2(context)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  AppLocalizations.of(context)!.translate('delete'),
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    final result = await PostService.deletePost(postId);
    if (result.success && mounted) {
      setState(() => _posts.removeAt(index));
      AppTheme.showSnackBar(context, AppLocalizations.of(context)!.translate('post_deleted'));
    }
  }

  void _showReportDialog(int contentId, String type) {
    final l10n = AppLocalizations.of(context)!;
    final reasons = ['spam', 'harassment', 'nudity', 'violence', 'misinformation', 'other'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.bg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppTheme.textMuted(context), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(l10n.translate('report'), style: GoogleFonts.jost(
              color: AppTheme.text1(context), fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...reasons.map((r) => ListTile(
              title: Text(r[0].toUpperCase() + r.substring(1),
                  style: GoogleFonts.jost(color: AppTheme.text1(context), fontSize: 14)),
              onTap: () async {
                Navigator.pop(ctx);
                final result = await BlockReportService.report(type: type, id: contentId, reason: r);
                if (mounted) {
                  AppTheme.showSnackBar(context, result.message);
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  Future<void> _blockUser(int userId, int postIndex) async {
    final result = await BlockReportService.toggleBlock(userId);
    if (mounted && result.success) {
      AppTheme.showSnackBar(context, result.message);
      // Remove blocked user's post from feed
      setState(() => _posts.removeAt(postIndex));
    }
  }

  void _showComments(Map<String, dynamic> post) {
    final postId = post['id'] as int;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ThreadedCommentsSheet(
        postId: postId,
        onCommentAdded: () {
          if (mounted) {
            setState(() {
              post['comments_count'] = ((post['comments_count'] ?? 0) as int) + 1;
            });
          }
        },
      ),
    );
  }

  /// Open the TikTok/Reels-style screen starting at the given post.
  void _openReelsScreen(Map<String, dynamic> tappedPost) {
    // Only posts with media (images/videos), skip text-only posts
    final allPosts = _posts.where((post) {
      final media = post['media'] as List<dynamic>? ?? [];
      return media.isNotEmpty;
    }).toList();
    // Inject follow state into each post so reels can read it
    for (final post in allPosts) {
      final user = post['user'] as Map<String, dynamic>? ?? {};
      final uid = user['id'] as int?;
      if (uid != null && _followStates.containsKey(uid)) {
        post['is_following'] = _followStates[uid];
      }
    }
    final initialIndex = allPosts.indexWhere((p) => p['id'] == tappedPost['id']);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => FeedReelsScreen(
              videoPosts: allPosts,
              initialIndex: initialIndex >= 0 ? initialIndex : 0,
            ),
          ),
        )
        .then((_) {
      if (!mounted) return;
      // Sync follow-state cache with any toggles done in reels.
      for (final post in allPosts) {
        final user = post['user'] as Map<String, dynamic>? ?? {};
        final uid = user['id'] as int?;
        final isFollowing = post['is_following'] as bool?;
        if (uid != null && isFollowing != null) {
          _followStates[uid] = isFollowing;
        }
        // Refresh like cache from any reactions toggled in reels.
        final pid = post['id'] as int?;
        if (pid != null) {
          _likeCache[pid] = post['user_reaction'] as String?;
        }
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // Feed list
            Expanded(
              child:
                  _isLoading
                      ? Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.goldColor(context),
                        ),
                      )
                      : _hasError
                      ? _buildErrorState()
                      : _posts.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                        onRefresh: _onRefresh,
                        color: AppTheme.goldColor(context),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: PinchToZoom.isPinching,
                          builder: (_, pinching, __) => ListView.builder(
                            controller: _scrollController,
                            physics: pinching
                                ? const NeverScrollableScrollPhysics()
                                : const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(bottom: 90),
                            itemCount:
                                _posts.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _posts.length) {
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
                              return _buildPostCard(index);
                            },
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_rounded,
            size: 48,
            color: AppTheme.textMuted(context),
          ),
          const SizedBox(height: 12),
          Text(AppLocalizations.of(context)!.translate('could_not_load_feed'), style: AppTheme.body(context, size: 15)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loadFeed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.goldColor(context)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                AppLocalizations.of(context)!.translate('retry'),
                style: TextStyle(color: AppTheme.goldColor(context)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dynamic_feed_outlined,
            size: 56,
            color: AppTheme.goldColor(context).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(AppLocalizations.of(context)!.translate('no_posts_yet'), style: AppTheme.heading(context, size: 22)),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.translate('be_first_to_share'),
            style: AppTheme.label(context, size: 12),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _navigateToCreatePost,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient2,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                'Create Post',
                style: GoogleFonts.jost(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1612),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(int index) {
    final post = _posts[index];
    final user = post['user'] as Map<String, dynamic>? ?? {};
    final userName = user['name'] as String? ?? 'Anonymous';
    final userAvatar =
        (user['profile_image_url'] ?? user['profile_image']) as String?;
    final content = post['content'] as String? ?? '';
    final media = post['media'] as List<dynamic>? ?? [];
    final reactionsCount = post['reactions_count'] as int? ?? 0;
    final commentsCount = post['comments_count'] as int? ?? 0;
    final userReaction = post['user_reaction'] as String?;
    final createdAt = post['created_at'] as String? ?? '';
    final timeAgo = _formatTimeAgo(createdAt);
    final postUserId = user['id'] as int?;
    final isOwner = (post['is_owner'] as bool? ?? false) || (_currentUserId != null && postUserId == _currentUserId);
    final isFollowing = postUserId != null ? (_followStates[postUserId] ?? false) : false;
    final isSaved = post['is_saved'] as bool? ?? false;
    final viewsCount = post['views_count'] as int? ?? 0;
    final postId = post['id'] as int;

    // Record view when card is built (visible on screen)
    _recordView(postId);

    return Column(
      key: ValueKey('post_$postId'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── User header (Instagram style) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: isOwner ? null : () => _openUserProfile(user),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.goldColor(context).withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child:
                        userAvatar != null && userAvatar.isNotEmpty
                            ? Image.network(
                              userAvatar.startsWith('http')
                                  ? userAvatar
                                  : '${ApiService.baseUrl}/$userAvatar',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              cacheWidth: 108,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Center(
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: AppTheme.goldColor(context),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder:
                                  (_, __, ___) => _avatarFallback(userName),
                            )
                            : _avatarFallback(userName),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Username + time (+ optional location row)
              Expanded(
                child: GestureDetector(
                  onTap: isOwner ? null : () => _openUserProfile(user),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userName,
                              style: GoogleFonts.jost(
                                color: AppTheme.text1(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timeAgo.isNotEmpty) ...[
                            Text(
                              ' · $timeAgo',
                              style: GoogleFonts.jost(
                                color: AppTheme.textMuted(context),
                                fontSize: 13,
                              ),
                            ),
                          ],
                          if (!isOwner) ...[
                            Text(
                              ' · ',
                              style: GoogleFonts.jost(
                                color: AppTheme.textMuted(context),
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _toggleFollow(index),
                              child: Text(
                                isFollowing ? AppLocalizations.of(context)!.translate('unfollow') : AppLocalizations.of(context)!.translate('follow'),
                                style: GoogleFonts.jost(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isFollowing
                                      ? AppTheme.textMuted(context)
                                      : AppTheme.goldColor(context),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Location display hidden until Google Places API integration is ready.
                      // TODO: re-enable once GET /api/places/search is live and posts carry verified location data.
                      // if ((post['location_name'] as String?)?.trim().isNotEmpty == true)
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 2),
                      //     child: Row(
                      //       children: [
                      //         Icon(
                      //           Icons.location_on,
                      //           size: 12,
                      //           color: AppTheme.textMuted(context),
                      //         ),
                      //         const SizedBox(width: 2),
                      //         Flexible(
                      //           child: Text(
                      //             (post['location_name'] as String).trim(),
                      //             style: GoogleFonts.jost(
                      //               color: AppTheme.textMuted(context),
                      //               fontSize: 12,
                      //               fontWeight: FontWeight.w500,
                      //             ),
                      //             overflow: TextOverflow.ellipsis,
                      //           ),
                      //         ),
                      //       ],
                      //     ),
                      //   ),
                    ],
                  ),
                ),
              ),
              // More options
              if (isOwner)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    color: AppTheme.text1(context),
                    size: 20,
                  ),
                  color: AppTheme.bg2(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (value) {
                    if (value == 'edit') _editPost(index);
                    if (value == 'delete') _deletePost(index);
                  },
                  itemBuilder:
                      (ctx) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, color: AppTheme.goldColor(context), size: 18),
                              const SizedBox(width: 8),
                              Text(AppLocalizations.of(context)!.translate('edit_post'), style: TextStyle(color: AppTheme.text1(context))),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                              const SizedBox(width: 8),
                              Text(AppLocalizations.of(context)!.translate('delete_post'), style: TextStyle(color: AppTheme.text1(context))),
                            ],
                          ),
                        ),
                      ],
                )
              else
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: AppTheme.text1(context), size: 20),
                  color: AppTheme.bg2(context),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (value) {
                    final postId = post['id'] as int;
                    final userId = user['id'] as int?;
                    if (value == 'report') {
                      _showReportDialog(postId, 'post');
                    } else if (value == 'block' && userId != null) {
                      _blockUser(userId, index);
                    }
                  },
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.flag_outlined, color: Colors.orangeAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.translate('report'),
                              style: TextStyle(color: AppTheme.text1(context))),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          const Icon(Icons.block, color: Colors.redAccent, size: 18),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.translate('block_user'),
                              style: TextStyle(color: AppTheme.text1(context))),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),

        // ── Media (full width, no padding, no rounded corners) ──
        if (media.isNotEmpty)
          _buildMediaGrid(media, post, index),

        // ── Caption ABOVE actions for text-only posts ──
        if (media.isEmpty && content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$userName ',
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: content,
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // ── Action icons bar (Instagram style: inline counts, compact) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Row(
            children: [
              // Heart icon — tap toggles reaction
              GestureDetector(
                onTap: () => _toggleReaction(index, 'like'),
                child: Icon(
                  userReaction != null ? Icons.favorite : Icons.favorite_border,
                  size: 22,
                  color: userReaction != null
                      ? Colors.redAccent
                      : AppTheme.text1(context),
                ),
              ),
              // Like count — tap opens the Likes-and-plays sheet
              if (reactionsCount > 0) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => LikesListSheet.show(
                    context,
                    post['id'] as int,
                    likesCount: reactionsCount,
                    viewsCount: viewsCount,
                  ),
                  child: Text(
                    _formatCount(reactionsCount),
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 14),
              // Comment + inline count
              GestureDetector(
                onTap: () => _showComments(post),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 22,
                      color: AppTheme.text1(context),
                    ),
                    if (commentsCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        _formatCount(commentsCount),
                        style: GoogleFonts.jost(
                          color: AppTheme.text1(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Share
              GestureDetector(
                onTap: () => ShareSheet.show(context, post['id'] as int),
                child: Icon(
                  Icons.send_outlined,
                  size: 22,
                  color: AppTheme.text1(context),
                ),
              ),
              const SizedBox(width: 14),
              // Bookmark (moved next to share, no longer right-aligned)
              GestureDetector(
                onTap: () => _toggleSave(index),
                child: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  size: 22,
                  color: isSaved ? AppTheme.goldColor(context) : AppTheme.text1(context),
                ),
              ),
              const Spacer(),
              // Views moved into the new Likes-and-plays sheet, so the
              // standalone view-count chip is no longer rendered here.
            ],
          ),
        ),

        // ── Caption BELOW actions for posts with media ──
        if (media.isNotEmpty && content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$userName ',
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: content,
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        const SizedBox(height: 2),
      ],
    );
  }

  Widget _avatarFallback(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: GoogleFonts.jost(
          color: AppTheme.goldColor(context),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  List<String> _getImageUrls(List<dynamic> media) {
    return media
        .where((item) => _getMediaType(item).contains('image'))
        .map((item) => _getMediaUrl(item))
        .toList();
  }

  Widget _buildMediaGrid(
    List<dynamic> media,
    Map<String, dynamic> post,
    int index,
  ) {
    final imageUrls = _getImageUrls(media);

    if (media.length == 1) {
      return _buildMediaItem(media[0], imageUrls, post, index);
    }

    // Multiple media: PageView with dot indicators
    return _MediaCarousel(
      media: media,
      imageUrls: imageUrls,
      post: post,
      buildItem: (item) => _buildMediaItem(item, imageUrls, post, index),
    );
  }

  String _getMediaUrl(dynamic item) {
    if (item is Map) {
      final url =
          (item['url'] ??
                  item['file_url'] ??
                  item['path'] ??
                  item['file_path'] ??
                  item['media_url'] ??
                  '')
              .toString();
      return url.startsWith('http')
          ? url
          : '${ApiService.baseUrl}/${url.replaceAll(RegExp(r'^/'), '')}';
    }
    final url = item.toString();
    return url.startsWith('http')
        ? url
        : '${ApiService.baseUrl}/${url.replaceAll(RegExp(r'^/'), '')}';
  }

  String _getMediaType(dynamic item) {
    if (item is Map) {
      return (item['type'] ?? item['mime_type'] ?? item['file_type'] ?? 'image')
          .toString();
    }
    return 'image';
  }

  Widget _buildMediaItem(
    dynamic item,
    List<String> imageUrls,
    Map<String, dynamic> post,
    int index,
  ) {
    final fullUrl = _getMediaUrl(item);
    final type = _getMediaType(item);
    final screenWidth = MediaQuery.of(context).size.width;

    if (type.contains('video')) {
      return DoubleTapHeart(
        onTap: () => _openReelsScreen(post),
        onDoubleTap: () => _doubleTapLike(index),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: screenWidth * 0.56),
          color: Colors.black,
          child: PinchToZoom(
            child: FeedInlineVideoPlayer(
              url: fullUrl,
              width: screenWidth,
              height: screenWidth * 0.56,
            ),
          ),
        ),
      );
    }

    return DoubleTapHeart(
      onTap: () => _openReelsScreen(post),
      onDoubleTap: () => _doubleTapLike(index),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: screenWidth * 0.56),
        color:
            AppTheme.isDark(context)
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFFAFAFA),
        child: PinchToZoom(
          child: Image.network(
          fullUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return SizedBox(
              height: screenWidth,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.goldColor(context),
                ),
              ),
            );
          },
          errorBuilder:
              (_, __, ___) => SizedBox(
                height: screenWidth * 0.56,
                child: Container(
                  color: AppTheme.glassBg(context),
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppTheme.textMuted(context),
                    ),
                  ),
                ),
              ),
        ),
        ),
      ),
    );
  }


  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  String _formatTimeAgo(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}

/// Carousel with page dots for multiple media items.
class _MediaCarousel extends StatefulWidget {
  final List<dynamic> media;
  final List<String> imageUrls;
  final Map<String, dynamic> post;
  final Widget Function(dynamic item) buildItem;

  const _MediaCarousel({
    required this.media,
    required this.imageUrls,
    required this.post,
    required this.buildItem,
  });

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ValueListenableBuilder<bool>(
            valueListenable: PinchToZoom.isPinching,
            builder: (_, pinching, __) => PageView.builder(
              physics: pinching ? const NeverScrollableScrollPhysics() : null,
              itemCount: widget.media.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) => widget.buildItem(widget.media[i]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.media.length, (i) {
            return Container(
              width: _current == i ? 7 : 6,
              height: _current == i ? 7 : 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _current == i
                    ? AppTheme.goldColor(context)
                    : AppTheme.textMuted(context).withValues(alpha: 0.3),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class FullImageScreen extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const FullImageScreen({super.key, required this.urls, this.initialIndex = 0});

  @override
  State<FullImageScreen> createState() => _FullImageScreenState();
}

class _FullImageScreenState extends State<FullImageScreen> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title:
            widget.urls.length > 1
                ? Text(
                  '${_currentIndex + 1} / ${widget.urls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                )
                : null,
        centerTitle: true,
      ),
      extendBodyBehindAppBar: true,
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.urls.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder:
            (_, index) => Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  widget.urls[index],
                  fit: BoxFit.contain,
                  errorBuilder:
                      (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: Colors.white70,
                      ),
                ),
              ),
            ),
      ),
    );
  }
}

class FeedInlineVideoPlayer extends StatefulWidget {
  final String url;
  final double width;
  final double height;
  const FeedInlineVideoPlayer({
    super.key,
    required this.url,
    required this.width,
    required this.height,
  });

  @override
  State<FeedInlineVideoPlayer> createState() => _FeedInlineVideoPlayerState();
}

/// App-wide mute state for inline feed videos. Toggling on one post applies
/// to every other feed video instantly. Defaults to muted (Instagram convention).
final ValueNotifier<bool> feedVideosMuted = ValueNotifier<bool>(true);

class _FeedInlineVideoPlayerState extends State<FeedInlineVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isVisible = false;
  // Set in dispose() before disposing the controller so any in-flight
  // initialize().then callback bails out instead of touching a dead player.
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    feedVideosMuted.addListener(_applyMuteState);
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (_disposed || !mounted) return;
            setState(() => _initialized = true);
            _controller.setVolume(feedVideosMuted.value ? 0 : 1);
            _controller.setLooping(true);
            // Only play if currently visible
            if (_isVisible) _controller.play();
          })
          .catchError((_) {
            if (_disposed || !mounted) return;
            setState(() => _hasError = true);
          });
  }

  void _applyMuteState() {
    if (_disposed || !_initialized) return;
    _controller.setVolume(feedVideosMuted.value ? 0 : 1);
  }

  @override
  void dispose() {
    _disposed = true;
    feedVideosMuted.removeListener(_applyMuteState);
    _controller.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    // VisibilityDetector can fire after the widget is gone (e.g. when the page
    // scrolls off in a PageView). Bail out instead of touching a dead controller.
    if (_disposed) return;
    final visible = info.visibleFraction > 0.5;
    if (visible == _isVisible) return;
    _isVisible = visible;
    if (!_initialized) return;

    if (visible) {
      _controller.play();
    } else {
      _controller.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('feed-video-${widget.url}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_hasError) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: Icon(Icons.error_outline, size: 36, color: Colors.white70),
        ),
      );
    }

    if (!_initialized) {
      return SizedBox(
        height: widget.height,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.goldColor(context),
          ),
        ),
      );
    }

    final videoWidth = _controller.value.size.width;
    final videoHeight = _controller.value.size.height;
    final aspectRatio = (videoWidth > 0 && videoHeight > 0)
        ? videoWidth / videoHeight
        : 16 / 9;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: videoWidth == 0 ? 320 : videoWidth,
                  height: videoHeight == 0 ? 240 : videoHeight,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          ),
          // Mute/Unmute toggle
          Positioned(
            right: 8,
            bottom: 8,
          child: GestureDetector(
            onTap: () {
              feedVideosMuted.value = !feedVideosMuted.value;
            },
            child: ValueListenableBuilder<bool>(
              valueListenable: feedVideosMuted,
              builder: (_, muted, __) => Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.all(6),
                child: Icon(
                  muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }
}

class VideoPlayerScreen extends StatefulWidget {
  final String url;
  const VideoPlayerScreen({super.key, required this.url});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _showControls = true;
  // Bails out of in-flight initialize().then after dispose.
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (_disposed || !mounted) return;
            setState(() {
              _initialized = true;
            });
            _controller.play();
          })
          .catchError((_) {
            if (_disposed || !mounted) return;
            setState(() => _hasError = true);
          });
    _controller.setLooping(true);
    _controller.addListener(() {
      if (_disposed || !mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Center(
          child:
              _hasError
                  ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load video',
                        style: GoogleFonts.jost(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  )
                  : !_initialized
                  ? CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.goldColor(context),
                  )
                  : Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                      if (_showControls) ...[
                        // Play/pause button
                        GestureDetector(
                          onTap: _togglePlay,
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 40,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Progress bar at bottom
                        Positioned(
                          bottom: 40,
                          left: 16,
                          right: 16,
                          child: Row(
                            children: [
                              Text(
                                _formatDuration(_controller.value.position),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: VideoProgressIndicator(
                                  _controller,
                                  allowScrubbing: true,
                                  colors: VideoProgressColors(
                                    playedColor: AppTheme.goldColor(context),
                                    bufferedColor: Colors.white24,
                                    backgroundColor: Colors.white12,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatDuration(_controller.value.duration),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
        ),
      ),
    );
  }
}
