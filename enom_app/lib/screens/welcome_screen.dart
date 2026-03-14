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

            // Particle overlay
            AnimatedBuilder(
              animation: _particleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: GoldParticlePainter(_particleController.value),
                  size: size,
                );
              },
            ),

            // Subtle cloud shapes at the bottom
            Positioned(
              bottom: -20,
              left: -40,
              right: -40,
              height: 160,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CloudPainter(
                    color: goldC.withValues(alpha: 0.04),
                  ),
                  size: Size(size.width + 80, 160),
                ),
              ),
            ),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // ENOM logo text
                  Text(
                    'ENOM',
                    style: GoogleFonts.playfairDisplay(
                      color: goldC,
                      fontSize: 52,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 12,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Gold divider
                  Container(
                    width: 50,
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          goldC.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tagline
                  Text(
                    'Luxury Redefined',
                    style: GoogleFonts.cormorantGaramond(
                      color: AppTheme.text2(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 4,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Bubble buttons with connecting glow line
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
                      height: 150,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Login bubble (larger, solid gold)
                          _BubbleButton(
                            label: 'Login',
                            diameter: 125,
                            isSolid: true,
                            goldColor: goldC,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                          ),

                          // Gold glow connector line
                          Container(
                            width: 32,
                            height: 2,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1),
                              gradient: LinearGradient(
                                colors: [
                                  goldC.withValues(alpha: 0.5),
                                  goldC.withValues(alpha: 0.15),
                                  goldC.withValues(alpha: 0.5),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: goldC.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),

                          // Sign Up bubble (glass style)
                          _BubbleButton(
                            label: 'Sign Up',
                            diameter: 110,
                            isSolid: false,
                            goldColor: goldC,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Circular "bubble" button for the welcome screen.
class _BubbleButton extends StatelessWidget {
  final String label;
  final double diameter;
  final bool isSolid;
  final Color goldColor;
  final VoidCallback onTap;

  const _BubbleButton({
    required this.label,
    required this.diameter,
    required this.isSolid,
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
          gradient: isSolid
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.goldLight,
                    goldColor,
                    AppTheme.goldDark,
                  ],
                )
              : null,
          color: isSolid ? null : Colors.white.withValues(alpha: 0.04),
          border: isSolid
              ? null
              : Border.all(
                  color: goldColor.withValues(alpha: 0.5),
                  width: 1.5,
                ),
          boxShadow: [
            BoxShadow(
              color: goldColor.withValues(alpha: isSolid ? 0.35 : 0.12),
              blurRadius: isSolid ? 24 : 16,
              spreadRadius: isSolid ? 2 : 0,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Specular highlight for solid button
            if (isSolid)
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
                color: isSolid
                    ? AppTheme.isDark(context)
                        ? AppTheme.darkBg
                        : AppTheme.lightBg
                    : goldColor,
                fontSize: isSolid ? 17 : 15,
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

/// Paints subtle cloud-like shapes.
class _CloudPainter extends CustomPainter {
  final Color color;

  _CloudPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // First cloud blob
    final path1 = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width * 0.15, size.height * 0.2,
          size.width * 0.35, size.height * 0.55)
      ..quadraticBezierTo(
          size.width * 0.5, size.height * 0.1, size.width * 0.7, size.height * 0.5)
      ..quadraticBezierTo(
          size.width * 0.85, size.height * 0.15, size.width, size.height * 0.6)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path1, paint);

    // Second softer cloud layer
    final paint2 = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final path2 = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(size.width * 0.25, size.height * 0.35,
          size.width * 0.5, size.height * 0.65)
      ..quadraticBezierTo(
          size.width * 0.75, size.height * 0.3, size.width, size.height * 0.7)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) =>
      oldDelegate.color != color;
}
