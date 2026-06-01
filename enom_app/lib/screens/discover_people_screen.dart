import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/social_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'user_profile_screen.dart';

/// Full "Discover people" list (the "See all" destination): a vertical list of
/// suggested users with avatar, name, reason, and a Follow toggle.
class DiscoverPeopleScreen extends StatefulWidget {
  const DiscoverPeopleScreen({super.key});

  @override
  State<DiscoverPeopleScreen> createState() => _DiscoverPeopleScreenState();
}

class _DiscoverPeopleScreenState extends State<DiscoverPeopleScreen> {
  final List<Map<String, dynamic>> _people = [];
  final Set<int> _following = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final people = await SocialService.getDiscoverPeople(limit: 50);
    if (!mounted) return;
    setState(() {
      _people
        ..clear()
        ..addAll(people);
      _loading = false;
    });
  }

  Future<void> _toggleFollow(int userId) async {
    final wasFollowing = _following.contains(userId);
    setState(() {
      if (wasFollowing) {
        _following.remove(userId);
      } else {
        _following.add(userId);
      }
    });
    final result = await SocialService.toggleFollow(userId);
    if (mounted && !result.success) {
      setState(() {
        if (wasFollowing) {
          _following.add(userId);
        } else {
          _following.remove(userId);
        }
      });
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
          l10n.translate('discover_people'),
          style: GoogleFonts.jost(
            color: AppTheme.text1(context),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.goldColor(context)),
            )
          : _people.isEmpty
              ? Center(
                  child: Text(
                    l10n.translate('no_suggestions_yet'),
                    style: GoogleFonts.jost(
                        color: AppTheme.textMuted(context), fontSize: 14),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppTheme.goldColor(context),
                  child: ListView.builder(
                    itemCount: _people.length,
                    itemBuilder: (_, i) => _buildPersonTile(_people[i]),
                  ),
                ),
    );
  }

  Widget _buildPersonTile(Map<String, dynamic> person) {
    final l10n = AppLocalizations.of(context)!;
    final id = person['id'] as int?;
    final name = (person['name'] as String?)?.trim();
    final username = (person['username'] as String?)?.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : (username != null && username.isNotEmpty ? username : 'Enom user');
    final reason = (person['reason'] as String?)?.trim();
    final avatarUrl = _avatarUrl(person);
    final isFollowing = id != null && _following.contains(id);

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
                  if (reason != null && reason.isNotEmpty)
                    Text(
                      reason,
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
            const SizedBox(width: 10),
            GestureDetector(
              onTap: id == null ? null : () => _toggleFollow(id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: isFollowing ? Colors.transparent : AppTheme.goldColor(context),
                  borderRadius: BorderRadius.circular(8),
                  border: isFollowing
                      ? Border.all(color: AppTheme.glassBorder(context))
                      : null,
                ),
                child: Text(
                  isFollowing ? l10n.translate('following') : l10n.translate('follow'),
                  style: GoogleFonts.jost(
                    color: isFollowing
                        ? AppTheme.text1(context)
                        : const Color(0xFF1A1612),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
