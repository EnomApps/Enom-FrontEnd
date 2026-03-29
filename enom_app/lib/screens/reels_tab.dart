import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';
import 'feed_reels_screen.dart';

/// Standalone Reels tab that loads all posts and shows them in TikTok/Reels style.
class ReelsTab extends StatefulWidget {
  const ReelsTab({super.key});

  @override
  State<ReelsTab> createState() => _ReelsTabState();
}

class _ReelsTabState extends State<ReelsTab> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final result = await PostService.getFeed();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      // Only show posts that have media (images/videos)
      _posts = result.posts
          .whereType<Map<String, dynamic>>()
          .where((post) {
            final media = post['media'] as List<dynamic>? ?? [];
            return media.isNotEmpty;
          })
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppTheme.goldColor(context),
          strokeWidth: 2,
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Text(
          'No posts yet',
          style: GoogleFonts.jost(
            color: AppTheme.textMuted(context),
            fontSize: 14,
          ),
        ),
      );
    }

    final bottomNavHeight = kBottomNavigationBarHeight + MediaQuery.of(context).viewPadding.bottom;
    return FeedReelsScreen(
      videoPosts: _posts,
      initialIndex: 0,
      showBackButton: false,
      bottomPadding: bottomNavHeight,
    );
  }
}
