import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentThemeMode = EnomApp.getThemeMode(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Appearance section
          _buildSectionTitle(context, l10n.translate('appearance')),
          const SizedBox(height: 12),
          _buildThemeCard(context, l10n, currentThemeMode),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: AppTheme.heading(context, size: 16),
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    AppLocalizations l10n,
    ThemeMode currentMode,
  ) {
    return Container(
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        children: [
          _buildThemeOption(
            context: context,
            icon: Icons.brightness_auto,
            title: l10n.translate('system_default'),
            isSelected: currentMode == ThemeMode.system,
            onTap: () => EnomApp.setThemeMode(context, ThemeMode.system),
          ),
          Divider(
            height: 1,
            color: AppTheme.cardBorder(context),
          ),
          _buildThemeOption(
            context: context,
            icon: Icons.light_mode,
            title: l10n.translate('light_mode'),
            isSelected: currentMode == ThemeMode.light,
            onTap: () => EnomApp.setThemeMode(context, ThemeMode.light),
          ),
          Divider(
            height: 1,
            color: AppTheme.cardBorder(context),
          ),
          _buildThemeOption(
            context: context,
            icon: Icons.dark_mode,
            title: l10n.translate('dark_mode'),
            isSelected: currentMode == ThemeMode.dark,
            onTap: () => EnomApp.setThemeMode(context, ThemeMode.dark),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.goldColor(context)
                  : AppTheme.text2(context),
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppTheme.text1(context),
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.goldColor(context),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
