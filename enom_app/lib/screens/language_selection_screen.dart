import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    final filteredLanguages = _filteredLanguages;

    return Scaffold(
      body: Stack(
        children: [
          const GradientBackground(variant: 2),
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
                    style: AppTheme.subheading(context),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      style: AppTheme.body(context).copyWith(
                        color: AppTheme.text1(context),
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search language...',
                        hintStyle: GoogleFonts.dmSans(
                          color: AppTheme.text2(context),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(Icons.search,
                            color: AppTheme.text2(context)),
                        filled: true,
                        fillColor: AppTheme.inputBg(context),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Language count
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${filteredLanguages.length} languages available',
                        style: AppTheme.body(context, size: 12).copyWith(
                          color: AppTheme.text2(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Language list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                setState(() {
                                  _selectedLanguage = lang.code;
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.goldColor(context)
                                          .withValues(alpha: 0.15)
                                      : AppTheme.cardBg(context),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppTheme.goldColor(context)
                                        : AppTheme.cardBorder(context),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      lang.flag,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            lang.nativeName,
                                            style: AppTheme.body(context, size: 16, weight: isSelected ? FontWeight.w600 : FontWeight.normal).copyWith(
                                              color: isSelected
                                                  ? AppTheme.goldColor(context)
                                                  : AppTheme.text1(context),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            lang.name,
                                            style: AppTheme.body(context, size: 12).copyWith(
                                              color: AppTheme.text2(context),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (lang.isRTL)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.cardBg(context),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'RTL',
                                            style: AppTheme.body(context, size: 10, weight: FontWeight.bold).copyWith(
                                              color: AppTheme.text2(context),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        color: AppTheme.goldColor(context),
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
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _saveLanguageAndContinue,
                        style: AppTheme.primaryButton(context),
                        child: const Text(
                          'Continue',
                        ),
                      ),
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
