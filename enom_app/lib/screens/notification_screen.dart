import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_api_service.dart';
import '../theme/app_theme.dart';

/// Notification screen — lists all user notifications with mark-read & delete.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = true;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final result = await NotificationApiService.getNotifications(page: 1);
    if (mounted) {
      setState(() {
        _notifications = result.notifications;
        _unreadCount = result.unreadCount;
        _isLoading = false;
        _page = 1;
        _hasMore = result.notifications.length >= 15;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore) return;
    final next = _page + 1;
    final result = await NotificationApiService.getNotifications(page: next);
    if (mounted) {
      setState(() {
        _notifications.addAll(result.notifications);
        _page = next;
        _hasMore = result.notifications.length >= 15;
      });
    }
  }

  Future<void> _markAllRead() async {
    await NotificationApiService.markAllAsRead();
    if (mounted) {
      setState(() {
        _unreadCount = 0;
        for (final n in _notifications) {
          n['read_at'] = DateTime.now().toIso8601String();
        }
      });
    }
  }

  Future<void> _delete(int index) async {
    final id = _notifications[index]['id'] as int?;
    if (id == null) return;
    final success = await NotificationApiService.deleteNotification(id);
    if (success && mounted) {
      setState(() => _notifications.removeAt(index));
    }
  }

  Future<void> _markRead(int index) async {
    final id = _notifications[index]['id'] as int?;
    if (id == null) return;
    await NotificationApiService.markAsRead(id);
    if (mounted) {
      setState(() {
        _notifications[index]['read_at'] = DateTime.now().toIso8601String();
        _unreadCount = (_unreadCount - 1).clamp(0, 999);
      });
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
            fontSize: 22, fontWeight: FontWeight.w600,
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
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 56, color: AppTheme.textMuted(context).withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        l10n.translate('no_notifications'),
                        style: GoogleFonts.jost(
                          color: AppTheme.textMuted(context), fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: goldC,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (scroll) {
                      if (scroll.metrics.pixels > scroll.metrics.maxScrollExtent - 200) {
                        _loadMore();
                      }
                      return false;
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 90),
                      itemCount: _notifications.length,
                      itemBuilder: (_, i) => _buildNotifTile(i),
                    ),
                  ),
                ),
    );
  }

  Widget _buildNotifTile(int index) {
    final notif = _notifications[index];
    final isRead = notif['read_at'] != null;
    final message = notif['message'] as String? ??
        notif['data']?['message'] as String? ?? '';
    final type = notif['type'] as String? ?? '';
    final createdAt = notif['created_at'] as String? ?? '';

    return Dismissible(
      key: ValueKey(notif['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _delete(index),
      child: GestureDetector(
        onTap: () => _markRead(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isRead
                ? Colors.transparent
                : AppTheme.goldColor(context).withValues(alpha: 0.04),
            border: Border(
              bottom: BorderSide(color: AppTheme.glassBorder(context), width: 0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.glassBg(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForType(type),
                  size: 20,
                  color: isRead ? AppTheme.textMuted(context) : AppTheme.goldColor(context),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message,
                      style: GoogleFonts.jost(
                        color: AppTheme.text1(context),
                        fontSize: 13,
                        fontWeight: isRead ? FontWeight.w400 : FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _timeAgo(createdAt),
                      style: GoogleFonts.jost(
                        color: AppTheme.textMuted(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              // Unread dot
              if (!isRead)
                Container(
                  width: 8, height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.goldColor(context),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    if (type.contains('like') || type.contains('reaction')) return Icons.favorite;
    if (type.contains('comment')) return Icons.chat_bubble_outline;
    if (type.contains('follow')) return Icons.person_add;
    if (type.contains('repost')) return Icons.repeat;
    if (type.contains('mention')) return Icons.alternate_email;
    return Icons.notifications_outlined;
  }

  String _timeAgo(String dateStr) {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'now';
  }
}
