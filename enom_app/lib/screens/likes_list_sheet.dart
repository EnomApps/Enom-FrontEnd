import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../services/social_service.dart';
import '../theme/app_theme.dart';
import 'user_profile_screen.dart';

/// Instagram-style "Likes and plays" bottom sheet.
///
/// Shows a stats row (likes + views), a searchable list of users who liked
/// the post, and a Follow button next to each user (except the current user,
/// who instead gets an unlike control).
class LikesListSheet extends StatefulWidget {
  final int postId;
  final bool darkMode;

  /// Likes count to display in the stats row (caller's current state).
  final int likesCount;

  /// Views count to display in the stats row (caller's current state).
  final int viewsCount;

  /// Called when the current user unlikes the post from this sheet.
  final VoidCallback? onUnliked;

  const LikesListSheet({
    super.key,
    required this.postId,
    this.darkMode = false,
    this.likesCount = 0,
    this.viewsCount = 0,
    this.onUnliked,
  });

  /// Show the likes list as a bottom sheet.
  static void show(
    BuildContext context,
    int postId, {
    bool darkMode = false,
    int likesCount = 0,
    int viewsCount = 0,
    VoidCallback? onUnliked,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LikesListSheet(
        postId: postId,
        darkMode: darkMode,
        likesCount: likesCount,
        viewsCount: viewsCount,
        onUnliked: onUnliked,
      ),
    );
  }

  @override
  State<LikesListSheet> createState() => _LikesListSheetState();
}

class _LikesListSheetState extends State<LikesListSheet> {
  List<Map<String, dynamic>> _reactions = [];
  final Map<int, bool> _followStates = {}; // userId → isFollowing
  bool _isLoading = true;
  int? _currentUserId;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadReactions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

    final reactions = result.reactions.whereType<Map<String, dynamic>>().toList();
    setState(() {
      _isLoading = false;
      _reactions = reactions;
    });

    // Batch-load follow status for everyone in the list (except self).
    final userIds = <int>[];
    for (final r in reactions) {
      final user = r['user'] as Map<String, dynamic>? ?? r;
      final uid = (user['id'] ?? r['user_id']) as int?;
      if (uid != null && uid != _currentUserId) userIds.add(uid);
    }
    if (userIds.isEmpty) return;

    final statuses = await SocialService.batchFollowStatus(userIds);
    if (!mounted) return;
    setState(() => _followStates.addAll(statuses));
  }

  Future<void> _toggleFollow(int userId) async {
    final was = _followStates[userId] ?? false;
    setState(() => _followStates[userId] = !was);

    final result = await SocialService.toggleFollow(userId);
    if (!mounted) return;
    if (result.success) {
      setState(() => _followStates[userId] = result.isFollowing);
    } else {
      setState(() => _followStates[userId] = was);
    }
  }

  Future<void> _unlikePost(int index) async {
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
  Color get _searchBgColor => widget.darkMode
      ? Colors.white.withValues(alpha: 0.08)
      : AppTheme.glassBg(context);

  String _getReactionEmoji(String? type) {
    switch (type) {
      case 'love':
        return '❤️';
      case 'haha':
        return '😂';
      case 'wow':
        return '😮';
      case 'like':
      default:
        return '❤️';
    }
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return '$count';
  }

  List<Map<String, dynamic>> get _filteredReactions {
    if (_searchQuery.isEmpty) return _reactions;
    final q = _searchQuery.toLowerCase();
    return _reactions.where((r) {
      final user = r['user'] as Map<String, dynamic>? ?? r;
      final name = (user['name'] ?? r['name'] ?? '').toString().toLowerCase();
      final username =
          (user['username'] ?? r['username'] ?? '').toString().toLowerCase();
      return name.contains(q) || username.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
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

              // Title: "Likes and plays"
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.translate('likes_and_plays'),
                  style: GoogleFonts.jost(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Stats row: ❤ likes  👁 views
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.favorite_border,
                        size: 18, color: _textColor),
                    const SizedBox(width: 6),
                    Text(
                      _formatCount(widget.likesCount),
                      style: GoogleFonts.jost(
                        color: _textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Icon(Icons.visibility_outlined,
                        size: 18, color: _textColor),
                    const SizedBox(width: 6),
                    Text(
                      _formatCount(widget.viewsCount),
                      style: GoogleFonts.jost(
                        color: _textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: _borderColor, height: 1),

              // "Liked by" header
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    l10n.translate('liked_by'),
                    style: GoogleFonts.jost(
                      color: _textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              // Search field
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: _searchBgColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                    style: GoogleFonts.jost(
                      color: _textColor,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.translate('search'),
                      hintStyle: GoogleFonts.jost(
                        color: _mutedColor,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(Icons.search,
                          size: 20, color: _mutedColor),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      isDense: true,
                    ),
                  ),
                ),
              ),

              // List
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.gold1,
                          strokeWidth: 2,
                        ),
                      )
                    : _filteredReactions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _searchQuery.isEmpty
                                      ? Icons.favorite_border
                                      : Icons.search_off,
                                  size: 48,
                                  color: _mutedColor,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _searchQuery.isEmpty
                                      ? l10n.translate('no_likes_yet')
                                      : l10n.translate('no_results'),
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
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: _filteredReactions.length,
                            itemBuilder: (_, i) {
                              final reaction = _filteredReactions[i];
                              // We need the index from _reactions, not the
                              // filtered list, so unlike removes the right one.
                              final originalIndex = _reactions.indexOf(reaction);
                              return _buildReactionTile(reaction, originalIndex);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReactionTile(Map<String, dynamic> reaction, int index) {
    final l10n = AppLocalizations.of(context)!;
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
    final isFollowing = userId != null && (_followStates[userId] ?? false);

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
                            errorBuilder: (_, __, ___) => _avatarFallback(name),
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
                    username.isNotEmpty ? username : name,
                    style: GoogleFonts.jost(
                      color: _textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (name.isNotEmpty && username.isNotEmpty)
                    Text(
                      name,
                      style: GoogleFonts.jost(
                        color: _text2Color,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),
          // Self → small unlike control; others → Follow / Following button.
          if (isCurrentUser)
            GestureDetector(
              onTap: () => _unlikePost(index),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _mutedColor.withValues(alpha: 0.4),
                  ),
                ),
                child: const Icon(
                  Icons.favorite,
                  size: 20,
                  color: Colors.redAccent,
                ),
              ),
            )
          else if (userId != null)
            _FollowPill(
              isFollowing: isFollowing,
              onTap: () => _toggleFollow(userId),
              label: isFollowing
                  ? l10n.translate('following')
                  : l10n.translate('follow'),
              darkMode: widget.darkMode,
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

class _FollowPill extends StatelessWidget {
  final bool isFollowing;
  final VoidCallback onTap;
  final String label;
  final bool darkMode;

  const _FollowPill({
    required this.isFollowing,
    required this.onTap,
    required this.label,
    required this.darkMode,
  });

  @override
  Widget build(BuildContext context) {
    final goldC = AppTheme.goldColor(context);
    final filledBg = goldC;
    final outlineBg = darkMode
        ? Colors.white.withValues(alpha: 0.06)
        : AppTheme.glassBg(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isFollowing ? outlineBg : filledBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isFollowing
                ? (darkMode
                    ? Colors.white24
                    : AppTheme.glassBorder(context))
                : filledBg,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.jost(
            color: isFollowing
                ? (darkMode ? Colors.white : AppTheme.text1(context))
                : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
