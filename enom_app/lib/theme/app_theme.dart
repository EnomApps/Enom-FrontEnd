import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens matching the ENOM Liquid Glass prototype.
/// Colors, typography, glassmorphism components, and gold dust background.
class AppTheme {
  AppTheme._();

  // ── Gold Palette (from prototype) ──
  static const Color gold1 = Color(0xFFC9A84C); // Primary gold
  static const Color gold2 = Color(0xFFE8C96D); // Gradient mid
  static const Color gold3 = Color(0xFFF5DFA0); // Gradient highlight
  static const Color gold4 = Color(0xFFB8922E); // Deep gold

  // Legacy aliases
  static const Color gold = gold1;
  static const Color goldLight = gold2;
  static const Color goldDark = gold4;
  static const Color goldPale = gold3;

  // ── Gold Gradients ──
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment(-0.5, -1),
    end: Alignment(0.5, 1),
    colors: [gold1, gold2, gold3, gold1],
  );

  static const LinearGradient goldGradient2 = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [gold4, gold2, gold3, gold1],
  );

  // ── Dark Theme Colors (Instagram-style) ──
  static const Color darkBg = Color(0xFF000000);
  static const Color darkBg2 = Color(0xFF121212);
  static const Color darkNavBg = Color(0xD9000000); // rgba(0,0,0,0.85)
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static Color darkTextSecondary = const Color(0xFFF5F5F5).withValues(alpha: 0.65);
  static Color darkTextMuted = const Color(0xFFF5F5F5).withValues(alpha: 0.40);
  static Color darkGlass = Colors.white.withValues(alpha: 0.08);
  static Color darkGlassBorder = Colors.white.withValues(alpha: 0.12);
  static Color darkGlassHighlight = Colors.white.withValues(alpha: 0.15);
  static Color darkMoodCardBg = const Color.fromRGBO(18, 18, 18, 0.80);
  static Color darkCardBg = Colors.white.withValues(alpha: 0.06);
  static Color darkCardBorder = Colors.white.withValues(alpha: 0.12);
  static Color darkInputBg = Colors.white.withValues(alpha: 0.08);
  static Color darkInputBorder = Colors.white.withValues(alpha: 0.12);

  // ── Light Theme Colors (Instagram-style) ──
  static const Color lightBg = Color(0xFFFAFAFA);
  static const Color lightBg2 = Color(0xFFEFEFEF);
  static const Color lightNavBg = Color(0xD9FAFAFA); // rgba(250,250,250,0.85)
  static const Color lightGold = Color(0xFF8C6D14);
  static const Color lightTextPrimary = Color(0xFF262626);
  static Color lightTextSecondary = const Color(0xFF262626).withValues(alpha: 0.60);
  static Color lightTextMuted = const Color(0xFF262626).withValues(alpha: 0.38);
  static Color lightGlass = Colors.white.withValues(alpha: 0.60);
  static Color lightGlassBorder = const Color.fromRGBO(219, 219, 219, 0.40);
  static Color lightGlassHighlight = Colors.white.withValues(alpha: 0.85);
  static Color lightMoodCardBg = const Color.fromRGBO(255, 255, 255, 0.75);
  static Color lightCardBg = Colors.white.withValues(alpha: 0.70);
  static Color lightCardBorder = const Color.fromRGBO(219, 219, 219, 0.35);
  static Color lightInputBg = Colors.white.withValues(alpha: 0.60);
  static Color lightInputBorder = const Color.fromRGBO(219, 219, 219, 0.40);

  // Legacy aliases for compatibility
  static const Color lightGoldLight = Color(0xFFBFA02A);
  static const Color lightGoldDark = Color(0xFF6B5210);
  static const Color darkText1 = Color(0xFFF5F5F5);

  // ── Helpers ──
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color bg(BuildContext context) => isDark(context) ? darkBg : lightBg;
  static Color bg2(BuildContext context) => isDark(context) ? darkBg2 : lightBg2;
  static Color cardBg(BuildContext context) => isDark(context) ? darkCardBg : lightCardBg;
  static Color cardBorder(BuildContext context) => isDark(context) ? darkCardBorder : lightCardBorder;
  static Color inputBg(BuildContext context) => isDark(context) ? darkInputBg : lightInputBg;
  static Color inputBorder(BuildContext context) => isDark(context) ? darkInputBorder : lightInputBorder;
  static Color navBg(BuildContext context) => isDark(context) ? darkNavBg : lightNavBg;
  static Color text1(BuildContext context) => isDark(context) ? darkTextPrimary : lightTextPrimary;
  static Color text2(BuildContext context) => isDark(context) ? darkTextSecondary : lightTextSecondary;
  static Color textMuted(BuildContext context) => isDark(context) ? darkTextMuted : lightTextMuted;
  static Color goldColor(BuildContext context) => isDark(context) ? gold1 : lightGold;
  static Color goldFill(BuildContext context) => isDark(context)
      ? gold1.withValues(alpha: 0.10)
      : lightGold.withValues(alpha: 0.08);
  static Color toggleBg(BuildContext context) => isDark(context) ? darkBg : Colors.white;
  static Color glassBg(BuildContext context) => isDark(context) ? darkGlass : lightGlass;
  static Color glassBorder(BuildContext context) => isDark(context) ? darkGlassBorder : lightGlassBorder;
  static Color glassHighlight(BuildContext context) => isDark(context) ? darkGlassHighlight : lightGlassHighlight;
  static Color moodCardBg(BuildContext context) => isDark(context) ? darkMoodCardBg : lightMoodCardBg;

  // ── Text Styles (Cormorant Garamond for display, Jost for UI) ──
  static TextStyle heading(BuildContext context, {double size = 36}) =>
      GoogleFonts.cormorantGaramond(
        color: text1(context),
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: 1,
      );

  static TextStyle subheading(BuildContext context, {double size = 14}) =>
      GoogleFonts.jost(
        color: textMuted(context),
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: 4,
      );

  static TextStyle body(BuildContext context, {double size = 15, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.jost(
        color: text1(context),
        fontSize: size,
        fontWeight: weight,
      );

  static TextStyle label(BuildContext context, {double size = 10}) =>
      GoogleFonts.jost(
        color: textMuted(context),
        fontSize: size,
        fontWeight: FontWeight.w400,
        letterSpacing: 4,
      );

  static TextStyle ctaText(BuildContext context) =>
      GoogleFonts.cormorantGaramond(
        color: const Color(0xFF1A1612),
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      );

  static TextStyle navLabel(BuildContext context) =>
      GoogleFonts.jost(
        fontSize: 9,
        fontWeight: FontWeight.w400,
        letterSpacing: 2,
      );

  // ── Glass Input Field (matching prototype 5.2) ──
  static InputDecoration inputDecoration(
    BuildContext context, {
    required String hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.jost(
        color: textMuted(context),
        fontSize: 15,
        fontWeight: FontWeight.w300,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: goldColor(context).withValues(alpha: 0.7))
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: glassBg(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: glassBorder(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: glassBorder(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: gold1.withValues(alpha: 0.4)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  // ── Gold CTA Button (matching prototype 5.3 - pill shape) ──
  static ButtonStyle primaryButton(BuildContext context) {
    return ElevatedButton.styleFrom(
      backgroundColor: goldColor(context),
      foregroundColor: const Color(0xFF1A1612),
      disabledBackgroundColor: goldColor(context).withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 18),
      textStyle: GoogleFonts.cormorantGaramond(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }

  // ── Gold Gradient CTA Button Widget ──
  static Widget goldCTAButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    double height = 56,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed != null ? goldGradient2 : null,
        color: onPressed == null ? gold1.withValues(alpha: 0.5) : null,
        borderRadius: BorderRadius.circular(50),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: gold1.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(50),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Color(0xFF1A1612),
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.cormorantGaramond(
                      color: const Color(0xFF1A1612),
                      fontSize: 19,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // ── Outline Button Style ──
  static ButtonStyle outlineButton(BuildContext context) {
    final g = goldColor(context);
    return OutlinedButton.styleFrom(
      foregroundColor: g,
      side: BorderSide(color: g, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      padding: const EdgeInsets.symmetric(vertical: 14),
      textStyle: GoogleFonts.jost(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: 1,
      ),
    );
  }

  // ── Glass Card Decoration (matching prototype 5.1) ──
  static BoxDecoration cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: cardBg(context),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: glassBorder(context)),
      boxShadow: [
        BoxShadow(
          color: isDark(context)
              ? Colors.black.withValues(alpha: 0.4)
              : const Color.fromRGBO(160, 140, 100, 0.12),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // ── Mood/Glass Card with backdrop blur ──
  static Widget glassCard(BuildContext context, {required Widget child, EdgeInsets? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: moodCardBg(context),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: glassBorder(context)),
            boxShadow: [
              BoxShadow(
                color: isDark(context)
                    ? Colors.black.withValues(alpha: 0.4)
                    : const Color.fromRGBO(160, 140, 100, 0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ── AppBar Theme ──
  static AppBar appBar(BuildContext context, {List<Widget>? actions, Widget? leading}) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: goldColor(context)),
      leading: leading,
      actions: actions,
    );
  }

  // ── Divider ──
  static Widget goldDivider(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            glassBorder(context),
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  // ── Logo Widget ──
  static Widget logo(BuildContext context, {double size = 80}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
        border: Border.all(
          color: goldColor(context).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: gold1.withValues(alpha: 0.15),
            blurRadius: size * 0.3,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/images/enom_logo.gif',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  // ── Snackbar ──
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.jost()),
        backgroundColor: isError ? Colors.redAccent : goldColor(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Bottom Nav Bar ──
  static BottomNavigationBarThemeData bottomNavTheme(BuildContext context) {
    return BottomNavigationBarThemeData(
      backgroundColor: navBg(context),
      selectedItemColor: goldColor(context),
      unselectedItemColor: textMuted(context),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: GoogleFonts.jost(fontSize: 9, letterSpacing: 2),
      unselectedLabelStyle: GoogleFonts.jost(fontSize: 9, letterSpacing: 2),
    );
  }

  // ── Or Divider ──
  static Widget orDivider(BuildContext context, String text) {
    return Row(
      children: [
        Expanded(child: goldDivider(context)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            text,
            style: GoogleFonts.jost(
              fontSize: 13,
              color: textMuted(context),
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        Expanded(child: goldDivider(context)),
      ],
    );
  }

  // ── Social Login Button ──
  static Widget socialButton(BuildContext context, {required Widget icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: glassBg(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: glassBorder(context)),
              boxShadow: [
                BoxShadow(
                  color: isDark(context)
                      ? Colors.black.withValues(alpha: 0.4)
                      : const Color.fromRGBO(160, 140, 100, 0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(child: icon),
          ),
        ),
      ),
    );
  }
}

/// Solid color background (Instagram-style).
/// Dark mode: black, Light mode: off-white (#FAFAFA).
class GoldDustBackground extends StatelessWidget {
  final bool minimalized;
  const GoldDustBackground({super.key, this.minimalized = true});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: dark ? AppTheme.darkBg : AppTheme.lightBg,
        ),
      ),
    );
  }
}

/// Full-screen background combining gold dust image, gradient glows,
/// and animated gold particles. Use this as the first child of a Stack
/// in every screen for the complete ENOM background effect.
class EnomScreenBackground extends StatefulWidget {
  final int gradientVariant;
  final int particleCount;
  final bool showParticles;

  const EnomScreenBackground({
    super.key,
    this.gradientVariant = 1,
    this.particleCount = 40,
    this.showParticles = true,
  });

  @override
  State<EnomScreenBackground> createState() => _EnomScreenBackgroundState();
}

class _EnomScreenBackgroundState extends State<EnomScreenBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final screenSize = MediaQuery.of(context).size;

    // Gradient glow positions
    Alignment a1, a2;
    switch (widget.gradientVariant) {
      case 1:
        a1 = const Alignment(0.0, -0.6);
        a2 = const Alignment(0.6, 0.6);
        break;
      case 2:
        a1 = const Alignment(-0.4, -1.0);
        a2 = const Alignment(0.4, 1.0);
        break;
      case 3:
        a1 = const Alignment(-0.6, -0.2);
        a2 = const Alignment(0.8, 0.4);
        break;
      case 4:
        a1 = const Alignment(0.0, 0.8);
        a2 = const Alignment(0.0, -0.8);
        break;
      default:
        a1 = const Alignment(0.0, -0.3);
        a2 = const Alignment(0.0, 1.0);
        break;
    }

    final glow1 = dark
        ? AppTheme.gold1.withValues(alpha: 0.10)
        : const Color(0xFFB49632).withValues(alpha: 0.08);
    final glow2 = dark
        ? AppTheme.gold1.withValues(alpha: 0.05)
        : const Color(0xFFB49632).withValues(alpha: 0.05);

    return SizedBox.expand(
      child: IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Solid background color (Instagram-style)
            ColoredBox(
              color: dark ? AppTheme.darkBg : AppTheme.lightBg,
            ),

            // 2. Radial gradient glows
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: a1,
                  radius: 0.8,
                  colors: [glow1, Colors.transparent],
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: a2,
                    radius: 0.7,
                    colors: [glow2, Colors.transparent],
                  ),
                ),
              ),
            ),

            // 3. Animated gold particles
            if (widget.showParticles)
              AnimatedBuilder(
                animation: _particleController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: GoldParticlePainter(
                      _particleController.value,
                      count: widget.particleCount,
                      seed: widget.gradientVariant * 17,
                    ),
                    size: screenSize,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Gradient background overlay matching the prototype's radial gold glows.
class GradientBackground extends StatelessWidget {
  final int variant;
  const GradientBackground({super.key, this.variant = 1});

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    final glow1 = dark
        ? AppTheme.gold1.withValues(alpha: 0.10)
        : const Color(0xFFB49632).withValues(alpha: 0.08);
    final glow2 = dark
        ? AppTheme.gold1.withValues(alpha: 0.05)
        : const Color(0xFFB49632).withValues(alpha: 0.05);

    Alignment a1, a2;
    switch (variant) {
      case 1:
        a1 = const Alignment(0.0, -0.6);
        a2 = const Alignment(0.6, 0.6);
        break;
      case 2:
        a1 = const Alignment(-0.4, -1.0);
        a2 = const Alignment(0.4, 1.0);
        break;
      case 3:
        a1 = const Alignment(-0.6, -0.2);
        a2 = const Alignment(0.8, 0.4);
        break;
      case 4:
        a1 = const Alignment(0.0, 0.8);
        a2 = const Alignment(0.0, -0.8);
        break;
      default:
        a1 = const Alignment(0.0, -0.3);
        a2 = const Alignment(0.0, 1.0);
        break;
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: a1,
              radius: 0.8,
              colors: [glow1, Colors.transparent],
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: a2,
                radius: 0.7,
                colors: [glow2, Colors.transparent],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating gold particles painter (minimalized for secondary screens).
class GoldParticlePainter extends CustomPainter {
  final double progress;
  final int count;
  final Random _random;

  GoldParticlePainter(this.progress, {this.count = 30, int seed = 42})
      : _random = Random(seed);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      final seed = _random.nextDouble();
      final x = _random.nextDouble() * size.width;
      final baseY = _random.nextDouble() * size.height;
      final y = (baseY - progress * size.height * 0.3 * seed) % size.height;
      final radius = 0.5 + _random.nextDouble() * 2.5;
      final alpha =
          (0.3 + 0.7 * sin((progress * 2 * pi) + seed * 2 * pi)).clamp(0.0, 1.0);

      paint.color = AppTheme.gold1.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GoldParticlePainter oldDelegate) => true;
}

/// Twinkling star dots overlay.
class StarField extends StatefulWidget {
  final int starCount;
  const StarField({super.key, this.starCount = 12});

  @override
  State<StarField> createState() => _StarFieldState();
}

class _StarFieldState extends State<StarField> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_StarData> _stars;

  @override
  void initState() {
    super.initState();
    final rng = Random(77);
    _stars = List.generate(widget.starCount, (_) => _StarData(
      x: 0.07 + rng.nextDouble() * 0.86,
      y: 0.08 + rng.nextDouble() * 0.72,
      size: 3 + rng.nextDouble() * 4,
      delay: rng.nextDouble() * 4,
      duration: 2 + rng.nextDouble() * 3,
    ));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final starColor = AppTheme.isDark(context)
        ? AppTheme.gold1
        : AppTheme.gold1.withValues(alpha: 0.5);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Stack(
          children: _stars.map((s) {
            final t = (_controller.value * 6 + s.delay) % s.duration / s.duration;
            final opacity = (0.15 + 0.45 * sin(t * pi)).clamp(0.0, 1.0);
            return Positioned(
              left: s.x * MediaQuery.of(context).size.width,
              top: s.y * MediaQuery.of(context).size.height,
              child: Opacity(
                opacity: opacity,
                child: Text(
                  '.',
                  style: TextStyle(
                    color: starColor,
                    fontSize: s.size,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StarData {
  final double x, y, size, delay, duration;
  _StarData({required this.x, required this.y, required this.size, required this.delay, required this.duration});
}
