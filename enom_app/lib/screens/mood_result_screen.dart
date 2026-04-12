import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../services/mood_detection_service.dart';
import '../services/mood_history_service.dart';
import '../theme/app_theme.dart';

/// Mood-specific color themes for the result screen.
class MoodTheme {
  final Color primary;
  final Color secondary;
  final List<Color> gradient;

  const MoodTheme({
    required this.primary,
    required this.secondary,
    required this.gradient,
  });

  static MoodTheme forMood(String mood) {
    return switch (mood.toLowerCase()) {
      'happy' => const MoodTheme(
          primary: Color(0xFFFFD700),
          secondary: Color(0xFFFFA000),
          gradient: [Color(0xFF1A1200), Color(0xFF2D1F00), Color(0xFF1A1200)],
        ),
      'calm' => const MoodTheme(
          primary: Color(0xFF81D4FA),
          secondary: Color(0xFF4FC3F7),
          gradient: [Color(0xFF0A1520), Color(0xFF0D2137), Color(0xFF0A1520)],
        ),
      'sad' => const MoodTheme(
          primary: Color(0xFF90A4AE),
          secondary: Color(0xFF78909C),
          gradient: [Color(0xFF121518), Color(0xFF1A2025), Color(0xFF121518)],
        ),
      'angry' => const MoodTheme(
          primary: Color(0xFFEF5350),
          secondary: Color(0xFFE53935),
          gradient: [Color(0xFF1A0A0A), Color(0xFF2D1010), Color(0xFF1A0A0A)],
        ),
      'surprised' => const MoodTheme(
          primary: Color(0xFFCE93D8),
          secondary: Color(0xFFBA68C8),
          gradient: [Color(0xFF1A0F1E), Color(0xFF251530), Color(0xFF1A0F1E)],
        ),
      'neutral' => const MoodTheme(
          primary: Color(0xFFC9A84C),
          secondary: Color(0xFFE8C96D),
          gradient: [Color(0xFF0F0E08), Color(0xFF1A1810), Color(0xFF0F0E08)],
        ),
      'low' => const MoodTheme(
          primary: Color(0xFF90A4AE),
          secondary: Color(0xFF78909C),
          gradient: [Color(0xFF121518), Color(0xFF1A2025), Color(0xFF121518)],
        ),
      _ => const MoodTheme(
          primary: Color(0xFFC9A84C),
          secondary: Color(0xFFE8C96D),
          gradient: [Color(0xFF0F0E08), Color(0xFF1A1810), Color(0xFF0F0E08)],
        ),
    };
  }
}

/// Mood result display screen — MOOD-303.
/// Shows detected mood with animated emoji, confidence indicator,
/// and allows user to confirm or correct the mood.
class MoodResultScreen extends StatefulWidget {
  final MoodResult moodResult;

  const MoodResultScreen({super.key, required this.moodResult});

  @override
  State<MoodResultScreen> createState() => _MoodResultScreenState();
}

class _MoodResultScreenState extends State<MoodResultScreen>
    with TickerProviderStateMixin {
  late MoodResult _currentMood;
  late MoodTheme _moodTheme;
  bool _isSaving = false;

  // Entrance animations
  late AnimationController _entranceController;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleIn;
  late Animation<Offset> _slideUp;

  // Emoji bounce animation
  late AnimationController _emojiController;
  late Animation<double> _emojiBounce;

  // Confidence ring animation
  late AnimationController _ringController;
  late Animation<double> _ringProgress;

  // Background particle animation
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _currentMood = widget.moodResult;
    _moodTheme = MoodTheme.forMood(_currentMood.mood);

    // Entrance: fade + scale + slide
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _scaleIn = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    // Emoji bounce
    _emojiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _emojiBounce = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.05), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _emojiController,
      curve: Curves.easeOut,
    ));

    // Confidence ring fill
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _ringProgress = Tween<double>(begin: 0, end: _currentMood.confidence).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic),
    );

    // Background particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // Stagger the animations
    _entranceController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _emojiController.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _ringController.forward();
    });

    HapticFeedback.mediumImpact();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _emojiController.dispose();
    _ringController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _updateMood(MoodResult newMood) {
    setState(() {
      _currentMood = newMood;
      _moodTheme = MoodTheme.forMood(newMood.mood);
    });
    // Re-run animations
    _emojiController.reset();
    _emojiController.forward();
    _ringController.reset();
    _ringProgress = Tween<double>(begin: 0, end: newMood.confidence).animate(
      CurvedAnimation(parent: _ringController, curve: Curves.easeOutCubic),
    );
    _ringController.forward();
    HapticFeedback.lightImpact();
  }

  Future<void> _confirmMood() async {
    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    // Save to local history + API sync
    await MoodHistoryService.saveMood(_currentMood);

    if (mounted) {
      Navigator.pop(context, _currentMood);
    }
  }

  void _showCorrectionSheet() {
    final l10n = AppLocalizations.of(context)!;
    final moods = [
      ('Happy', '\u{1F60A}', l10n.translate('mood_happy')),
      ('Neutral', '\u{1F610}', l10n.translate('mood_neutral')),
      ('Low', '\u{1F614}', l10n.translate('mood_low')),
      ('Angry', '\u{1F621}', l10n.translate('mood_angry')),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: BoxDecoration(
          color: AppTheme.isDark(context)
              ? const Color(0xFF1A1A1A)
              : const Color(0xFFFAFAFA),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.glassBorder(context)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.textMuted(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.translate('how_are_you_feeling'),
              style: GoogleFonts.cormorantGaramond(
                color: AppTheme.text1(context),
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('select_your_mood'),
              style: GoogleFonts.jost(
                color: AppTheme.textMuted(context),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            // 4 mood options in a row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: moods.map((m) {
                final isSelected = _currentMood.mood == m.$1;
                final moodTheme = MoodTheme.forMood(m.$1);
                return GestureDetector(
                  onTap: () {
                    final correctedMood = MoodResult(
                      mood: m.$1,
                      emoji: m.$2,
                      confidence: 1.0, // User-confirmed = 100%
                      score: _scoreForMood(m.$1),
                    );
                    _updateMood(correctedMood);
                    Navigator.pop(ctx);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? moodTheme.primary.withValues(alpha: 0.15)
                          : AppTheme.glassBg(context),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? moodTheme.primary.withValues(alpha: 0.5)
                            : AppTheme.glassBorder(context),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(m.$2, style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: 6),
                        Text(
                          m.$3,
                          style: GoogleFonts.jost(
                            color: isSelected
                                ? moodTheme.primary
                                : AppTheme.text2(context),
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  int _scoreForMood(String mood) {
    return switch (mood) {
      'Happy' => 90,
      'Neutral' => 50,
      'Low' => 30,
      'Angry' => 25,
      _ => 50,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Mood-themed gradient background
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _moodTheme.gradient,
              ),
            ),
          ),

          // Floating particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, _) => CustomPaint(
              size: Size.infinite,
              painter: _MoodParticlesPainter(
                progress: _particleController.value,
                color: _moodTheme.primary,
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: ScaleTransition(
                  scale: _scaleIn,
                  child: Column(
                    children: [
                      // Top bar
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white70),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Spacer(),
                            Text(
                              l10n.translate('scan_result').toUpperCase(),
                              style: GoogleFonts.jost(
                                color: Colors.white54,
                                fontSize: 11,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 48),
                          ],
                        ),
                      ),

                      const Spacer(flex: 2),

                      // Animated emoji
                      AnimatedBuilder(
                        animation: _emojiBounce,
                        builder: (context, child) => Transform.scale(
                          scale: _emojiBounce.value,
                          child: child,
                        ),
                        child: Text(
                          _currentMood.emoji,
                          style: const TextStyle(fontSize: 80),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Mood label
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          _getMoodLabel(l10n),
                          key: ValueKey(_currentMood.mood),
                          style: GoogleFonts.cormorantGaramond(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Mood insight
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _getMoodInsight(l10n),
                            key: ValueKey('${_currentMood.mood}_insight'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jost(
                              color: Colors.white60,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Confidence ring
                      _buildConfidenceRing(l10n),

                      const Spacer(flex: 3),

                      // Action buttons
                      _buildActionButtons(l10n),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMoodLabel(AppLocalizations l10n) {
    return switch (_currentMood.mood) {
      'Happy' => l10n.translate('mood_happy'),
      'Calm' => l10n.translate('mood_calm'),
      'Sad' => l10n.translate('mood_sad'),
      'Angry' => l10n.translate('mood_angry'),
      'Surprised' => l10n.translate('mood_surprised'),
      'Neutral' => l10n.translate('mood_neutral'),
      'Low' => l10n.translate('mood_low'),
      _ => _currentMood.mood,
    };
  }

  String _getMoodInsight(AppLocalizations l10n) {
    return switch (_currentMood.mood) {
      'Happy' => l10n.translate('mood_msg_happy'),
      'Calm' => l10n.translate('mood_msg_calm'),
      'Sad' => l10n.translate('mood_msg_sad'),
      'Angry' => l10n.translate('mood_msg_angry'),
      'Surprised' => l10n.translate('mood_msg_surprised'),
      'Neutral' => l10n.translate('mood_msg_neutral'),
      'Low' => l10n.translate('mood_msg_sad'),
      _ => l10n.translate('mood_msg_default'),
    };
  }

  Widget _buildConfidenceRing(AppLocalizations l10n) {
    return AnimatedBuilder(
      animation: _ringProgress,
      builder: (context, _) {
        final progress = _ringProgress.value;
        final percentage = (progress * 100).round();
        return Column(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Track
                  CustomPaint(
                    size: const Size(100, 100),
                    painter: _ConfidenceRingPainter(
                      progress: progress,
                      color: _moodTheme.primary,
                      trackColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  // Percentage text
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$percentage%',
                        style: GoogleFonts.cormorantGaramond(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.translate('confidence').toUpperCase(),
                        style: GoogleFonts.jost(
                          color: _moodTheme.primary,
                          fontSize: 9,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButtons(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // "That's Right" — confirm
          GestureDetector(
            onTap: _isSaving ? null : _confirmMood,
            child: Container(
              width: double.infinity,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _moodTheme.primary,
                    _moodTheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: _moodTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.black,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      l10n.translate('thats_right'),
                      style: GoogleFonts.jost(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          // "Not Quite" — correct
          GestureDetector(
            onTap: _showCorrectionSheet,
            child: Container(
              width: double.infinity,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                l10n.translate('not_quite'),
                style: GoogleFonts.jost(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular confidence ring painter with animated fill.
class _ConfidenceRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _ConfidenceRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
    if (progress > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi * progress,
        colors: [color.withValues(alpha: 0.6), color],
      );
      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );

      // Glow dot at the end of the arc
      final endAngle = -math.pi / 2 + 2 * math.pi * progress;
      final dotX = center.dx + radius * math.cos(endAngle);
      final dotY = center.dy + radius * math.sin(endAngle);
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(dotX, dotY), 4, glowPaint);
      final dotPaint = Paint()..color = color;
      canvas.drawCircle(Offset(dotX, dotY), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_ConfidenceRingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Floating mood-themed particles.
class _MoodParticlesPainter extends CustomPainter {
  final double progress;
  final Color color;

  _MoodParticlesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    for (int i = 0; i < 20; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final phase = rng.nextDouble() * 2 * math.pi;
      final radius = 1.5 + rng.nextDouble() * 2.5;

      final x = baseX + math.sin(progress * 2 * math.pi * speed + phase) * 20;
      final y = baseY - (progress * speed * 60) % size.height;
      final adjustedY = y < 0 ? y + size.height : y;

      final alpha = (0.15 + 0.15 * math.sin(progress * 2 * math.pi + phase));
      final paint = Paint()..color = color.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, adjustedY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_MoodParticlesPainter old) => old.progress != progress;
}
