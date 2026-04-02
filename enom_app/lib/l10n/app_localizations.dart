import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalizations {
  final Locale locale;
  Map<String, String> _localizedStrings = {};

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// Loads translations from the JSON file for the current locale.
  Future<bool> load() async {
    try {
      final jsonString = await rootBundle.loadString(
          'assets/translations/${locale.languageCode}.json');
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedStrings =
          jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      // Fallback: load English if the locale file is missing
      try {
        final jsonString =
            await rootBundle.loadString('assets/translations/en.json');
        final Map<String, dynamic> jsonMap = json.decode(jsonString);
        _localizedStrings =
            jsonMap.map((key, value) => MapEntry(key, value.toString()));
      } catch (_) {
        _localizedStrings = {};
      }
    }
    return true;
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }

  /// RTL language codes
  static const Set<String> rtlLanguages = {'ar', 'fa', 'he', 'ur', 'sd', 'prs', 'ps'};

  static bool isRTL(String languageCode) =>
      rtlLanguages.contains(languageCode);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
