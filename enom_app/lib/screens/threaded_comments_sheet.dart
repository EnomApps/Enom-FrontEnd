import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';

/// Reusable threaded comments bottom sheet.
/// Supports nested replies (parent_id), reply UI, and works in both
/// light (feed) and dark (reels) themes.
class ThreadedCommentsSheet extends StatefulWidget {
  final int postId;

  /// If true, uses dark theme (for reels screen).
  final bool darkMode;

  /// Called whenever a comment is added so the parent can update count instantly.
  final VoidCallback? onCommentAdded;

  const ThreadedCommentsSheet({
    super.key,
    required this.postId,
    this.darkMode = false,
    this.onCommentAdded,
  });

  @override
  State<ThreadedCommentsSheet> createState() => _ThreadedCommentsSheetState();
}

class _ThreadedCommentsSheetState extends State<ThreadedCommentsSheet> {
  final List<Map<String, dynamic>> _comments = [];
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = true;
  bool _isSending = false;

  /// When replying to a comment, this holds the parent comment info.
  int? _replyToId;
  String? _replyToName;

  // Tracks which comment threads are expanded (show replies).
  final Set<int> _expandedReplies = {};

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _focusNode.dispose();
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

  /// Build a tree: top-level comments (no parent_id) and their nested replies.
  List<Map<String, dynamic>> _getTopLevelComments() {
    return _comments.where((c) => c['parent_id'] == null).toList();
  }

  List<Map<String, dynamic>> _getReplies(int parentId) {
    return _comments.where((c) => c['parent_id'] == parentId).toList();
  }

  void _startReply(int commentId, String userName) {
    setState(() {
      _replyToId = commentId;
      _replyToName = userName;
    });
    _focusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);

    final result = await PostService.addComment(
      widget.postId,
      content: text,
      parentId: _replyToId,
    );

    if (!mounted) return;

    if (result.success) {
      _commentController.clear();
      // Auto-expand the parent thread if replying
      if (_replyToId != null) {
        _expandedReplies.add(_replyToId!);
      }
      _cancelReply();
      _loadComments();
      widget.onCommentAdded?.call();
    }
    setState(() => _isSending = false);
  }

  // ── Color helpers for light/dark mode ──

  Color get _bgColor => widget.darkMode ? const Color(0xFF1A1A1A) : AppTheme.bg(context);
  Color get _bg2Color => widget.darkMode ? const Color(0xFF222222) : AppTheme.bg2(context);
  Color get _textColor => widget.darkMode ? Colors.white : AppTheme.text1(context);
  Color get _text2Color => widget.darkMode ? Colors.white70 : AppTheme.text2(context);
  Color get _mutedColor => widget.darkMode ? Colors.white38 : AppTheme.textMuted(context);
  Color get _borderColor => widget.darkMode ? Colors.white12 : AppTheme.glassBorder(context);
  Color get _inputBgColor => widget.darkMode ? const Color(0xFF333333) : AppTheme.glassBg(context);
  Color get _avatarBgColor => widget.darkMode ? Colors.grey[800]! : AppTheme.glassBg(context);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: widget.darkMode ? null : Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _mutedColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Comments',
                  style: GoogleFonts.jost(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Divider(color: _borderColor, height: 1),

              // Comments list
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.gold1,
                          strokeWidth: 2,
                        ),
                      )
                    : _comments.isEmpty
                        ? Center(
                            child: Text(
                              'No comments yet',
                              style: GoogleFonts.jost(
                                color: _mutedColor,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            itemCount: _getTopLevelComments().length,
                            itemBuilder: (_, i) {
                              final comment = _getTopLevelComments()[i];
                              return _buildCommentThread(comment);
                            },
                          ),
              ),

              // Reply indicator + Comment input
              _buildInputArea(),
            ],
          ),
        );
      },
    );
  }

  /// Builds a top-level comment with its nested replies.
  Widget _buildCommentThread(Map<String, dynamic> comment) {
    final commentId = comment['id'] as int;
    final replies = _getReplies(commentId);
    final isExpanded = _expandedReplies.contains(commentId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentTile(comment, isReply: false),

        // Show replies toggle
        if (replies.isNotEmpty) ...[
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedReplies.remove(commentId);
                } else {
                  _expandedReplies.add(commentId);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(left: 42, bottom: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 24,
                    height: 1,
                    color: _mutedColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isExpanded
                        ? 'Hide replies'
                        : 'View ${replies.length} ${replies.length == 1 ? 'reply' : 'replies'}',
                    style: GoogleFonts.jost(
                      color: _mutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: _mutedColor,
                  ),
                ],
              ),
            ),
          ),
        ],

        // Nested replies
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Column(
              children: replies
                  .map((reply) => _buildCommentTile(reply, isReply: true))
                  .toList(),
            ),
          ),
      ],
    );
  }

  /// Builds a single comment tile (works for both top-level and replies).
  Widget _buildCommentTile(Map<String, dynamic> comment, {required bool isReply}) {
    final user = comment['user'] as Map<String, dynamic>? ?? {};
    final name = user['name'] as String? ?? 'Anonymous';
    final userAvatar = (user['profile_image_url'] ?? user['profile_image']) as String?;
    final content = comment['content'] as String? ?? '';
    final createdAt = comment['created_at'] as String? ?? '';
    final commentId = comment['id'] as int;
    final timeAgo = _formatTimeAgo(createdAt);

    return Padding(
      padding: EdgeInsets.only(bottom: isReply ? 10 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: isReply ? 28 : 34,
            height: isReply ? 28 : 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _avatarBgColor,
              border: widget.darkMode ? null : Border.all(color: _borderColor),
            ),
            child: ClipOval(
              child: userAvatar != null && userAvatar.isNotEmpty
                  ? Image.network(
                      userAvatar.startsWith('http')
                          ? userAvatar
                          : '${ApiService.baseUrl}/$userAvatar',
                      width: isReply ? 28 : 34,
                      height: isReply ? 28 : 34,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(name, isReply),
                    )
                  : _avatarFallback(name, isReply),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + time
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.jost(
                        color: _text2Color,
                        fontSize: isReply ? 12 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (timeAgo.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        timeAgo,
                        style: GoogleFonts.jost(
                          color: _mutedColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                // Comment content
                Text(
                  content,
                  style: GoogleFonts.jost(
                    color: _textColor,
                    fontSize: isReply ? 12 : 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                // Reply button
                GestureDetector(
                  onTap: () => _startReply(commentId, name),
                  child: Text(
                    'Reply',
                    style: GoogleFonts.jost(
                      color: _mutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String name, bool isReply) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: GoogleFonts.jost(
          color: AppTheme.gold1,
          fontSize: isReply ? 11 : 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply indicator
        if (_replyToId != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: _bg2Color,
            child: Row(
              children: [
                Icon(Icons.reply_rounded, size: 16, color: AppTheme.gold1),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Replying to $_replyToName',
                    style: GoogleFonts.jost(
                      color: _text2Color,
                      fontSize: 13,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _cancelReply,
                  child: Icon(Icons.close, size: 18, color: _mutedColor),
                ),
              ],
            ),
          ),

        // Input field
        Container(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).viewPadding.bottom +
                12,
          ),
          decoration: BoxDecoration(
            color: _bg2Color,
            border: Border(
              top: BorderSide(color: _borderColor),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _focusNode,
                  style: GoogleFonts.jost(
                    color: _textColor,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: _replyToId != null
                        ? 'Reply to $_replyToName...'
                        : 'Write a comment...',
                    hintStyle: GoogleFonts.jost(
                      color: _mutedColor,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: _inputBgColor,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: widget.darkMode
                          ? BorderSide.none
                          : BorderSide(color: _borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: widget.darkMode
                          ? BorderSide.none
                          : BorderSide(color: _borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(
                        color: AppTheme.gold1.withValues(alpha: 0.4),
                      ),
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
                      : const Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: Color(0xFF1A1612),
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimeAgo(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}
