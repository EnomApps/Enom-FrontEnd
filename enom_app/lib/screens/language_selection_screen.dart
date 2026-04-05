import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../models/language_model.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {
  String _selectedLanguage = 'en';
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<LanguageModel> get _filteredLanguages {
    final sorted = List<LanguageModel>.from(LanguageModel.supportedLanguages)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (_searchQuery.isEmpty) return sorted;
    final query = _searchQuery.toLowerCase();
    return sorted.where((lang) {
      return lang.name.toLowerCase().contains(query) ||
          lang.nativeName.toLowerCase().contains(query) ||
          lang.code.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _saveLanguageAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', _selectedLanguage);

    if (mounted) {
      EnomApp.setLocale(context, Locale(_selectedLanguage));

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const WelcomeScreen(),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filteredLanguages = _filteredLanguages;

    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const EnomScreenBackground(gradientVariant: 2, particleCount: 45),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Logo
                  AppTheme.logo(context, size: 80),
                  const SizedBox(height: 24),
                  // Title
                  Text(
                    'Select Language',
                    style: AppTheme.heading(context, size: 28),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your preferred language',
                    style: GoogleFonts.jost(
                      color: AppTheme.text2(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: TextField(
                      onChanged: (value) {
                        setState(() => _searchQuery = value);
                      },
                      style: AppTheme.body(context),
                      decoration: InputDecoration(
                        hintText: l10n.translate('search_language'),
                        hintStyle: GoogleFonts.jost(
                          color: AppTheme.textMuted(context),
                          fontSize: 15,
                          fontWeight: FontWeight.w300,
                        ),
                        prefixIcon: Icon(Icons.search,
                            color: AppTheme.textMuted(context)),
                        filled: true,
                        fillColor: AppTheme.glassBg(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppTheme.glassBorder(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppTheme.glassBorder(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                              color: AppTheme.gold1.withValues(alpha: 0.4)),
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Language count
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${filteredLanguages.length} languages available',
                        style: GoogleFonts.jost(
                          color: AppTheme.textMuted(context),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Language list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: filteredLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = filteredLanguages[index];
                        final isSelected = _selectedLanguage == lang.code;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() =>
                                    _selectedLanguage = lang.code);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.gold1
                                          .withValues(alpha: 0.08)
                                      : AppTheme.glassBg(context),
                                  borderRadius:
                                      BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.gold1
                                            .withValues(alpha: 0.5)
                                        : AppTheme.glassBorder(context),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      lang.flag,
                                      style:
                                          const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lang.nativeName,
                                            style: GoogleFonts.jost(
                                              color: isSelected
                                                  ? AppTheme.goldColor(
                                                      context)
                                                  : AppTheme.text1(
                                                      context),
                                              fontSize: 16,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            lang.name,
                                            style: GoogleFonts.jost(
                                              color: AppTheme.text2(
                                                  context),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (lang.isRTL)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                            right: 8),
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.glassBg(
                                                context),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'RTL',
                                            style: GoogleFonts.jost(
                                              color: AppTheme.textMuted(
                                                  context),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color:
                                            AppTheme.goldColor(context),
                                        size: 24,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // Continue button
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppTheme.goldCTAButton(
                      label: l10n.translate('continue_btn'),
                      onPressed: _saveLanguageAndContinue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
