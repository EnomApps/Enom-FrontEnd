import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens matching the ENOM prototype design system.
/// Provides theme-aware colors, text styles, and reusable widget builders.
class AppTheme {
  AppTheme._();

  // ── Gold Palette ──
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFF0D860);
  static const Color goldDark = Color(0xFFA67C00);
  static const Color goldPale = Color(0xFFE6CC80);

  // ── Dark Theme Colors ──
  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color darkBg2 = Color(0xFF111111);
  static const Color darkNavBg = Color(0xEB0A0A0A); // 92% opacity
  static Color darkCardBg = Colors.white.withValues(alpha: 0.02);
  static Color darkCardBorder = gold.withValues(alpha: 0.1);
  static Color darkInputBg = Colors.white.withValues(alpha: 0.03);
  static Color darkInputBorder = gold.withValues(alpha: 0.2);
  static const Color darkText1 = Color(0xFFE6CC80);
  static Color darkText2 = gold.withValues(alpha: 0.5);
  static Color darkGoldFill = gold.withValues(alpha: 0.08);

  // ── Light Theme Colors ──
  static const Color lightBg = Color(0xFFFAF6EE);
  static const Color lightBg2 = Color(0xFFF3EDD9);
  static const Color lightNavBg = Color(0xF0FAF6EE); // 94% opacity
  static const Color lightGold = Color(0xFF9A7B1A);
  static const Color lightGoldLight = Color(0xFFC9A227);
  static const Color lightGoldDark = Color(0xFF7A5F10);
  static Color lightCardBg = const Color(0xFFB48C28).withValues(alpha: 0.04);
  static Color lightCardBorder = const Color(0xFFA07814).withValues(alpha: 0.12);
  static Color lightInputBg = Colors.white.withValues(alpha: 0.7);
  static Color lightInputBorder = const Color(0xFFA07814).withValues(alpha: 0.2);
  static const Color lightText1 = Color(0xFF3D2E08);
  static Color lightText2 = const Color(0xFF503C0A).withValues(alpha: 0.5);
  static Color lightGoldFill = const Color(0xFFA07814).withValues(alpha: 0.06);

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
  static Color text1(BuildContext context) => isDark(context) ? darkText1 : lightText1;
  static Color text2(BuildContext context) => isDark(context) ? darkText2 : lightText2;
  static Color goldColor(BuildContext context) => isDark(context) ? gold : lightGold;
  static Color goldFill(BuildContext context) => isDark(context) ? darkGoldFill : lightGoldFill;
  static Color toggleBg(BuildContext context) => isDark(context) ? darkBg : Colors.white;

  // ── Text Styles ──
  static TextStyle heading(BuildContext context, {double size = 24}) =>
      GoogleFonts.playfairDisplay(
        color: goldColor(context),
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      );

  static TextStyle subheading(BuildContext context, {double size = 14}) =>
      GoogleFonts.cormorantGaramond(
        color: text2(context),
        fontSize: size,
        fontWeight: FontWeight.w400,
        fontStyle: FontStyle.italic,
        letterSpacing: 2,
      );

  static TextStyle body(BuildContext context, {double size = 13, FontWeight weight = FontWeight.w400}) =>
      GoogleFonts.dmSans(
        color: text1(context),
        fontSize: size,
        fontWeight: weight,
      );

  static TextStyle label(BuildContext context, {double size = 10}) =>
      GoogleFonts.cormorantGaramond(
        color: text2(context),
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: 2,
      );

  // ── Input Decoration ──
  static InputDecoration inputDecoration(
    BuildContext context, {
    required String hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.dmSans(color: text2(context), fontSize: 12),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: goldColor(context).withValues(alpha:0.7))
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: inputBg(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: inputBorder(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: inputBorder(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: goldColor(context)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  // ── Primary Button Style ──
  static ButtonStyle primaryButton(BuildContext context) {
    final g = goldColor(context);
    return ElevatedButton.styleFrom(
      backgroundColor: g,
      foregroundColor: toggleBg(context),
      disabledBackgroundColor: g.withValues(alpha:0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      padding: const EdgeInsets.symmetric(vertical: 14),
      textStyle: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      ),
    );
  }

  // ── Outline Button Style ──
  static ButtonStyle outlineButton(BuildContext context) {
    final g = goldColor(context);
    return OutlinedButton.styleFrom(
      foregroundColor: g,
      side: BorderSide(color: g, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.symmetric(vertical: 14),
      textStyle: GoogleFonts.dmSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 2,
      ),
    );
  }

  // ── Card Decoration ──
  static BoxDecoration cardDecoration(BuildContext context) {
    return BoxDecoration(
      color: cardBg(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: cardBorder(context)),
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
      width: 50,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            goldColor(context).withValues(alpha:0.6),
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
            color: gold.withValues(alpha: 0.15),
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
        content: Text(message, style: GoogleFonts.dmSans()),
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
      unselectedItemColor: text2(context),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: GoogleFonts.dmSans(fontSize: 10, letterSpacing: 1),
      unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 10, letterSpacing: 1),
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
        ? AppTheme.gold.withValues(alpha: 0.06)
        : const Color(0xFFB49632).withValues(alpha: 0.06);
    final glow2 = dark
        ? AppTheme.gold.withValues(alpha: 0.03)
        : const Color(0xFFB49632).withValues(alpha: 0.03);

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

/// Floating gold particles painter (used in welcome, login, signup screens).
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
      final radius = 0.5 + _random.nextDouble() * 1.5;
      final alpha =
          (0.2 + 0.6 * sin((progress * 2 * pi) + seed * 2 * pi)).clamp(0.0, 1.0);

      paint.color = AppTheme.gold.withValues(alpha: alpha);
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
        ? AppTheme.gold
        : AppTheme.gold.withValues(alpha: 0.5);

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
