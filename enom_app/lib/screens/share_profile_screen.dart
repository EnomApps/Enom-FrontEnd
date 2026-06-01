import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import '../services/api_service.dart';
import '../services/social_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Instagram-style "Share profile" screen: a scannable QR card for the profile,
/// plus Share / Copy link / Download actions.
class ShareProfileScreen extends StatefulWidget {
  const ShareProfileScreen({super.key, required this.user});

  final Map<String, dynamic> user;

  @override
  State<ShareProfileScreen> createState() => _ShareProfileScreenState();
}

class _ShareProfileScreenState extends State<ShareProfileScreen> {
  final GlobalKey _cardKey = GlobalKey();
  String? _shareLink;
  bool _loadingLink = true;
  int _themeIndex = 0;

  /// Color themes cycled by tapping the QR card / COLOR pill (Instagram-style).
  /// Each theme is the card gradient plus the QR + text colors that stay
  /// readable on it.
  static const List<_QrTheme> _themes = [
    _QrTheme([Colors.white, Colors.white], Colors.black, Colors.black),
    _QrTheme([Color(0xFFD4AF37), Color(0xFFF9D976)], Colors.black, Colors.black),
    _QrTheme([Color(0xFF833AB4), Color(0xFFFD1D1D)], Colors.white, Colors.white),
    _QrTheme([Color(0xFF2196F3), Color(0xFF00C6FB)], Colors.white, Colors.white),
    _QrTheme([Color(0xFFFF8008), Color(0xFFFFC837)], Colors.white, Colors.white),
    _QrTheme([Color(0xFF11998E), Color(0xFF38EF7D)], Colors.white, Colors.white),
    _QrTheme([Color(0xFF232526), Color(0xFF414345)], Colors.white, Colors.white),
  ];

  _QrTheme get _theme => _themes[_themeIndex];

  void _cycleColor() {
    setState(() => _themeIndex = (_themeIndex + 1) % _themes.length);
  }

  @override
  void initState() {
    super.initState();
    _loadShareLink();
  }

  int? get _userId => widget.user['id'] as int?;

  String get _handle {
    final username = (widget.user['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) return username;
    final name = (widget.user['name'] as String?)?.trim();
    return name != null && name.isNotEmpty ? name : 'enom';
  }

  /// Fallback profile URL when the backend share-link endpoint is unavailable.
  String get _fallbackLink {
    final id = _userId;
    final username = (widget.user['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) {
      return '${ApiService.baseUrl}/u/$username';
    }
    return '${ApiService.baseUrl}/users/$id';
  }

  Future<void> _loadShareLink() async {
    String? link;
    if (_userId != null) {
      link = await SocialService.getProfileShareLink(_userId!);
    }
    if (!mounted) return;
    setState(() {
      _shareLink = (link != null && link.isNotEmpty) ? link : _fallbackLink;
      _loadingLink = false;
    });
  }

  /// Render the white QR card to PNG bytes for sharing / saving.
  Future<Uint8List?> _captureCard() async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _copyLink() async {
    final link = _shareLink ?? _fallbackLink;
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      AppTheme.showSnackBar(
          context, AppLocalizations.of(context)!.translate('link_copied'));
    }
  }

  Future<void> _shareProfile() async {
    final l10n = AppLocalizations.of(context)!;
    final link = _shareLink ?? _fallbackLink;
    final bytes = await _captureCard();
    try {
      if (bytes != null) {
        final dir = await getTemporaryDirectory();
        final file = File(
            '${dir.path}/enom_profile_${_handle}_${_userId ?? 0}.png');
        await file.writeAsBytes(bytes);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: '@$_handle\n$link',
          ),
        );
      } else {
        await SharePlus.instance.share(ShareParams(text: '@$_handle\n$link'));
      }
    } catch (_) {
      if (mounted) {
        AppTheme.showSnackBar(context, l10n.translate('could_not_share'),
            isError: true);
      }
    }
  }

  Future<void> _downloadQr() async {
    final l10n = AppLocalizations.of(context)!;
    final bytes = await _captureCard();
    if (bytes == null) {
      if (mounted) {
        AppTheme.showSnackBar(context, l10n.translate('could_not_share'),
            isError: true);
      }
      return;
    }
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) {
            AppTheme.showSnackBar(
                context, l10n.translate('permission_denied'),
                isError: true);
          }
          return;
        }
      }
      await Gal.putImageBytes(bytes, album: 'Enom');
      if (mounted) {
        AppTheme.showSnackBar(context, l10n.translate('qr_saved'));
      }
    } catch (_) {
      if (mounted) {
        AppTheme.showSnackBar(context, l10n.translate('could_not_share'),
            isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final link = _shareLink ?? _fallbackLink;
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Center(
                      child: GestureDetector(
                        onTap: _cycleColor,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                          ),
                          child: Text(
                            l10n.translate('color').toUpperCase(),
                            style: GoogleFonts.jost(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // ── QR card ──
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: GestureDetector(
                      onTap: _cycleColor,
                      child: RepaintBoundary(
                        key: _cardKey,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: _theme.colors,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _loadingLink
                                  ? SizedBox(
                                      width: 220,
                                      height: 220,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            color: _theme.qrColor, strokeWidth: 2),
                                      ),
                                    )
                                  : QrImageView(
                                      data: link,
                                      version: QrVersions.auto,
                                      size: 220,
                                      backgroundColor: Colors.transparent,
                                      eyeStyle: QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: _theme.qrColor,
                                      ),
                                      dataModuleStyle: QrDataModuleStyle(
                                        dataModuleShape: QrDataModuleShape.square,
                                        color: _theme.qrColor,
                                      ),
                                      embeddedImage: const AssetImage(
                                          'assets/images/enom_logo.jpeg'),
                                      embeddedImageStyle: const QrEmbeddedImageStyle(
                                        size: Size(44, 44),
                                      ),
                                    ),
                              const SizedBox(height: 18),
                              Text(
                                '@${_handle.toUpperCase()}',
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.jost(
                                  color: _theme.textColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Action bar ──
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(
                    icon: Icons.share_outlined,
                    label: l10n.translate('share_profile'),
                    onTap: _loadingLink ? null : _shareProfile,
                  ),
                  _actionButton(
                    icon: Icons.link,
                    label: l10n.translate('copy_link'),
                    onTap: _loadingLink ? null : _copyLink,
                  ),
                  _actionButton(
                    icon: Icons.download,
                    label: l10n.translate('download'),
                    onTap: _loadingLink ? null : _downloadQr,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.jost(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A color theme for the shareable QR card: [colors] is the card's gradient,
/// [qrColor] the QR modules, [textColor] the username label — chosen so each
/// stays readable on its gradient.
class _QrTheme {
  const _QrTheme(this.colors, this.qrColor, this.textColor);

  final List<Color> colors;
  final Color qrColor;
  final Color textColor;
}
