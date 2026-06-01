import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/social_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'user_profile_screen.dart';

/// Your private "Favourites" (close friends) list — GET /api/favourites.
/// Tap a star to remove someone; tap a row to open their profile.
class FavouriteUsersScreen extends StatefulWidget {
  const FavouriteUsersScreen({super.key});

  @override
  State<FavouriteUsersScreen> createState() => _FavouriteUsersScreenState();
}

class _FavouriteUsersScreenState extends State<FavouriteUsersScreen> {
  final List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final users = await SocialService.getFavouriteUsers();
    if (!mounted) return;
    setState(() {
      _users
        ..clear()
        ..addAll(users);
      _loading = false;
    });
  }

  Future<void> _removeFavourite(int userId) async {
    final removed = _users.firstWhere((u) => u['id'] == userId, orElse: () => {});
    setState(() => _users.removeWhere((u) => u['id'] == userId));
    final result = await SocialService.toggleFavourite(userId);
    // If it somehow turned the user back into a favourite, restore the row.
    if (mounted && result.success && result.isFavourite && removed.isNotEmpty) {
      setState(() => _users.add(removed));
    }
  }

  String? _avatarUrl(Map<String, dynamic> person) {
    var url = person['profile_image_url'] as String? ?? person['profile_image'] as String?;
    if (url == null || url.isEmpty) return null;
    if (!url.startsWith('http')) url = '${ApiService.baseUrl}/storage/$url';
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        backgroundColor: AppTheme.bg(context),
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.text1(context)),
        title: Text(
          l10n.translate('favourites'),
          style: GoogleFonts.jost(
            color: AppTheme.text1(context),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.goldColor(context)))
          : _users.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_border,
                          size: 56,
                          color: AppTheme.goldColor(context).withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        l10n.translate('no_favourites_yet'),
                        style: AppTheme.heading(context, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          l10n.translate('favourites_hint'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jost(
                              color: AppTheme.textMuted(context), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.goldColor(context),
                  child: ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (_, i) => _buildUserTile(_users[i]),
                  ),
                ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> person) {
    final id = person['id'] as int?;
    final name = (person['name'] as String?)?.trim();
    final username = (person['username'] as String?)?.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : (username != null && username.isNotEmpty ? username : 'Enom user');
    final avatarUrl = _avatarUrl(person);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserProfileScreen(user: person)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.goldColor(context).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: avatarUrl != null
                    ? Image.network(
                        avatarUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        cacheWidth: 150,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppTheme.bg2(context),
                          child: Icon(Icons.person,
                              size: 28, color: AppTheme.goldColor(context)),
                        ),
                      )
                    : Container(
                        color: AppTheme.bg2(context),
                        child: Icon(Icons.person,
                            size: 28, color: AppTheme.goldColor(context)),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (username != null && username.isNotEmpty)
                    Text(
                      '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.jost(
                        color: AppTheme.textMuted(context),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.star, color: AppTheme.goldColor(context), size: 24),
              onPressed: id == null ? null : () => _removeFavourite(id),
            ),
          ],
        ),
      ),
    );
  }
}
