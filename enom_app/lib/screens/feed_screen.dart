import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';
import 'create_post_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<Map<String, dynamic>> _posts = [];
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  int _lastPage = 1;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadFeed();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadFeed() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final result = await PostService.getFeed(page: 1);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        _posts.clear();
        for (final p in result.posts) {
          if (p is Map<String, dynamic>) _posts.add(p);
        }
        _currentPage = result.pagination?['current_page'] ?? 1;
        _lastPage = result.pagination?['last_page'] ?? 1;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _currentPage >= _lastPage) return;

    setState(() => _isLoadingMore = true);

    final result = await PostService.getFeed(page: _currentPage + 1);

    if (!mounted) return;

    if (result.success) {
      setState(() {
        for (final p in result.posts) {
          if (p is Map<String, dynamic>) _posts.add(p);
        }
        _currentPage = result.pagination?['current_page'] ?? _currentPage;
        _lastPage = result.pagination?['last_page'] ?? _lastPage;
        _isLoadingMore = false;
      });
    } else {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _onRefresh() async {
    _currentPage = 1;
    await _loadFeed();
  }

  void _navigateToCreatePost() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (created == true) {
      _onRefresh();
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

  Future<void> _deletePost(int index) async {
    final post = _posts[index];
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
      builder: (ctx) => _CommentsSheet(postId: postId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const EnomScreenBackground(gradientVariant: 4, particleCount: 15),
        SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'FEED',
                      style: AppTheme.label(context, size: 12),
                    ),
                    GestureDetector(
                      onTap: _navigateToCreatePost,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient2,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.gold1.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 16, color: Color(0xFF1A1612)),
                            const SizedBox(width: 4),
                            Text(
                              'Post',
                              style: GoogleFonts.jost(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1A1612),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Feed list
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: AppTheme.goldColor(context)),
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
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
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
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.textMuted(context)),
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
              child: Text('Retry', style: TextStyle(color: AppTheme.goldColor(context))),
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
          Icon(Icons.dynamic_feed_outlined, size: 56,
              color: AppTheme.goldColor(context).withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No posts yet', style: AppTheme.heading(context, size: 22)),
          const SizedBox(height: 8),
          Text('Be the first to share something', style: AppTheme.label(context, size: 12)),
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
    final userAvatar = user['profile_image'] as String?;
    final content = post['content'] as String? ?? '';
    final media = post['media'] as List<dynamic>? ?? [];
    final reactionsCount = post['reactions_count'] as int? ?? 0;
    final commentsCount = post['comments_count'] as int? ?? 0;
    final userReaction = post['user_reaction'] as String?;
    final createdAt = post['created_at'] as String? ?? '';
    final timeAgo = _formatTimeAgo(createdAt);
    final isOwner = post['is_owner'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.moodCardBg(context),
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
                      // Avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.goldColor(context).withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          color: AppTheme.glassBg(context),
                        ),
                        child: ClipOval(
                          child: userAvatar != null && userAvatar.isNotEmpty
                              ? Image.network(
                                  userAvatar.startsWith('http')
                                      ? userAvatar
                                      : '${ApiService.baseUrl}/$userAvatar',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _avatarFallback(userName),
                                )
                              : _avatarFallback(userName),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: GoogleFonts.jost(
                                color: AppTheme.text1(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              timeAgo,
                              style: GoogleFonts.jost(
                                color: AppTheme.textMuted(context),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isOwner)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_horiz, color: AppTheme.textMuted(context), size: 20),
                          color: AppTheme.bg2(context),
                          onSelected: (value) {
                            if (value == 'delete') _deletePost(index);
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: AppTheme.text1(context))),
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
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Text(
                      content,
                      style: GoogleFonts.jost(
                        color: AppTheme.text1(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                  ),

                // Media
                if (media.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildMediaGrid(media),
                ],

                // Reactions bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Row(
                    children: [
                      // Reaction buttons
                      _ReactionButton(
                        emoji: '\u{2764}',
                        label: reactionsCount > 0 ? '$reactionsCount' : '',
                        isActive: userReaction != null,
                        onTap: () => _toggleReaction(index, 'like'),
                        activeColor: AppTheme.goldColor(context),
                        context: context,
                      ),
                      _ReactionButton(
                        emoji: '\u{1F4AC}',
                        label: commentsCount > 0 ? '$commentsCount' : '',
                        isActive: false,
                        onTap: () => _showComments(post),
                        activeColor: AppTheme.goldColor(context),
                        context: context,
                      ),
                      const Spacer(),
                      // Reaction picker
                      _buildReactionPicker(index),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  Widget _buildMediaGrid(List<dynamic> media) {
    if (media.length == 1) {
      return _buildMediaItem(media[0], double.infinity, 240);
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
          child: _buildMediaItem(media[i], 200, 200),
        ),
      ),
    );
  }

  Widget _buildMediaItem(dynamic item, double width, double height) {
    String url = '';
    String type = 'image';
    if (item is Map) {
      // Try multiple possible keys for the URL
      url = (item['url'] ?? item['file_url'] ?? item['path'] ?? item['file_path'] ?? item['media_url'] ?? '').toString();
      type = (item['type'] ?? item['mime_type'] ?? item['file_type'] ?? 'image').toString();
      // ignore: avoid_print
      print('[Feed] media item keys: ${item.keys.toList()}, url: $url, type: $type');
    } else if (item is String) {
      url = item;
    }
    final fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}/${url.replaceAll(RegExp(r'^/'), '')}';

    if (type.contains('video')) {
      return Container(
        width: width == double.infinity ? null : width,
        height: height,
        margin: width == double.infinity ? const EdgeInsets.symmetric(horizontal: 16) : null,
        decoration: BoxDecoration(
          color: AppTheme.glassBg(context),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Icon(Icons.play_circle_outline, size: 48,
              color: AppTheme.goldColor(context).withValues(alpha: 0.7)),
        ),
      );
    }

    return Container(
      width: width == double.infinity ? null : width,
      height: height,
      margin: width == double.infinity ? const EdgeInsets.symmetric(horizontal: 16) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          fullUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: AppTheme.glassBg(context),
            child: Icon(Icons.broken_image_outlined, color: AppTheme.textMuted(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionPicker(int index) {
    final reactions = [
      ('\u{1F44D}', 'like'),
      ('\u{2764}', 'love'),
      ('\u{1F602}', 'haha'),
      ('\u{1F62E}', 'wow'),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: reactions.map((r) {
        return GestureDetector(
          onTap: () => _toggleReaction(index, r.$2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(r.$1, style: const TextStyle(fontSize: 18)),
          ),
        );
      }).toList(),
    );
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

/// Reaction button widget
class _ReactionButton extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color activeColor;
  final BuildContext context;

  const _ReactionButton({
    required this.emoji,
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.activeColor,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.12)
              : AppTheme.glassBg(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? activeColor.withValues(alpha: 0.3)
                : AppTheme.glassBorder(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.jost(
                  color: isActive ? activeColor : AppTheme.text2(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Comments bottom sheet
class _CommentsSheet extends StatefulWidget {
  final int postId;
  const _CommentsSheet({required this.postId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final result = await PostService.getComments(widget.postId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _comments.clear();
      for (final c in result.comments) {
        if (c is Map<String, dynamic>) _comments.add(c);
      }
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    final result = await PostService.addComment(widget.postId, content: text);

    if (!mounted) return;

    if (result.success) {
      _commentController.clear();
      _loadComments();
    }
    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    final goldC = AppTheme.goldColor(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.bg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('COMMENTS', style: AppTheme.label(context, size: 11)),
              ),
              AppTheme.goldDivider(context),

              // Comments list
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator(color: goldC, strokeWidth: 2))
                    : _comments.isEmpty
                        ? Center(
                            child: Text(
                              'No comments yet',
                              style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _comments.length,
                            itemBuilder: (_, i) => _buildComment(_comments[i]),
                          ),
              ),

              // Comment input
              Container(
                padding: EdgeInsets.fromLTRB(
                  16, 8, 16,
                  MediaQuery.of(context).viewInsets.bottom + 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.bg2(context),
                  border: Border(top: BorderSide(color: AppTheme.glassBorder(context))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: GoogleFonts.jost(color: AppTheme.text1(context), fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Write a comment...',
                          hintStyle: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 14),
                          filled: true,
                          fillColor: AppTheme.glassBg(context),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: AppTheme.glassBorder(context)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: AppTheme.glassBorder(context)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide(color: goldC.withValues(alpha: 0.4)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _isSending ? null : _sendComment,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AppTheme.goldGradient2,
                          shape: BoxShape.circle,
                        ),
                        child: _isSending
                            ? const Padding(
                                padding: EdgeInsets.all(10),
                                child: CircularProgressIndicator(
                                  color: Color(0xFF1A1612),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18, color: Color(0xFF1A1612)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComment(Map<String, dynamic> comment) {
    final user = comment['user'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? 'Anonymous';
    final content = comment['content'] as String? ?? '';
    final createdAt = comment['created_at'] as String? ?? '';

    String timeAgo = '';
    if (createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAt);
        final diff = DateTime.now().difference(date);
        if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes}m';
        } else if (diff.inHours < 24) {
          timeAgo = '${diff.inHours}h';
        } else {
          timeAgo = '${diff.inDays}d';
        }
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.glassBg(context),
              border: Border.all(color: AppTheme.glassBorder(context)),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: GoogleFonts.jost(
                  color: AppTheme.goldColor(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.jost(
                        color: AppTheme.text1(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (timeAgo.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 11),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: GoogleFonts.jost(
                    color: AppTheme.text2(context),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
