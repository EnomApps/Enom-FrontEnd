import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';

/// TikTok-style share bottom sheet.
class ShareSheet extends StatefulWidget {
  final int postId;
  final bool darkMode;

  const ShareSheet({
    super.key,
    required this.postId,
    this.darkMode = false,
  });

  /// Show the share sheet as a modal bottom sheet.
  static void show(BuildContext context, int postId, {bool darkMode = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareSheet(postId: postId, darkMode: darkMode),
    );
  }

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  bool _isLoading = true;
  String _shareLink = '';

  @override
  void initState() {
    super.initState();
    _loadShareLink();
  }

  Future<void> _loadShareLink() async {
    final result = await PostService.getShareLink(widget.postId);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _shareLink = result.link;
    });
  }

  Future<void> _copyLink() async {
    if (_shareLink.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _shareLink));
    if (!mounted) return;
    Navigator.pop(context);
    AppTheme.showSnackBar(
      context,
      AppLocalizations.of(context)!.translate('link_copied'),
    );
  }

  Future<void> _shareExternal() async {
    if (_shareLink.isEmpty) return;
    await SharePlus.instance.share(ShareParams(text: _shareLink));
    if (!mounted) return;
    Navigator.pop(context);
  }

  /// Open a URL in its native app when installed, browser otherwise. Closes
  /// the sheet on success; shows a snackbar if nothing can handle the URI.
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      if (launched) {
        Navigator.pop(context);
      } else {
        AppTheme.showSnackBar(context, 'No app available to open this link');
      }
    } catch (_) {
      if (!mounted) return;
      AppTheme.showSnackBar(context, 'No app available to open this link');
    }
  }

  // ── Brand-target handlers ──
  String get _encoded => Uri.encodeComponent(_shareLink);
  void _shareWhatsApp() => _openUrl('https://wa.me/?text=$_encoded');
  void _shareFacebook() =>
      _openUrl('https://www.facebook.com/sharer/sharer.php?u=$_encoded');
  void _shareTelegram() => _openUrl('https://t.me/share/url?url=$_encoded');
  void _shareTwitter() =>
      _openUrl('https://twitter.com/intent/tweet?url=$_encoded');
  void _shareSms() => _openUrl('sms:?body=$_encoded');
  void _shareEmail() =>
      _openUrl('mailto:?subject=Check%20this%20out&body=$_encoded');

  // ── Color helpers ──
  Color get _bgColor =>
      widget.darkMode ? const Color(0xFF1A1A1A) : AppTheme.bg(context);
  Color get _textColor =>
      widget.darkMode ? Colors.white : AppTheme.text1(context);
  Color get _mutedColor =>
      widget.darkMode ? Colors.white70 : AppTheme.textMuted(context);
  Color get _borderColor =>
      widget.darkMode ? Colors.white12 : AppTheme.glassBorder(context);

  List<_ShareTarget> get _targets => [
        _ShareTarget(
          icon: Icons.chat_bubble,
          color: const Color(0xFF25D366),
          label: 'WhatsApp',
          onTap: _shareWhatsApp,
        ),
        _ShareTarget(
          icon: Icons.facebook,
          color: const Color(0xFF1877F2),
          label: 'Facebook',
          onTap: _shareFacebook,
        ),
        _ShareTarget(
          icon: Icons.send_rounded,
          color: const Color(0xFF0088CC),
          label: 'Telegram',
          onTap: _shareTelegram,
        ),
        _ShareTarget(
          icon: Icons.alternate_email,
          color: Colors.black,
          label: 'X',
          onTap: _shareTwitter,
        ),
        _ShareTarget(
          icon: Icons.sms_rounded,
          color: const Color(0xFF34C759),
          label: 'SMS',
          onTap: _shareSms,
        ),
        _ShareTarget(
          icon: Icons.email_rounded,
          color: const Color(0xFFEA4335),
          label: 'Email',
          onTap: _shareEmail,
        ),
        _ShareTarget(
          icon: Icons.link_rounded,
          color: AppTheme.gold1,
          label: 'Copy link',
          onTap: _copyLink,
        ),
        _ShareTarget(
          icon: Icons.share_rounded,
          color: const Color(0xFF6C7280),
          label: 'More',
          onTap: _shareExternal,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.32,
      minChildSize: 0.25,
      maxChildSize: 0.6,
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
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _mutedColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title + close
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 24),
                    Expanded(
                      child: Text(
                        l10n.translate('share'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.jost(
                          color: _textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close_rounded,
                          color: _textColor, size: 22),
                    ),
                  ],
                ),
              ),
              Divider(color: _borderColor, height: 1),

              // Content
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.gold1,
                          strokeWidth: 2,
                        ),
                      )
                    : _shareLink.isEmpty
                        ? Center(
                            child: Text(
                              'Unable to get share link',
                              style: GoogleFonts.jost(
                                color: _mutedColor,
                                fontSize: 14,
                              ),
                            ),
                          )
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            children: [
                              SizedBox(
                                height: 96,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                  ),
                                  itemCount: _targets.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 18),
                                  itemBuilder: (_, i) =>
                                      _buildTargetTile(_targets[i]),
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

  Widget _buildTargetTile(_ShareTarget t) {
    return GestureDetector(
      onTap: t.onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.color,
              ),
              child: Icon(t.icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              t.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.jost(
                color: _textColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareTarget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ShareTarget({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
}
