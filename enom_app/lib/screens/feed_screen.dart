import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../services/social_service.dart';
import '../services/upload_manager.dart';
import '../theme/app_theme.dart';
import 'create_post_screen.dart';
import 'edit_post_screen.dart';
import 'feed_reels_screen.dart';
import 'threaded_comments_sheet.dart';
import 'likes_list_sheet.dart';
import 'user_profile_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

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

    final result = await PostService.getFeed();

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
      _fetchFollowStatuses(_posts);
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
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

    final result = await PostService.getFeed(cursor: _nextCursor);

    if (!mounted) return;

    if (result.success) {
      final newPosts = <Map<String, dynamic>>[];
      setState(() {
        for (final p in result.posts) {
          if (p is Map<String, dynamic>) {
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

  Future<void> _toggleReaction(int index, String type) async {
    final post = _posts[index];
    final postId = post['id'] as int;

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

    await PostService.toggleReaction(postId, type);
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
              'Delete Post',
              style: AppTheme.body(context, size: 18, weight: FontWeight.w600),
            ),
            content: Text(
              'Are you sure?',
              style: AppTheme.body(context, size: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppTheme.text2(context)),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    final result = await PostService.deletePost(postId);
    if (result.success && mounted) {
      setState(() => _posts.removeAt(index));
      AppTheme.showSnackBar(context, 'Post deleted');
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FeedReelsScreen(
          videoPosts: allPosts,
          initialIndex: initialIndex >= 0 ? initialIndex : 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: SafeArea(
        child: Column(
          children: [
            // Header — Instagram style
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ENOM',
                    style: GoogleFonts.cormorantGaramond(
                      color: AppTheme.text1(context),
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 4,
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _navigateToCreatePost,
                        child: Icon(
                          Icons.add_box_outlined,
                          size: 26,
                          color: AppTheme.text1(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

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
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: _posts.length + (_isLoadingMore ? 1 : 0),
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
          Text('Could not load feed', style: AppTheme.body(context, size: 15)),
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
                'Retry',
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
          Text('No posts yet', style: AppTheme.heading(context, size: 22)),
          const SizedBox(height: 8),
          Text(
            'Be the first to share something',
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
    // ignore: avoid_print
    print(
      '[Feed] user: ${user['name']}, avatar: $userAvatar, keys: ${user.keys.toList()}',
    );
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
              // Username + time
              Expanded(
                child: GestureDetector(
                  onTap: isOwner ? null : () => _openUserProfile(user),
                  child: Row(
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
                            isFollowing ? 'Following' : 'Follow',
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
                )
              else
                GestureDetector(
                  onTap: () {},
                  child: Icon(Icons.more_vert, color: AppTheme.text1(context), size: 20),
                ),
            ],
          ),
        ),

        // ── Media (full width, no padding, no rounded corners) ──
        if (media.isNotEmpty)
          _buildMediaGrid(media, post),

        // ── Action icons bar (Instagram style) ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              // Heart
              GestureDetector(
                onTap: () => _toggleReaction(index, 'like'),
                child: Icon(
                  userReaction != null ? Icons.favorite : Icons.favorite_border,
                  size: 26,
                  color: userReaction != null ? Colors.redAccent : AppTheme.text1(context),
                ),
              ),
              const SizedBox(width: 16),
              // Comment
              GestureDetector(
                onTap: () => _showComments(post),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 24,
                  color: AppTheme.text1(context),
                ),
              ),
              const SizedBox(width: 16),
              // Share
              GestureDetector(
                onTap: () {},
                child: Icon(
                  Icons.send_outlined,
                  size: 24,
                  color: AppTheme.text1(context),
                ),
              ),
              const Spacer(),
              // Bookmark
              GestureDetector(
                onTap: () => _toggleSave(index),
                child: Icon(
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  size: 26,
                  color: isSaved ? AppTheme.goldColor(context) : AppTheme.text1(context),
                ),
              ),
            ],
          ),
        ),

        // ── Likes count ──
        if (reactionsCount > 0)
          GestureDetector(
            onTap: () => LikesListSheet.show(context, post['id'] as int),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Text(
                '$reactionsCount ${reactionsCount == 1 ? 'like' : 'likes'}',
                style: GoogleFonts.jost(
                  color: AppTheme.text1(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

        // ── Caption (username + content inline) ──
        if (content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
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

        // ── View all comments link ──
        if (commentsCount > 0)
          GestureDetector(
            onTap: () => _showComments(post),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Text(
                'View all $commentsCount comments',
                style: GoogleFonts.jost(
                  color: AppTheme.textMuted(context),
                  fontSize: 13,
                ),
              ),
            ),
          ),

        // ── Views count ──
        if (viewsCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Text(
              '${_formatCount(viewsCount)} views',
              style: GoogleFonts.jost(
                color: AppTheme.textMuted(context),
                fontSize: 12,
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Thin divider between posts
        Divider(
          height: 0.5,
          thickness: 0.5,
          color: AppTheme.isDark(context)
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
        ),
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

  Widget _buildMediaGrid(List<dynamic> media, Map<String, dynamic> post) {
    final imageUrls = _getImageUrls(media);

    if (media.length == 1) {
      return _buildMediaItem(media[0], imageUrls, post);
    }

    // Multiple media: PageView with dot indicators
    return _MediaCarousel(
      media: media,
      imageUrls: imageUrls,
      post: post,
      buildItem: (item) => _buildMediaItem(item, imageUrls, post),
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
  ) {
    final fullUrl = _getMediaUrl(item);
    final type = _getMediaType(item);
    final screenWidth = MediaQuery.of(context).size.width;

    if (type.contains('video')) {
      return GestureDetector(
        onTap: () => _openReelsScreen(post),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: screenWidth * 0.56),
          color: Colors.black,
          child: FeedInlineVideoPlayer(
            url: fullUrl,
            width: screenWidth,
            height: screenWidth * 0.56,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openReelsScreen(post),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(minHeight: screenWidth * 0.56),
        color:
            AppTheme.isDark(context)
                ? const Color(0xFF1A1A1A)
                : const Color(0xFFFAFAFA),
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
          child: PageView.builder(
            itemCount: widget.media.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => widget.buildItem(widget.media[i]),
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

class _FeedInlineVideoPlayerState extends State<FeedInlineVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _isMuted = true;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() => _initialized = true);
              _controller.setVolume(0);
              _controller.setLooping(true);
              // Only play if currently visible
              if (_isVisible) _controller.play();
            }
          })
          .catchError((_) {
            if (mounted) setState(() => _hasError = true);
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
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
              setState(() {
                _isMuted = !_isMuted;
                _controller.setVolume(_isMuted ? 0 : 1);
              });
            },
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(6),
              child: Icon(
                _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                size: 16,
                color: Colors.white,
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

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize()
          .then((_) {
            if (mounted) {
              setState(() {
                _initialized = true;
              });
              _controller.play();
            }
          })
          .catchError((_) {
            if (mounted) {
              setState(() => _hasError = true);
            }
          });
    _controller.setLooping(true);
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
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
