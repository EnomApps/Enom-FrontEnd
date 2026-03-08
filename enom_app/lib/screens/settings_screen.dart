import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentThemeMode = EnomApp.getThemeMode(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Appearance section
          _buildSectionTitle(l10n.translate('appearance'), isDark),
          const SizedBox(height: 12),
          _buildThemeCard(context, l10n, isDark, currentThemeMode),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        color: const Color(0xFFD4AF37),
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildThemeCard(
    BuildContext context,
    AppLocalizations l10n,
    bool isDark,
    ThemeMode currentMode,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          _buildThemeOption(
            context: context,
            icon: Icons.brightness_auto,
            title: l10n.translate('system_default'),
            isSelected: currentMode == ThemeMode.system,
            isDark: isDark,
            onTap: () => EnomApp.setThemeMode(context, ThemeMode.system),
          ),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          _buildThemeOption(
            context: context,
            icon: Icons.light_mode,
            title: l10n.translate('light_mode'),
            isSelected: currentMode == ThemeMode.light,
            isDark: isDark,
            onTap: () => EnomApp.setThemeMode(context, ThemeMode.light),
          ),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
          _buildThemeOption(
            context: context,
            icon: Icons.dark_mode,
            title: l10n.translate('dark_mode'),
            isSelected: currentMode == ThemeMode.dark,
            isDark: isDark,
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
    required bool isDark,
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
                  ? const Color(0xFFD4AF37)
                  : isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : Colors.black.withValues(alpha: 0.5),
              size: 24,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFD4AF37),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
