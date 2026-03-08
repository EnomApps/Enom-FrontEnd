import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'language_selection_screen.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _initializeVideo();
    _startTimer();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController =
          VideoPlayerController.asset('assets/videos/splash.mp4');
      await _videoController!.initialize();
      await _videoController!.setLooping(false);
      await _videoController!.setVolume(0);
      await _videoController!.setPlaybackSpeed(1.5);
      await _videoController!.play();
      if (mounted) {
        setState(() {
          _videoInitialized = true;
        });
      }
    } catch (e) {
      // Video failed to load — show logo fallback
      if (mounted) {
        _fadeController.forward();
      }
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;

      // Check if user is already logged in
      final isLoggedIn = await ApiService.isLoggedIn();

      // Check if language has been selected before
      final prefs = await SharedPreferences.getInstance();
      final hasSelectedLanguage = prefs.getString('selected_language') != null;

      if (!mounted) return;

      Widget nextScreen;
      if (isLoggedIn) {
        nextScreen = const HomeScreen();
      } else if (hasSelectedLanguage) {
        // Language already selected, skip to welcome via language screen
        nextScreen = const LanguageSelectionScreen();
      } else {
        nextScreen = const LanguageSelectionScreen();
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _videoInitialized && _videoController != null
            ? SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              )
            : FadeTransition(
                opacity: _fadeAnimation..addListener(() {}),
                child: Image.asset(
                  'assets/images/enom_logo.gif',
                  width: 200,
                  height: 200,
                ),
              ),
      ),
    );
  }
}
