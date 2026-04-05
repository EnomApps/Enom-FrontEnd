import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Search / Explore screen — placeholder until API is provided.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Stack(
      children: [
        const EnomScreenBackground(gradientVariant: 2, particleCount: 35),
        SafeArea(
          child: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.moodCardBg(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.glassBorder(context)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.jost(
                      color: AppTheme.text1(context),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: l10n.translate('search_hint'),
                      hintStyle: GoogleFonts.jost(
                        color: AppTheme.textMuted(context),
                        fontSize: 15,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppTheme.textMuted(context),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),

              // Placeholder content
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_rounded,
                        size: 64,
                        color: AppTheme.textMuted(context).withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Search & Explore',
                        style: GoogleFonts.jost(
                          color: AppTheme.textMuted(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Coming soon',
                        style: GoogleFonts.jost(
                          color: AppTheme.textMuted(context).withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
