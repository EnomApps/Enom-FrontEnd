import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'l10n/app_localizations.dart';
import 'models/language_model.dart';
import 'screens/splash_screen.dart';
import 'services/upload_manager.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UploadManager.instance.init();
  // Make system nav bar transparent so content doesn't get hidden behind it
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    statusBarColor: Colors.transparent,
  ));
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
    } else {
      // No saved preference — follow device mode
      if (mounted) {
        setState(() => _themeMode = ThemeMode.system);
      }
      await prefs.setString(_themePrefKey, 'system');
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

      // ── Dark Theme ──
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppTheme.darkBg,
        primaryColor: AppTheme.gold,
        colorScheme: ColorScheme.dark(
          primary: AppTheme.gold,
          secondary: AppTheme.gold,
          surface: AppTheme.darkBg2,
          onSurface: AppTheme.darkText1,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.gold),
          titleTextStyle: TextStyle(color: AppTheme.gold),
        ),
        cardColor: AppTheme.darkBg2,
        dividerColor: AppTheme.gold.withValues(alpha: 0.15),
        textTheme: GoogleFonts.jostTextTheme(
          ThemeData.dark().textTheme,
        ).apply(bodyColor: AppTheme.darkText1, displayColor: AppTheme.goldPale),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppTheme.darkInputBg,
          hintStyle: TextStyle(color: AppTheme.darkTextSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.darkInputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.darkInputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.gold),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppTheme.darkNavBg,
          selectedItemColor: AppTheme.gold,
          unselectedItemColor: AppTheme.darkTextSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),

      // ── Light Theme ──
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppTheme.lightBg,
        primaryColor: AppTheme.lightGold,
        colorScheme: ColorScheme.light(
          primary: AppTheme.lightGold,
          secondary: AppTheme.lightGold,
          surface: AppTheme.lightBg2,
          onSurface: AppTheme.lightTextPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: AppTheme.lightGold),
          titleTextStyle: TextStyle(color: AppTheme.lightGold),
        ),
        cardColor: AppTheme.lightBg2,
        dividerColor: AppTheme.lightGold.withValues(alpha: 0.15),
        textTheme: GoogleFonts.jostTextTheme(
          ThemeData.light().textTheme,
        ).apply(bodyColor: AppTheme.lightTextPrimary, displayColor: AppTheme.lightTextPrimary),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppTheme.lightInputBg,
          hintStyle: TextStyle(color: AppTheme.lightTextSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.lightInputBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: AppTheme.lightInputBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.lightGold),
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: AppTheme.lightNavBg,
          selectedItemColor: AppTheme.lightGold,
          unselectedItemColor: AppTheme.lightTextSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
