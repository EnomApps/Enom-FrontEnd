import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:simple_pip_mode/simple_pip.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../services/block_report_service.dart';
import '../theme/app_theme.dart';

/// TikTok-style long-press action sheet for a video in the reels screen.
class VideoActionsSheet extends StatefulWidget {
  /// True while the activity is in Picture-in-Picture mode. Reels overlays
  /// listen and hide so only the video shows in the PiP window.
  static final ValueNotifier<bool> pipActive = ValueNotifier<bool>(false);

  /// User toggle: when true, finishing a reel auto-advances to the next one.
  static final ValueNotifier<bool> autoScrollEnabled = ValueNotifier<bool>(false);

  final int postId;
  final String? videoUrl;
  final VideoPlayerController? controller;
  final double currentSpeed;
  final bool clearMode;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onClearModeToggled;
  final VoidCallback onNotInterested;

  const VideoActionsSheet({
    super.key,
    required this.postId,
    required this.videoUrl,
    required this.controller,
    required this.currentSpeed,
    required this.clearMode,
    required this.onSpeedChanged,
    required this.onClearModeToggled,
    required this.onNotInterested,
  });

  static Future<void> show(
    BuildContext context, {
    required int postId,
    required String? videoUrl,
    required VideoPlayerController? controller,
    required double currentSpeed,
    required bool clearMode,
    required ValueChanged<double> onSpeedChanged,
    required VoidCallback onClearModeToggled,
    required VoidCallback onNotInterested,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => VideoActionsSheet(
        postId: postId,
        videoUrl: videoUrl,
        controller: controller,
        currentSpeed: currentSpeed,
        clearMode: clearMode,
        onSpeedChanged: onSpeedChanged,
        onClearModeToggled: onClearModeToggled,
        onNotInterested: onNotInterested,
      ),
    );
  }

  @override
  State<VideoActionsSheet> createState() => _VideoActionsSheetState();
}

class _VideoActionsSheetState extends State<VideoActionsSheet> {
  bool _downloading = false;
  late double _currentSpeed = widget.currentSpeed;

  Future<void> _download() async {
    final url = widget.videoUrl;
    if (url == null || url.isEmpty || _downloading) return;
    setState(() => _downloading = true);
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          if (mounted) {
            AppTheme.showSnackBar(context, 'Storage permission denied');
            Navigator.pop(context);
          }
          return;
        }
      }

      final dir = await getTemporaryDirectory();
      final filename =
          'enom_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final file = File('${dir.path}/$filename');
      final res = await http.get(Uri.parse(url));
      await file.writeAsBytes(res.bodyBytes);
      await Gal.putVideo(file.path, album: 'Enom');

      if (!mounted) return;
      AppTheme.showSnackBar(context, 'Saved to gallery');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppTheme.showSnackBar(context, 'Download failed');
      Navigator.pop(context);
    }
  }

  Future<void> _report() async {
    Navigator.pop(context);
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.bg(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        const reasons = [
          'spam',
          'harassment',
          'nudity',
          'violence',
          'misinformation',
          'other',
        ];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Report post',
                  style: GoogleFonts.jost(
                    color: AppTheme.text1(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final r in reasons)
                ListTile(
                  title: Text(
                    r[0].toUpperCase() + r.substring(1),
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 14,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, r),
                ),
            ],
          ),
        );
      },
    );
    if (reason == null) return;
    final result = await BlockReportService.report(
      type: 'post',
      id: widget.postId,
      reason: reason,
    );
    if (mounted) AppTheme.showSnackBar(context, result.message);
  }

  void _setSpeed(double speed) {
    widget.controller?.setPlaybackSpeed(speed);
    widget.onSpeedChanged(speed);
    setState(() => _currentSpeed = speed);
  }

  void _toggleClearMode() {
    widget.onClearModeToggled();
    Navigator.pop(context);
  }

  void _notInterested() {
    widget.onNotInterested();
    Navigator.pop(context);
  }

  Future<void> _enterPip() async {
    Navigator.pop(context);
    final pip = SimplePip();
    final entered = await pip.enterPipMode(aspectRatio: const (9, 16));
    if (!entered && mounted) {
      AppTheme.showSnackBar(
        context,
        'Picture-in-Picture not supported on this device',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.of(context).size;
    // Don't try to lay out at PiP-tiny widths — the sheet was popping while
    // the activity was resizing into PiP and the row contents overflowed.
    if (s.width < 320) return const SizedBox.shrink();
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.bg(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            // Group 1: post actions
            _buildRow(
              icon: _downloading
                  ? Icons.downloading_rounded
                  : Icons.download_rounded,
              label: _downloading ? 'Saving…' : 'Download',
              onTap: _download,
            ),
            _buildRow(
              icon: Icons.heart_broken_outlined,
              label: 'Not interested',
              onTap: _notInterested,
            ),
            _buildRow(
              icon: Icons.flag_outlined,
              label: 'Report',
              onTap: _report,
            ),
            const SizedBox(height: 8),
            Divider(color: AppTheme.glassBorder(context), height: 1),
            const SizedBox(height: 8),
            // Group 2: playback
            _buildSpeedRow(),
            _buildRow(
              icon: Icons.crop_free_rounded,
              label: 'Clear mode',
              trailing: widget.clearMode
                  ? Icon(Icons.check_rounded,
                      color: AppTheme.goldColor(context), size: 20)
                  : null,
              onTap: _toggleClearMode,
            ),
            _buildAutoScrollRow(),
            _buildRow(
              icon: Icons.picture_in_picture_alt_rounded,
              label: 'Picture-in-Picture',
              onTap: _enterPip,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.text1(context), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.jost(
                  color: AppTheme.text1(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildAutoScrollRow() {
    return ValueListenableBuilder<bool>(
      valueListenable: VideoActionsSheet.autoScrollEnabled,
      builder: (_, enabled, __) {
        return InkWell(
          onTap: () => VideoActionsSheet.autoScrollEnabled.value = !enabled,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.swap_vert_rounded,
                    color: AppTheme.text1(context), size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Auto scroll',
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch(
                  value: enabled,
                  activeColor: AppTheme.goldColor(context),
                  onChanged: (v) => VideoActionsSheet.autoScrollEnabled.value = v,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpeedRow() {
    const speeds = [0.5, 1.0, 1.5, 2.0];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.speed_rounded,
              color: AppTheme.text1(context), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'Speed',
              style: GoogleFonts.jost(
                color: AppTheme.text1(context),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: AppTheme.glassBg(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in speeds)
                  GestureDetector(
                    onTap: () => _setSpeed(s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: s == _currentSpeed
                            ? AppTheme.bg(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${s}x',
                        style: GoogleFonts.jost(
                          color: AppTheme.text1(context),
                          fontSize: 13,
                          fontWeight: s == _currentSpeed
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
