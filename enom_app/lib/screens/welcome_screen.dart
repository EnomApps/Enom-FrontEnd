import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _bobController;
  late Animation<double> _bobAnimation;
  late AnimationController _orbController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _bobAnimation = CurvedAnimation(
      parent: _bobController,
      curve: Curves.easeInOut,
    );

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _bobController.dispose();
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dark = AppTheme.isDark(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full background with gold dust + gradient + particles
            const EnomScreenBackground(gradientVariant: 1, particleCount: 60),

            // Floating orbs
            AnimatedBuilder(
              animation: _orbController,
              builder: (context, _) {
                final t = _orbController.value;
                return Stack(
                  children: [
                    Positioned(
                      top: size.height * 0.1 + sin(t * 2 * pi) * 20,
                      left: -size.width * 0.2 + cos(t * 2 * pi) * 30,
                      child: Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.gold1.withValues(alpha: dark ? 0.15 : 0.10),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: size.height * 0.15 + sin((t + 0.375) * 2 * pi) * 15,
                      right: -size.width * 0.15 + cos((t + 0.375) * 2 * pi) * 20,
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.gold2.withValues(alpha: dark ? 0.10 : 0.08),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: size.height * 0.5 + sin((t + 0.625) * 2 * pi) * 10,
                      left: size.width * 0.4 + cos((t + 0.625) * 2 * pi) * 15,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.gold3.withValues(alpha: dark ? 0.08 : 0.06),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // E logo circle with sunrise rays
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: AnimatedBuilder(
                      animation: _orbController,
                      builder: (context, child) {
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer soft glow
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppTheme.gold1.withValues(alpha: dark ? 0.18 : 0.12),
                                    AppTheme.gold2.withValues(alpha: dark ? 0.08 : 0.05),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.5, 1.0],
                                ),
                              ),
                            ),
                            // Rotating sun rays
                            Transform.rotate(
                              angle: _orbController.value * 2 * pi,
                              child: CustomPaint(
                                size: const Size(220, 220),
                                painter: _SunRaysPainter(
                                  color: AppTheme.goldColor(context),
                                  rayCount: 24,
                                  innerRadius: 38,
                                  outerRadius: 110,
                                  pulse: sin(_orbController.value * 2 * pi) * 0.15 + 0.85,
                                ),
                              ),
                            ),
                            // Inner warm glow behind logo
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.gold2.withValues(alpha: dark ? 0.35 : 0.25),
                                    blurRadius: 30,
                                    spreadRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                            // The logo itself
                            AppTheme.logo(context, size: 64),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ENOM logo text
                  Text(
                    'ENOM',
                    style: GoogleFonts.cormorantGaramond(
                      color: AppTheme.text1(context),
                      fontSize: 42,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 16,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tagline
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Track your mood & connect\nwith like-minded people',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jost(
                        color: AppTheme.text2(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.3,
                        height: 1.6,
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Glass orb buttons
                  AnimatedBuilder(
                    animation: _bobAnimation,
                    builder: (context, child) {
                      final bobOffset = 6.0 * _bobAnimation.value - 3.0;
                      return Transform.translate(
                        offset: Offset(0, bobOffset),
                        child: child,
                      );
                    },
                    child: SizedBox(
                      width: size.width,
                      height: 180,
                      child: CustomPaint(
                        painter: _ConnectorLinePainter(
                          color: AppTheme.goldColor(context),
                          startOffset: Offset(size.width * 0.28, 130),
                          endOffset: Offset(size.width * 0.68, 60),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Sign Up glass orb — bottom-left
                            Positioned(
                              left: size.width * 0.28 - 60,
                              top: 130 - 60,
                              child: _GlassOrbButton(
                                label: 'Sign Up',
                                diameter: 120,
                                isGold: false,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SignupScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Login gold orb — top-right
                            Positioned(
                              left: size.width * 0.68 - 60,
                              top: 60 - 60,
                              child: _GlassOrbButton(
                                label: 'Login',
                                diameter: 120,
                                isGold: true,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paints a curved glowing connector line between two bubble centers.
class _ConnectorLinePainter extends CustomPainter {
  final Color color;
  final Offset startOffset;
  final Offset endOffset;

  _ConnectorLinePainter({
    required this.color,
    required this.startOffset,
    required this.endOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midX = (startOffset.dx + endOffset.dx) / 2;
    final midY = (startOffset.dy + endOffset.dy) / 2;
    final controlPoint = Offset(midX + 20, midY + 40);

    final path = Path()
      ..moveTo(startOffset.dx, startOffset.dy)
      ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, endOffset.dx, endOffset.dy);

    // Glow layer
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);

    // Main curved line
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _ConnectorLinePainter oldDelegate) =>
      oldDelegate.startOffset != startOffset || oldDelegate.endOffset != endOffset;
}

/// Glass orb button matching the prototype's liquid glass style.
class _GlassOrbButton extends StatelessWidget {
  final String label;
  final double diameter;
  final bool isGold;
  final VoidCallback onTap;

  const _GlassOrbButton({
    required this.label,
    required this.diameter,
    required this.isGold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: diameter,
            height: diameter,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isGold
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppTheme.gold1.withValues(alpha: 0.6),
                        AppTheme.gold2.withValues(alpha: 0.4),
                        AppTheme.gold3.withValues(alpha: 0.5),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.white.withValues(alpha: 0.04),
                      ],
                    ),
              border: Border.all(
                color: isGold
                    ? AppTheme.gold3.withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: isGold
                      ? AppTheme.gold1.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.2),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Specular highlight (inner light reflection)
                Positioned(
                  top: diameter * 0.06,
                  left: diameter * 0.15,
                  child: Container(
                    width: diameter * 0.7,
                    height: diameter * 0.35,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(diameter),
                      gradient: RadialGradient(
                        center: Alignment.topCenter,
                        colors: [
                          Colors.white.withValues(alpha: isGold ? 0.35 : 0.20),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Label
                Text(
                  label,
                  style: GoogleFonts.cormorantGaramond(
                    color: isGold
                        ? const Color(0xFF1A1612)
                        : AppTheme.text1(context),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints radiating sun rays from center — sunrise effect behind the logo.
class _SunRaysPainter extends CustomPainter {
  final Color color;
  final int rayCount;
  final double innerRadius;
  final double outerRadius;
  final double pulse;

  _SunRaysPainter({
    required this.color,
    this.rayCount = 24,
    this.innerRadius = 38,
    this.outerRadius = 110,
    this.pulse = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final angleStep = (2 * pi) / rayCount;
    final rayWidth = angleStep * 0.35;

    for (int i = 0; i < rayCount; i++) {
      final angle = i * angleStep;
      final opacity = (0.12 + 0.10 * sin(angle * 3)) * pulse;
      final currentOuter = outerRadius * (0.85 + 0.15 * sin(angle * 5)) * pulse;

      final path = Path();
      path.moveTo(
        center.dx + innerRadius * cos(angle - rayWidth),
        center.dy + innerRadius * sin(angle - rayWidth),
      );
      path.lineTo(
        center.dx + currentOuter * cos(angle),
        center.dy + currentOuter * sin(angle),
      );
      path.lineTo(
        center.dx + innerRadius * cos(angle + rayWidth),
        center.dy + innerRadius * sin(angle + rayWidth),
      );
      path.close();

      final paint = Paint()
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SunRaysPainter oldDelegate) =>
      oldDelegate.pulse != pulse;
}
