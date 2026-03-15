import 'dart:math';
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
  late AnimationController _particleController;
  late AnimationController _bobController;
  late Animation<double> _bobAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _bobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _bobAnimation = CurvedAnimation(
      parent: _bobController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _particleController.dispose();
    _bobController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final goldC = AppTheme.goldColor(context);

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background overlay
            const GradientBackground(variant: 1),

            // Star field
            const StarField(),

            // Particle overlay — dense gold dust
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: GoldParticlePainter(_particleController.value, count: 120),
                  size: size,
                );
              },
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // E logo circle
                  AppTheme.logo(context, size: 56),
                  const SizedBox(height: 20),

                  // ENOM logo text
                  Text(
                    'ENOM',
                    style: GoogleFonts.playfairDisplay(
                      color: goldC,
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tagline
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Track your mood & connect\nwith like-minded people',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cormorantGaramond(
                        color: AppTheme.text2(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 2,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Diagonal bubble buttons
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
                          color: goldC,
                          // Sign Up center: left area, lower
                          // Login center: right area, upper
                          startOffset: Offset(size.width * 0.28, 130),
                          endOffset: Offset(size.width * 0.68, 60),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Sign Up bubble — bottom-left
                            Positioned(
                              left: size.width * 0.28 - 55,
                              top: 130 - 55,
                              child: _BubbleButton(
                                label: 'Sign Up',
                                diameter: 110,
                                goldColor: goldC,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SignupScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Login bubble — top-right (larger)
                            Positioned(
                              left: size.width * 0.68 - 62.5,
                              top: 60 - 62.5,
                              child: _BubbleButton(
                                label: 'Login',
                                diameter: 125,
                                goldColor: goldC,
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
    // Control point for the curve — offset to create the bend
    final midX = (startOffset.dx + endOffset.dx) / 2;
    final midY = (startOffset.dy + endOffset.dy) / 2;
    // Bend downward and to the right for a natural arc
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

/// Solid gold sphere bubble button for the welcome screen.
class _BubbleButton extends StatelessWidget {
  final String label;
  final double diameter;
  final Color goldColor;
  final VoidCallback onTap;

  const _BubbleButton({
    required this.label,
    required this.diameter,
    required this.goldColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.goldLight,
              goldColor,
              AppTheme.goldDark,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: goldColor.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Specular highlight
            Positioned(
              top: diameter * 0.12,
              left: diameter * 0.2,
              child: Container(
                width: diameter * 0.35,
                height: diameter * 0.18,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(diameter),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Label
            Text(
              label,
              style: GoogleFonts.playfairDisplay(
                color: AppTheme.isDark(context)
                    ? AppTheme.darkBg
                    : AppTheme.lightBg,
                fontSize: diameter > 115 ? 17 : 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
