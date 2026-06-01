import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/notification_api_service.dart';
import '../theme/app_theme.dart';
import 'feed_screen.dart';
import 'user_profile_screen.dart';

/// Notification screen — modern list with avatars, action badges, and pagination.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  int _page = 1;
  int _total = 0;

  bool get _hasMore => _notifications.length < _total;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await NotificationApiService.getNotifications(page: 1);
    if (!mounted) return;
    setState(() {
      _notifications = result.notifications;
      _unreadCount = result.unreadCount;
      _total = result.total;
      _page = result.currentPage;
      _isLoading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    final next = _page + 1;
    final result = await NotificationApiService.getNotifications(page: next);
    if (!mounted) return;
    setState(() {
      _notifications.addAll(result.notifications);
      _page = result.currentPage;
      _total = result.total;
      _isLoadingMore = false;
    });
  }

  Future<void> _markAllRead() async {
    await NotificationApiService.markAllAsRead();
    if (!mounted) return;
    setState(() {
      _unreadCount = 0;
      for (final n in _notifications) {
        n['is_read'] = true;
      }
    });
  }

  Future<void> _delete(int index) async {
    final id = _notifications[index]['id'] as int?;
    if (id == null) return;
    final wasUnread = _isUnread(_notifications[index]);
    final success = await NotificationApiService.deleteNotification(id);
    if (success && mounted) {
      setState(() {
        _notifications.removeAt(index);
        if (wasUnread) _unreadCount = (_unreadCount - 1).clamp(0, 9999);
        _total = (_total - 1).clamp(0, 1 << 30);
      });
    }
  }

  Future<void> _markRead(int index) async {
    if (!_isUnread(_notifications[index])) return;
    final id = _notifications[index]['id'] as int?;
    if (id == null) return;
    await NotificationApiService.markAsRead(id);
    if (!mounted) return;
    setState(() {
      _notifications[index]['is_read'] = true;
      _unreadCount = (_unreadCount - 1).clamp(0, 9999);
    });
  }

  bool _isUnread(Map<String, dynamic> n) {
    final v = n['is_read'];
    if (v is bool) return !v;
    if (v is num) return v == 0;
    // Backward-compat with older payloads using read_at.
    return n['read_at'] == null;
  }

  // ── `related` payload accessors (rich notification data) ──
  Map<String, dynamic> _related(Map<String, dynamic> n) =>
      (n['related'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic>? _fromUser(Map<String, dynamic> n) =>
      (_related(n)['from_user'] as Map?)?.cast<String, dynamic>();
  Map<String, dynamic>? _relPost(Map<String, dynamic> n) =>
      (_related(n)['post'] as Map?)?.cast<String, dynamic>();
  Map<String, dynamic>? _relComment(Map<String, dynamic> n) =>
      (_related(n)['comment'] as Map?)?.cast<String, dynamic>();

  void _onTileTap(int index) {
    _markRead(index);
    final notif = _notifications[index];
    final type = (notif['type'] as String? ?? '').toLowerCase();
    final fromUser = _fromUser(notif);
    final data = notif['data'] as Map<String, dynamic>? ?? {};

    // Follow → go to the follower's profile.
    if (type.contains('follow')) {
      final userId = fromUser?['id'] ?? data['from_user_id'];
      if (userId != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(user: {
              'id': userId,
              'name': fromUser?['name'] ?? data['from_user_name'] ?? '',
              if (fromUser?['username'] != null) 'username': fromUser!['username'],
              if (fromUser?['profile_image_url'] != null)
                'profile_image_url': fromUser!['profile_image_url'],
              if (data['from_profile_image'] != null)
                'profile_image': data['from_profile_image'],
            }),
          ),
        );
      }
      return;
    }

    // Like / comment / repost / mention → open the related post.
    final postId = (_relPost(notif)?['id'] ?? data['post_id']) as int?;
    if (postId != null) {
      // Comment / reply → open the post with the comments sheet expanded.
      final openComments = type.contains('comment') || type.contains('reply');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FeedScreen(
            singlePostId: postId,
            openCommentsOnLoad: openComments,
          ),
        ),
      );
      return;
    }

    // Fallback → actor's profile.
    final userId = fromUser?['id'] ?? data['from_user_id'];
    if (userId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserProfileScreen(user: {
            'id': userId,
            'name': fromUser?['name'] ?? data['from_user_name'] ?? '',
          }),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final goldC = AppTheme.goldColor(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: AppTheme.text1(context), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('notifications'),
          style: GoogleFonts.cormorantGaramond(
            color: AppTheme.text1(context),
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text(
                l10n.translate('mark_all_read'),
                style: GoogleFonts.jost(color: goldC, fontSize: 12),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: goldC))
          : _notifications.isEmpty
              ? _emptyState(l10n)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: goldC,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (scroll) {
                      if (scroll.metrics.pixels >
                          scroll.metrics.maxScrollExtent - 200) {
                        _loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 8, 0, 90),
                      itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= _notifications.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: goldC,
                                ),
                              ),
                            ),
                          );
                        }
                        return _buildNotifTile(i);
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _emptyState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.notifications_none,
            size: 56,
            color: AppTheme.textMuted(context).withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.translate('no_notifications'),
            style: GoogleFonts.jost(
              color: AppTheme.textMuted(context),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotifTile(int index) {
    final notif = _notifications[index];
    final isUnread = _isUnread(notif);
    final type = (notif['type'] as String? ?? '').toLowerCase();
    final createdAt = notif['created_at'] as String? ?? '';

    final goldC = AppTheme.goldColor(context);
    final unreadBg = goldC.withValues(alpha: 0.06);
    final thumb = _buildPostThumb(notif);

    return Dismissible(
      key: ValueKey(notif['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => _delete(index),
      child: InkWell(
        onTap: () => _onTileTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isUnread ? unreadBg : Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatarWithBadge(notif, type),
              const SizedBox(width: 12),
              Expanded(child: _buildMessage(notif, type, createdAt, isUnread)),
              if (isUnread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: goldC,
                    shape: BoxShape.circle,
                  ),
                ),
              if (thumb != null) ...[
                const SizedBox(width: 4),
                thumb,
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Small post preview on the right (image/video thumbnail or text snippet).
  Widget? _buildPostThumb(Map<String, dynamic> notif) {
    final post = _relPost(notif);
    if (post == null) return null;

    final isVideo =
        (post['media_type'] as String?)?.toLowerCase().contains('video') ?? false;
    var url = (post['thumbnail_url'] as String?) ?? (post['media_url'] as String?);
    if (url != null && url.isNotEmpty && !url.startsWith('http')) {
      url = '${ApiService.baseUrl}/$url';
    }

    // Text-only post → show a content snippet box.
    if (url == null || url.isEmpty) {
      final content = (post['content'] as String?)?.trim() ?? '';
      if (content.isEmpty) return null;
      return Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.bg2(context),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.jost(
            color: AppTheme.textMuted(context),
            fontSize: 7,
            height: 1.2,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Stack(
        children: [
          Image.network(
            url,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            cacheWidth: 132,
            errorBuilder: (_, __, ___) => Container(
              width: 44,
              height: 44,
              color: AppTheme.bg2(context),
              child: Icon(Icons.image_outlined,
                  size: 18, color: AppTheme.textMuted(context)),
            ),
          ),
          if (isVideo)
            const Positioned(
              right: 2,
              bottom: 2,
              child: Icon(Icons.play_circle_fill, size: 14, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarWithBadge(Map<String, dynamic> notif, String type) {
    final data = notif['data'] as Map<String, dynamic>? ?? {};
    final fromUser = _fromUser(notif);
    final fromName = (fromUser?['name'] ?? data['from_user_name'] as String?)
            ?.toString()
            .trim() ??
        '';
    var avatar = (fromUser?['profile_image_url'] ??
            data['from_profile_image'] ??
            data['profile_image_url'] ??
            data['profile_image']) as String?;
    if (avatar != null && avatar.isNotEmpty && !avatar.startsWith('http')) {
      avatar = '${ApiService.baseUrl}/storage/$avatar';
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.glassBg(context),
            border: Border.all(
              color: AppTheme.goldColor(context).withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: ClipOval(
            child: avatar != null && avatar.isNotEmpty
                ? Image.network(
                    avatar,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    cacheWidth: 144,
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
                    errorBuilder: (_, __, ___) => _avatarFallback(fromName),
                  )
                : _avatarFallback(fromName),
          ),
        ),
        // Action-type badge bottom-right
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _badgeColor(type),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.bg(context), width: 2),
            ),
            child: Icon(_iconForType(type), size: 12, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _avatarFallback(String name) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Center(
      child: Text(
        letter,
        style: GoogleFonts.jost(
          color: AppTheme.goldColor(context),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMessage(
      Map<String, dynamic> notif, String type, String createdAt, bool isUnread) {
    final l10n = AppLocalizations.of(context)!;
    final data = notif['data'] as Map<String, dynamic>? ?? {};
    final fromUser = _fromUser(notif);
    final rawName =
        (fromUser?['name'] ?? data['from_user_name'] as String?)?.toString().trim();
    final name = (rawName == null || rawName.isEmpty)
        ? l10n.translate('notif_someone')
        : rawName;
    final action = _actionText(type, l10n);
    final timeAgo = _timeAgo(createdAt);

    // For comment/reply notifications, show the actual comment text.
    final comment = _relComment(notif);
    final commentText = (comment?['text'] as String?)?.trim();

    // Post engagement stats (likes/comments on the related post).
    final post = _relPost(notif);
    final likes = post != null ? _intOr(post['likes_count']) : null;
    final comments = post != null ? _intOr(post['comments_count']) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: name,
                style: GoogleFonts.jost(
                  color: AppTheme.text1(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: ' $action',
                style: GoogleFonts.jost(
                  color: AppTheme.text1(context),
                  fontSize: 14,
                  fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                  height: 1.35,
                ),
              ),
              if (commentText != null && commentText.isNotEmpty)
                TextSpan(
                  text: ' "$commentText"',
                  style: GoogleFonts.jost(
                    color: AppTheme.text2(context),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    height: 1.35,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              timeAgo,
              style: GoogleFonts.jost(
                color: AppTheme.textMuted(context),
                fontSize: 11,
              ),
            ),
            if (post != null && (likes! > 0 || comments! > 0)) ...[
              const SizedBox(width: 8),
              Icon(Icons.favorite, size: 11, color: AppTheme.textMuted(context)),
              const SizedBox(width: 2),
              Text(
                '$likes',
                style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 11),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chat_bubble_outline, size: 11, color: AppTheme.textMuted(context)),
              const SizedBox(width: 2),
              Text(
                '${comments ?? 0}',
                style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 11),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Defensive int read — counts may arrive as int or string.
  int _intOr(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _actionText(String type, AppLocalizations l10n) {
    if (type.contains('like') || type.contains('reaction')) {
      return l10n.translate('notif_action_liked');
    }
    if (type.contains('comment')) return l10n.translate('notif_action_commented');
    if (type.contains('follow')) return l10n.translate('notif_action_followed');
    if (type.contains('repost')) return l10n.translate('notif_action_reposted');
    if (type.contains('mention')) return l10n.translate('notif_action_mentioned');
    return l10n.translate('notif_action_default');
  }

  IconData _iconForType(String type) {
    if (type.contains('like') || type.contains('reaction')) return Icons.favorite;
    if (type.contains('comment')) return Icons.chat_bubble;
    if (type.contains('follow')) return Icons.person_add;
    if (type.contains('repost')) return Icons.repeat;
    if (type.contains('mention')) return Icons.alternate_email;
    return Icons.notifications;
  }

  Color _badgeColor(String type) {
    if (type.contains('like') || type.contains('reaction')) return Colors.redAccent;
    if (type.contains('comment')) return const Color(0xFF3897F0);
    if (type.contains('follow')) return AppTheme.goldColor(context);
    if (type.contains('repost')) return const Color(0xFF2EBD85);
    if (type.contains('mention')) return const Color(0xFF7E57C2);
    return AppTheme.goldColor(context);
  }

  String _timeAgo(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 6) {
      final weeks = (diff.inDays / 7).floor();
      return '${weeks}w';
    }
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return AppLocalizations.of(context)!.translate('just_now');
  }
}
