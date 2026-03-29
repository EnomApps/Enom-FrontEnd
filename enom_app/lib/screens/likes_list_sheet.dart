import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';
import 'user_profile_screen.dart';

/// Instagram-style bottom sheet showing who liked/reacted to a post.
class LikesListSheet extends StatefulWidget {
  final int postId;
  final bool darkMode;

  /// Called when the current user unlikes the post from this sheet.
  final VoidCallback? onUnliked;

  const LikesListSheet({
    super.key,
    required this.postId,
    this.darkMode = false,
    this.onUnliked,
  });

  /// Show the likes list as a bottom sheet.
  static void show(BuildContext context, int postId,
      {bool darkMode = false, VoidCallback? onUnliked}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LikesListSheet(
        postId: postId,
        darkMode: darkMode,
        onUnliked: onUnliked,
      ),
    );
  }

  @override
  State<LikesListSheet> createState() => _LikesListSheetState();
}

class _LikesListSheetState extends State<LikesListSheet> {
  List<Map<String, dynamic>> _reactions = [];
  bool _isLoading = true;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadReactions();
  }

  Future<void> _loadCurrentUser() async {
    final user = await ApiService.getUser();
    if (!mounted) return;
    setState(() {
      _currentUserId = user?['id'] as int?;
    });
  }

  Future<void> _loadReactions() async {
    final result = await PostService.getReactions(widget.postId);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _reactions = result.reactions
          .whereType<Map<String, dynamic>>()
          .toList();
    });

    debugPrint('[LikesListSheet] loaded ${_reactions.length} reactions: $_reactions');
  }

  Future<void> _unlikePost(int index) async {
    final reaction = _reactions[index];
    setState(() {
      _reactions.removeAt(index);
    });

    await PostService.toggleReaction(widget.postId, 'like');
    widget.onUnliked?.call();

    if (!mounted) return;
    if (_reactions.isEmpty) {
      Navigator.of(context).pop();
    }
  }

  // ── Color helpers ──
  Color get _bgColor =>
      widget.darkMode ? const Color(0xFF1A1A1A) : AppTheme.bg(context);
  Color get _textColor =>
      widget.darkMode ? Colors.white : AppTheme.text1(context);
  Color get _text2Color =>
      widget.darkMode ? Colors.white : AppTheme.text2(context);
  Color get _mutedColor =>
      widget.darkMode ? Colors.white70 : AppTheme.textMuted(context);
  Color get _borderColor =>
      widget.darkMode ? Colors.white12 : AppTheme.glassBorder(context);
  Color get _avatarBgColor =>
      widget.darkMode ? Colors.grey[800]! : AppTheme.glassBg(context);

  String _getReactionEmoji(String? type) {
    switch (type) {
      case 'love':
        return '\u2764\uFE0F';
      case 'haha':
        return '\uD83D\uDE02';
      case 'wow':
        return '\uD83D\uDE2E';
      case 'like':
      default:
        return '\u2764\uFE0F';
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
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
                  'Likes',
                  style: GoogleFonts.jost(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Divider(color: _borderColor, height: 1),

              // List
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.gold1,
                          strokeWidth: 2,
                        ),
                      )
                    : _reactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.favorite_border,
                                    size: 48, color: _mutedColor),
                                const SizedBox(height: 12),
                                Text(
                                  'No likes yet',
                                  style: GoogleFonts.jost(
                                    color: _mutedColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: _reactions.length,
                            itemBuilder: (_, i) =>
                                _buildReactionTile(_reactions[i], i),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReactionTile(Map<String, dynamic> reaction, int index) {
    // Support both nested user object and flat structure
    final user = reaction['user'] as Map<String, dynamic>? ?? reaction;
    final name = (user['name'] ?? reaction['name'] ?? 'Anonymous') as String;
    final username = (user['username'] ?? reaction['username'] ?? '') as String;
    final userId = (user['id'] ?? reaction['user_id']) as int?;
    var avatar =
        (user['profile_image_url'] ?? user['profile_image']) as String?;
    // Same URL pattern as profile screen
    if (avatar != null && avatar.isNotEmpty && !avatar.startsWith('http')) {
      avatar = '${ApiService.baseUrl}/storage/$avatar';
    }
    final reactionType = reaction['type'] as String? ?? 'like';
    final emoji = _getReactionEmoji(reactionType);
    final isCurrentUser = _currentUserId != null && userId == _currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Avatar with reaction badge
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(user: user),
              ),
            ),
            child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _avatarBgColor,
                  border: Border.all(
                    color: widget.darkMode
                        ? Colors.white12
                        : AppTheme.goldColor(context).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: ClipOval(
                  child: avatar != null && avatar.isNotEmpty
                      ? Image.network(
                          avatar,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          cacheWidth: 120,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppTheme.gold1,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) =>
                              _avatarFallback(name),
                        )
                      : _avatarFallback(name),
                ),
              ),
              // Reaction emoji badge
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: _bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
          ),
          const SizedBox(width: 12),
          // Name + username
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(
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
                      color: _textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (username.isNotEmpty)
                    Text(
                      '@$username',
                      style: GoogleFonts.jost(
                        color: _text2Color,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Unlike button — only for current user's like
          if (isCurrentUser)
            GestureDetector(
              onTap: () => _unlikePost(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _mutedColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Icon(
                  Icons.favorite,
                  size: 20,
                  color: Colors.redAccent,
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
          color: AppTheme.gold1,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
