import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../l10n/app_localizations.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';

/// Instagram-style share bottom sheet.
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
    AppTheme.showSnackBar(context, AppLocalizations.of(context)!.translate('link_copied'));
  }

  Future<void> _shareExternal() async {
    if (_shareLink.isEmpty) return;
    await SharePlus.instance.share(ShareParams(text: _shareLink));
    if (!mounted) return;
    Navigator.pop(context);
  }

  // ── Color helpers ──
  Color get _bgColor =>
      widget.darkMode ? const Color(0xFF1A1A1A) : AppTheme.bg(context);
  Color get _textColor =>
      widget.darkMode ? Colors.white : AppTheme.text1(context);
  Color get _mutedColor =>
      widget.darkMode ? Colors.white70 : AppTheme.textMuted(context);
  Color get _borderColor =>
      widget.darkMode ? Colors.white12 : AppTheme.glassBorder(context);
  Color get _tileBgColor =>
      widget.darkMode ? const Color(0xFF2A2A2A) : AppTheme.moodCardBg(context);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.7,
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
                  l10n.translate('share'),
                  style: GoogleFonts.jost(
                    color: _textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            children: [
                              // Share link preview
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: _tileBgColor,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.link,
                                        color: AppTheme.gold1, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _shareLink,
                                        style: GoogleFonts.jost(
                                          color: _mutedColor,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Action buttons row
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildShareAction(
                                    icon: Icons.copy_rounded,
                                    label: l10n.translate('copy_link'),
                                    color: AppTheme.gold1,
                                    onTap: _copyLink,
                                  ),
                                  _buildShareAction(
                                    icon: Icons.share_rounded,
                                    label: l10n.translate('share'),
                                    color: const Color(0xFF3897F0),
                                    onTap: _shareExternal,
                                  ),
                                ],
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

  Widget _buildShareAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.jost(
              color: _textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
