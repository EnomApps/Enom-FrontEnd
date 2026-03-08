import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'models/language_model.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EnomApp());
}

class EnomApp extends StatefulWidget {
  const EnomApp({super.key});

  static void setLocale(BuildContext context, Locale locale) {
    final state = context.findAncestorStateOfType<_EnomAppState>();
    state?.setLocale(locale);
  }

  static void setThemeMode(BuildContext context, ThemeMode mode) {
    final state = context.findAncestorStateOfType<_EnomAppState>();
    state?.setThemeMode(mode);
  }

  static ThemeMode getThemeMode(BuildContext context) {
    final state = context.findAncestorStateOfType<_EnomAppState>();
    return state?._themeMode ?? ThemeMode.system;
  }

  @override
  State<EnomApp> createState() => _EnomAppState();
}

class _EnomAppState extends State<EnomApp> {
  Locale _locale = const Locale('en');
  ThemeMode _themeMode = ThemeMode.system;

  static const String _themePrefKey = 'theme_mode';

  @override
  void initState() {
    super.initState();
    _loadSavedLocale();
    _loadSavedTheme();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final langCode = prefs.getString('selected_language');
    if (langCode != null && mounted) {
      setState(() {
        _locale = Locale(langCode);
      });
    }
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString(_themePrefKey);
    if (themeStr != null && mounted) {
      setState(() {
        switch (themeStr) {
          case 'light':
            _themeMode = ThemeMode.light;
            break;
          case 'dark':
            _themeMode = ThemeMode.dark;
            break;
          default:
            _themeMode = ThemeMode.system;
        }
      });
    }
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  void setThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    switch (mode) {
      case ThemeMode.light:
        await prefs.setString(_themePrefKey, 'light');
        break;
      case ThemeMode.dark:
        await prefs.setString(_themePrefKey, 'dark');
        break;
      case ThemeMode.system:
        await prefs.setString(_themePrefKey, 'system');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRTL = AppLocalizations.isRTL(_locale.languageCode);

    const goldColor = Color(0xFFD4AF37);

    return MaterialApp(
      title: 'ENOM',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: LanguageModel.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // RTL support: override directionality for RTL languages
      builder: (context, child) {
        if (isRTL) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        }
        return child!;
      },
      themeMode: _themeMode,
      // Dark theme
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primaryColor: goldColor,
        colorScheme: const ColorScheme.dark(
          primary: goldColor,
          secondary: goldColor,
          surface: Color(0xFF121212),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: IconThemeData(color: goldColor),
          titleTextStyle: TextStyle(color: goldColor),
        ),
        cardColor: const Color(0xFF1A1A1A),
        dividerColor: Colors.white12,
        fontFamily: 'Roboto',
      ),
      // Light theme
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        primaryColor: goldColor,
        colorScheme: const ColorScheme.light(
          primary: goldColor,
          secondary: goldColor,
          surface: Colors.white,
          onSurface: Color(0xFF1A1A1A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: goldColor),
          titleTextStyle: TextStyle(color: goldColor),
        ),
        cardColor: Colors.white,
        dividerColor: Colors.black12,
        fontFamily: 'Roboto',
      ),
      home: const SplashScreen(),
    );
  }
}
