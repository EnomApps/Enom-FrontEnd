import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:permission_handler/permission_handler.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Permission result returned to the caller.
enum CameraPermissionResult { granted, denied, cancelled }

/// Pre-permission explainer screen for mood detection camera access.
///
/// Shows a mood-themed illustration explaining why camera access is needed,
/// then triggers the native OS prompt. Handles all permission states:
/// granted, denied, permanently denied, and restricted.
class CameraPermissionScreen extends StatefulWidget {
  const CameraPermissionScreen({super.key});

  @override
  State<CameraPermissionScreen> createState() =>
      _CameraPermissionScreenState();
}

class _CameraPermissionScreenState extends State<CameraPermissionScreen>
    with SingleTickerProviderStateMixin {
  _PermissionState _state = _PermissionState.explainer;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _checkExistingPermission();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// If permission was already granted earlier, return immediately.
  Future<void> _checkExistingPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted && mounted) {
      Navigator.pop(context, CameraPermissionResult.granted);
    }
  }

  Future<void> _requestPermission() async {
    setState(() => _state = _PermissionState.requesting);

    final status = await Permission.camera.request();

    if (!mounted) return;

    if (status.isGranted) {
      Navigator.pop(context, CameraPermissionResult.granted);
      return;
    }

    if (status.isRestricted) {
      setState(() => _state = _PermissionState.restricted);
      return;
    }

    if (status.isPermanentlyDenied) {
      setState(() => _state = _PermissionState.permanentlyDenied);
      return;
    }

    // Denied (but can ask again)
    setState(() => _state = _PermissionState.denied);
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    // After returning from settings, check again
    if (!mounted) return;
    final status = await Permission.camera.status;
    if (status.isGranted && mounted) {
      Navigator.pop(context, CameraPermissionResult.granted);
    }
  }

  void _cancel() {
    Navigator.pop(context, CameraPermissionResult.cancelled);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final goldC = AppTheme.goldColor(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppTheme.text1(context)),
          onPressed: _cancel,
        ),
      ),
      body: Stack(
        children: [
          const EnomScreenBackground(gradientVariant: 4, particleCount: 35),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _buildContent(l10n, goldC),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n, Color goldC) {
    switch (_state) {
      case _PermissionState.explainer:
        return _buildExplainerState(l10n, goldC);
      case _PermissionState.requesting:
        return _buildRequestingState(l10n, goldC);
      case _PermissionState.denied:
        return _buildDeniedState(l10n, goldC);
      case _PermissionState.permanentlyDenied:
        return _buildPermanentlyDeniedState(l10n, goldC);
      case _PermissionState.restricted:
        return _buildRestrictedState(l10n, goldC);
    }
  }

  // ─── Explainer (Pre-permission) ──────────────────────────────

  Widget _buildExplainerState(AppLocalizations l10n, Color goldC) {
    return Column(
      children: [
        const Spacer(flex: 2),

        // Mood illustration
        _buildMoodIllustration(goldC),
        const SizedBox(height: 40),

        // Title
        Text(
          l10n.translate('mood_camera_title'),
          style: AppTheme.heading(context, size: 32),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.translate('mood_camera_subtitle'),
          style: GoogleFonts.jost(
            color: goldC,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Description
        Text(
          l10n.translate('mood_camera_desc'),
          style: AppTheme.body(context, size: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Privacy note
        _buildPrivacyNote(l10n, goldC),

        const Spacer(flex: 3),

        // CTA Buttons
        AppTheme.goldCTAButton(
          label: l10n.translate('mood_camera_enable'),
          onPressed: _requestPermission,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: AppTheme.outlineButton(context),
            onPressed: _cancel,
            child: Text(l10n.translate('mood_camera_not_now')),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Requesting (loading) ────────────────────────────────────

  Widget _buildRequestingState(AppLocalizations l10n, Color goldC) {
    return Column(
      children: [
        const Spacer(flex: 3),
        _buildMoodIllustration(goldC),
        const SizedBox(height: 40),
        CircularProgressIndicator(color: goldC, strokeWidth: 2),
        const SizedBox(height: 20),
        Text(
          l10n.translate('mood_camera_initializing'),
          style: AppTheme.body(context, size: 14),
          textAlign: TextAlign.center,
        ),
        const Spacer(flex: 4),
      ],
    );
  }

  // ─── Denied (can retry) ──────────────────────────────────────

  Widget _buildDeniedState(AppLocalizations l10n, Color goldC) {
    return Column(
      children: [
        const Spacer(flex: 2),
        _buildStateIcon(Icons.videocam_off_outlined, goldC),
        const SizedBox(height: 32),
        Text(
          l10n.translate('mood_camera_denied_title'),
          style: AppTheme.heading(context, size: 28),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.translate('mood_camera_denied_desc'),
          style: AppTheme.body(context, size: 14),
          textAlign: TextAlign.center,
        ),
        const Spacer(flex: 3),
        AppTheme.goldCTAButton(
          label: l10n.translate('mood_camera_try_again'),
          onPressed: _requestPermission,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: AppTheme.outlineButton(context),
            onPressed: _cancel,
            child: Text(l10n.translate('mood_camera_not_now')),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Permanently Denied ──────────────────────────────────────

  Widget _buildPermanentlyDeniedState(AppLocalizations l10n, Color goldC) {
    return Column(
      children: [
        const Spacer(flex: 2),
        _buildStateIcon(Icons.settings_outlined, goldC),
        const SizedBox(height: 32),
        Text(
          l10n.translate('mood_camera_perm_denied_title'),
          style: AppTheme.heading(context, size: 28),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.translate('mood_camera_perm_denied_desc'),
          style: AppTheme.body(context, size: 14),
          textAlign: TextAlign.center,
        ),
        const Spacer(flex: 3),
        AppTheme.goldCTAButton(
          label: l10n.translate('open_settings'),
          onPressed: _openSettings,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: AppTheme.outlineButton(context),
            onPressed: _cancel,
            child: Text(l10n.translate('mood_camera_not_now')),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Restricted (parental controls) ──────────────────────────

  Widget _buildRestrictedState(AppLocalizations l10n, Color goldC) {
    return Column(
      children: [
        const Spacer(flex: 2),
        _buildStateIcon(Icons.lock_outline, goldC),
        const SizedBox(height: 32),
        Text(
          l10n.translate('mood_camera_restricted_title'),
          style: AppTheme.heading(context, size: 28),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.translate('mood_camera_restricted_desc'),
          style: AppTheme.body(context, size: 14),
          textAlign: TextAlign.center,
        ),
        const Spacer(flex: 3),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            style: AppTheme.outlineButton(context),
            onPressed: _cancel,
            child: Text(l10n.translate('mood_camera_not_now')),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ─── Shared Widgets ──────────────────────────────────────────

  /// Mood-themed Lottie illustration: animated face scan with glow rings.
  Widget _buildMoodIllustration(Color goldC) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Lottie.asset(
        'assets/animations/mood_scan.json',
        fit: BoxFit.contain,
        repeat: true,
      ),
    );
  }

  Widget _buildStateIcon(IconData icon, Color goldC) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            goldC.withValues(alpha: 0.15),
            goldC.withValues(alpha: 0.05),
          ],
        ),
        border: Border.all(
          color: goldC.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: goldC.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(icon, color: goldC, size: 40),
    );
  }

  Widget _buildPrivacyNote(AppLocalizations l10n, Color goldC) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.glassBg(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.glassBorder(context)),
          ),
          child: Row(
            children: [
              Icon(Icons.shield_outlined, color: goldC, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.translate('mood_camera_privacy'),
                  style: GoogleFonts.jost(
                    color: AppTheme.text2(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PermissionState {
  explainer,
  requesting,
  denied,
  permanentlyDenied,
  restricted,
}
