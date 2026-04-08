import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/mood_detection_service.dart';
import '../theme/app_theme.dart';

/// Screen states for the mood scan flow.
enum _ScanState {
  preview,      // Live camera preview with guide
  countdown,    // 3-2-1 countdown before auto-capture
  capturing,    // Taking the photo
  analyzing,    // Sending to API, waiting for result
  result,       // Showing detected mood
  error,        // Something went wrong
}

/// Live Camera Preview & Capture screen for mood detection.
/// Captures a selfie and sends it to the backend API for mood analysis.
class MoodScanScreen extends StatefulWidget {
  const MoodScanScreen({super.key});

  @override
  State<MoodScanScreen> createState() => _MoodScanScreenState();
}

class _MoodScanScreenState extends State<MoodScanScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isTorchOn = false;
  _ScanState _state = _ScanState.preview;

  // Countdown
  int _countdownValue = 3;
  Timer? _countdownTimer;
  Timer? _autoStartTimer;

  // Result
  MoodResult? _moodResult;
  String? _errorMessage;

  // Animations
  late AnimationController _pulseController;
  late AnimationController _borderSpinController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _borderSpinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = null; // will use default translation
        });
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() => _isCameraReady = true);

        // Auto-start countdown after 3 seconds of preview
        _autoStartTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && _state == _ScanState.preview) {
            _startCountdown();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _startCountdown() {
    setState(() {
      _state = _ScanState.countdown;
      _countdownValue = 3;
    });

    HapticFeedback.mediumImpact();

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_countdownValue <= 1) {
        timer.cancel();
        _countdownTimer = null;
        _captureAndAnalyze();
      } else {
        HapticFeedback.lightImpact();
        setState(() => _countdownValue--);
      }
    });
  }

  /// Manual capture — skip countdown.
  void _manualCapture() {
    _countdownTimer?.cancel();
    _autoStartTimer?.cancel();
    _captureAndAnalyze();
  }

  Future<void> _captureAndAnalyze() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() => _state = _ScanState.capturing);
    HapticFeedback.heavyImpact();

    try {
      // Take the picture
      final XFile photo = await _cameraController!.takePicture();

      // Pause camera to save battery
      await _cameraController!.pausePreview();

      setState(() => _state = _ScanState.analyzing);

      // Detect mood on-device using ML Kit
      final result = await MoodDetectionService.detectMood(photo.path);

      if (mounted) {
        if (result != null) {
          setState(() {
            _moodResult = result;
            _state = _ScanState.result;
          });
          HapticFeedback.heavyImpact();
        } else {
          setState(() {
            _state = _ScanState.error;
            _errorMessage = null; // Use default error message
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = _ScanState.error;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _toggleTorch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      _isTorchOn = !_isTorchOn;
      await _cameraController!.setFlashMode(
        _isTorchOn ? FlashMode.torch : FlashMode.off,
      );
      setState(() {});
    } catch (_) {}
  }

  void _retake() async {
    // Resume camera preview
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.resumePreview();
      } catch (_) {}
    }

    setState(() {
      _state = _ScanState.preview;
      _moodResult = null;
      _errorMessage = null;
      _countdownValue = 3;
    });

    // Auto-start again
    _autoStartTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _state == _ScanState.preview) {
        _startCountdown();
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoStartTimer?.cancel();
    _pulseController.dispose();
    _borderSpinController.dispose();
    _cameraController?.dispose();
    MoodDetectionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final goldC = AppTheme.goldColor(context);
    final size = MediaQuery.of(context).size;
    final viewfinderSize = size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.translate('mood_scan_title'),
          style: GoogleFonts.jost(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_state == _ScanState.preview || _state == _ScanState.countdown)
            IconButton(
              icon: Icon(
                _isTorchOn ? Icons.flash_on : Icons.flash_off,
                color: _isTorchOn ? goldC : Colors.white70,
              ),
              onPressed: _toggleTorch,
              tooltip: l10n.translate('mood_scan_torch'),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isCameraReady && _cameraController != null)
            Center(child: CameraPreview(_cameraController!))
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white24),
            ),

          // Circular viewfinder overlay
          _buildViewfinderOverlay(viewfinderSize, goldC),

          // State-specific UI
          _buildStateOverlay(l10n, goldC, viewfinderSize),
        ],
      ),
    );
  }

  /// Dark overlay with a circular cutout for the viewfinder.
  Widget _buildViewfinderOverlay(double viewfinderSize, Color goldC) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _borderSpinController,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ViewfinderPainter(
              viewfinderSize: viewfinderSize,
              borderColor: _state == _ScanState.analyzing
                  ? goldC.withValues(alpha: 0.6)
                  : goldC,
              rotation: _borderSpinController.value * 2 * math.pi,
              isScanning: _state == _ScanState.countdown ||
                  _state == _ScanState.analyzing,
              pulseValue: _pulseAnimation.value,
            ),
          );
        },
      ),
    );
  }

  Widget _buildStateOverlay(
      AppLocalizations l10n, Color goldC, double viewfinderSize) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(flex: 1),
          // Center area for countdown/result
          SizedBox(
            width: viewfinderSize,
            height: viewfinderSize,
            child: Center(child: _buildCenterContent(l10n, goldC)),
          ),
          const Spacer(flex: 1),
          // Bottom controls
          _buildBottomControls(l10n, goldC),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildCenterContent(AppLocalizations l10n, Color goldC) {
    switch (_state) {
      case _ScanState.countdown:
        return TweenAnimationBuilder<double>(
          key: ValueKey(_countdownValue),
          tween: Tween(begin: 1.5, end: 1.0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Text(
                '$_countdownValue',
                style: GoogleFonts.jost(
                  color: goldC,
                  fontSize: 80,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        );
      case _ScanState.capturing:
        // White flash effect
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.3),
          ),
        );
      case _ScanState.analyzing:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: goldC,
                strokeWidth: 2.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.translate('mood_scan_analyzing'),
              style: GoogleFonts.jost(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ],
        );
      case _ScanState.result:
        if (_moodResult == null) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _moodResult!.emoji,
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 12),
            Text(
              _moodResult!.mood,
              style: GoogleFonts.jost(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(_moodResult!.confidence * 100).round()}% confidence',
              style: GoogleFonts.jost(
                color: goldC,
                fontSize: 14,
              ),
            ),
          ],
        );
      case _ScanState.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: goldC, size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? l10n.translate('mood_scan_error'),
              style: GoogleFonts.jost(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBottomControls(AppLocalizations l10n, Color goldC) {
    switch (_state) {
      case _ScanState.preview:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.translate('mood_scan_guide'),
              style: GoogleFonts.jost(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            // Manual capture button
            GestureDetector(
              onTap: _manualCapture,
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: goldC, width: 4),
                      boxShadow: [
                        BoxShadow(
                          color: goldC.withValues(
                              alpha: 0.3 * _pulseAnimation.value),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: goldC,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.translate('mood_scan_tap_capture'),
              style: GoogleFonts.jost(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        );

      case _ScanState.countdown:
        return Text(
          l10n.translate('mood_scan_countdown'),
          style: GoogleFonts.jost(
            color: Colors.white70,
            fontSize: 14,
          ),
        );

      case _ScanState.analyzing:
        // Shimmer loading bars
        return _buildLoadingShimmer(goldC);

      case _ScanState.result:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Retake
            OutlinedButton.icon(
              onPressed: _retake,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.translate('mood_scan_retake')),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
            // Use this mood
            ElevatedButton(
              onPressed: () => Navigator.pop(context, _moodResult),
              style: ElevatedButton.styleFrom(
                backgroundColor: goldC,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: Text(
                l10n.translate('use_mood'),
                style: GoogleFonts.jost(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );

      case _ScanState.error:
        return AppTheme.goldCTAButton(
          label: l10n.translate('mood_camera_try_again'),
          onPressed: _retake,
        );

      default:
        return const SizedBox.shrink();
    }
  }

  /// Shimmer loading effect while API processes the image.
  Widget _buildLoadingShimmer(Color goldC) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 800 + (index * 200)),
              curve: Curves.easeInOut,
              builder: (context, value, _) {
                return Container(
                  height: 12,
                  width: double.infinity * (0.5 + value * 0.5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      begin: Alignment(-1.0 + value * 2, 0),
                      end: Alignment(value * 2, 0),
                      colors: [
                        goldC.withValues(alpha: 0.1),
                        goldC.withValues(alpha: 0.3),
                        goldC.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}

/// Custom painter for the circular viewfinder overlay.
class _ViewfinderPainter extends CustomPainter {
  final double viewfinderSize;
  final Color borderColor;
  final double rotation;
  final bool isScanning;
  final double pulseValue;

  _ViewfinderPainter({
    required this.viewfinderSize,
    required this.borderColor,
    required this.rotation,
    required this.isScanning,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = viewfinderSize / 2;

    // Dark overlay with circular cutout
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.6);
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(Rect.fromCircle(center: center, radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, overlayPaint);

    // Border arc segments (4 arcs with gaps)
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final arcRect = Rect.fromCircle(center: center, radius: radius);

    for (int i = 0; i < 4; i++) {
      final startAngle = rotation + (i * math.pi / 2) + 0.1;
      const sweepAngle = math.pi / 2 - 0.2;
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, borderPaint);
    }

    // Corner markers
    if (!isScanning) {
      final markerPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;

      const markerLen = 20.0;
      final corners = [
        Offset(center.dx - radius, center.dy - radius), // top-left
        Offset(center.dx + radius, center.dy - radius), // top-right
        Offset(center.dx - radius, center.dy + radius), // bottom-left
        Offset(center.dx + radius, center.dy + radius), // bottom-right
      ];

      for (int i = 0; i < 4; i++) {
        final c = corners[i];
        final dx = (i % 2 == 0) ? 1.0 : -1.0;
        final dy = (i < 2) ? 1.0 : -1.0;

        canvas.drawLine(c, Offset(c.dx + markerLen * dx, c.dy), markerPaint);
        canvas.drawLine(c, Offset(c.dx, c.dy + markerLen * dy), markerPaint);
      }
    }

    // Glow effect when scanning
    if (isScanning) {
      final glowPaint = Paint()
        ..color = borderColor.withValues(alpha: 0.15 * pulseValue)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(center, radius, glowPaint);
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) =>
      rotation != old.rotation ||
      isScanning != old.isScanning ||
      pulseValue != old.pulseValue;
}
