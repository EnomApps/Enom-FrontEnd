import 'dart:ui' show Locale;

class LanguageModel {
  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final bool isRTL;

  const LanguageModel({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    this.isRTL = false,
  });

  static const List<LanguageModel> supportedLanguages = [
    // English
    LanguageModel(code: 'en', name: 'English', nativeName: 'English', flag: '🇺🇸'),

    // --- 22 Official Indian Languages ---
    LanguageModel(code: 'as', name: 'Assamese', nativeName: 'অসমীয়া', flag: '🇮🇳'),
    LanguageModel(code: 'bn', name: 'Bengali', nativeName: 'বাংলা', flag: '🇮🇳'),
    LanguageModel(code: 'brx', name: 'Bodo', nativeName: 'बड़ो', flag: '🇮🇳'),
    LanguageModel(code: 'doi', name: 'Dogri', nativeName: 'डोगरी', flag: '🇮🇳'),
    LanguageModel(code: 'gu', name: 'Gujarati', nativeName: 'ગુજરાતી', flag: '🇮🇳'),
    LanguageModel(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', flag: '🇮🇳'),
    LanguageModel(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ', flag: '🇮🇳'),
    LanguageModel(code: 'ks', name: 'Kashmiri', nativeName: 'कॉशुर', flag: '🇮🇳'),
    LanguageModel(code: 'kok', name: 'Konkani', nativeName: 'कोंकणी', flag: '🇮🇳'),
    LanguageModel(code: 'mai', name: 'Maithili', nativeName: 'मैथिली', flag: '🇮🇳'),
    LanguageModel(code: 'ml', name: 'Malayalam', nativeName: 'മലയാളം', flag: '🇮🇳'),
    LanguageModel(code: 'mni', name: 'Manipuri', nativeName: 'মণিপুরী', flag: '🇮🇳'),
    LanguageModel(code: 'mr', name: 'Marathi', nativeName: 'मराठी', flag: '🇮🇳'),
    LanguageModel(code: 'ne', name: 'Nepali', nativeName: 'नेपाली', flag: '🇳🇵'),
    LanguageModel(code: 'or', name: 'Odia', nativeName: 'ଓଡ଼ିଆ', flag: '🇮🇳'),
    LanguageModel(code: 'pa', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', flag: '🇮🇳'),
    LanguageModel(code: 'sa', name: 'Sanskrit', nativeName: 'संस्कृतम्', flag: '🇮🇳'),
    LanguageModel(code: 'sat', name: 'Santali', nativeName: 'ᱥᱟᱱᱛᱟᱲᱤ', flag: '🇮🇳'),
    LanguageModel(code: 'sd', name: 'Sindhi', nativeName: 'سنڌي', flag: '🇮🇳', isRTL: true),
    LanguageModel(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', flag: '🇮🇳'),
    LanguageModel(code: 'te', name: 'Telugu', nativeName: 'తెలుగు', flag: '🇮🇳'),
    LanguageModel(code: 'ur', name: 'Urdu', nativeName: 'اردو', flag: '🇵🇰', isRTL: true),

    // --- RTL Languages ---
    LanguageModel(code: 'ar', name: 'Arabic', nativeName: 'العربية', flag: '🇸🇦', isRTL: true),
    LanguageModel(code: 'fa', name: 'Persian', nativeName: 'فارسی', flag: '🇮🇷', isRTL: true),
    LanguageModel(code: 'he', name: 'Hebrew', nativeName: 'עברית', flag: '🇮🇱', isRTL: true),

    // --- African ---
    LanguageModel(code: 'sw', name: 'Swahili', nativeName: 'Kiswahili', flag: '🇰🇪'),
    LanguageModel(code: 'ha', name: 'Hausa', nativeName: 'Hausa', flag: '🇳🇬'),
    LanguageModel(code: 'am', name: 'Amharic', nativeName: 'አማርኛ', flag: '🇪🇹'),
    LanguageModel(code: 'yo', name: 'Yoruba', nativeName: 'Yorùbá', flag: '🇳🇬'),
    LanguageModel(code: 'ig', name: 'Igbo', nativeName: 'Igbo', flag: '🇳🇬'),
    LanguageModel(code: 'om', name: 'Oromo', nativeName: 'Afaan Oromoo', flag: '🇪🇹'),
    LanguageModel(code: 'zu', name: 'Zulu', nativeName: 'isiZulu', flag: '🇿🇦'),

    // --- Middle Eastern / Central Asian ---
    LanguageModel(code: 'tr', name: 'Turkish', nativeName: 'Türkçe', flag: '🇹🇷'),
    LanguageModel(code: 'prs', name: 'Dari', nativeName: 'دری', flag: '🇦🇫', isRTL: true),
    LanguageModel(code: 'ps', name: 'Pashto', nativeName: 'پښتو', flag: '🇦🇫', isRTL: true),

    // --- Southeast Asian ---
    LanguageModel(code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu', flag: '🇲🇾'),
    LanguageModel(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia', flag: '🇮🇩'),
    LanguageModel(code: 'th', name: 'Thai', nativeName: 'ไทย', flag: '🇹🇭'),
    LanguageModel(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt', flag: '🇻🇳'),
    LanguageModel(code: 'fil', name: 'Filipino', nativeName: 'Filipino', flag: '🇵🇭'),
    LanguageModel(code: 'tl', name: 'Tagalog', nativeName: 'Tagalog', flag: '🇵🇭'),
    LanguageModel(code: 'my', name: 'Burmese', nativeName: 'ဗမာစာ', flag: '🇲🇲'),
    LanguageModel(code: 'km', name: 'Khmer', nativeName: 'ខ្មែរ', flag: '🇰🇭'),
    LanguageModel(code: 'lo', name: 'Lao', nativeName: 'ລາວ', flag: '🇱🇦'),
    LanguageModel(code: 'tet', name: 'Tetum', nativeName: 'Tetun', flag: '🇹🇱'),

    // --- South Asian ---
    LanguageModel(code: 'si', name: 'Sinhalese', nativeName: 'සිංහල', flag: '🇱🇰'),

    // --- East Asian ---
    LanguageModel(code: 'ja', name: 'Japanese', nativeName: '日本語', flag: '🇯🇵'),
    LanguageModel(code: 'ko', name: 'Korean', nativeName: '한국어', flag: '🇰🇷'),
    LanguageModel(code: 'zh', name: 'Chinese', nativeName: '中文', flag: '🇨🇳'),

    // --- Pacific / Oceanian ---
    LanguageModel(code: 'sm', name: 'Samoan', nativeName: 'Gagana Sāmoa', flag: '🇼🇸'),
    LanguageModel(code: 'to', name: 'Tongan', nativeName: 'Lea Fakatonga', flag: '🇹🇴'),
    LanguageModel(code: 'mi', name: 'Maori', nativeName: 'Te Reo Māori', flag: '🇳🇿'),
    LanguageModel(code: 'haw', name: 'Hawaiian', nativeName: 'ʻŌlelo Hawaiʻi', flag: '🇺🇸'),
    LanguageModel(code: 'ty', name: 'Tahitian', nativeName: 'Reo Tahiti', flag: '🇵🇫'),

    // --- European ---
    LanguageModel(code: 'es', name: 'Spanish', nativeName: 'Español', flag: '🇪🇸'),
    LanguageModel(code: 'fr', name: 'French', nativeName: 'Français', flag: '🇫🇷'),
    LanguageModel(code: 'de', name: 'German', nativeName: 'Deutsch', flag: '🇩🇪'),
    LanguageModel(code: 'it', name: 'Italian', nativeName: 'Italiano', flag: '🇮🇹'),
    LanguageModel(code: 'pt', name: 'Portuguese', nativeName: 'Português', flag: '🇧🇷'),
    LanguageModel(code: 'ru', name: 'Russian', nativeName: 'Русский', flag: '🇷🇺'),
    LanguageModel(code: 'uk', name: 'Ukrainian', nativeName: 'Українська', flag: '🇺🇦'),
    LanguageModel(code: 'nl', name: 'Dutch', nativeName: 'Nederlands', flag: '🇳🇱'),
    LanguageModel(code: 'pl', name: 'Polish', nativeName: 'Polski', flag: '🇵🇱'),
    LanguageModel(code: 'cs', name: 'Czech', nativeName: 'Čeština', flag: '🇨🇿'),
    LanguageModel(code: 'ro', name: 'Romanian', nativeName: 'Română', flag: '🇷🇴'),
    LanguageModel(code: 'hu', name: 'Hungarian', nativeName: 'Magyar', flag: '🇭🇺'),
    LanguageModel(code: 'el', name: 'Greek', nativeName: 'Ελληνικά', flag: '🇬🇷'),
    LanguageModel(code: 'sv', name: 'Swedish', nativeName: 'Svenska', flag: '🇸🇪'),
    LanguageModel(code: 'no', name: 'Norwegian', nativeName: 'Norsk', flag: '🇳🇴'),
    LanguageModel(code: 'da', name: 'Danish', nativeName: 'Dansk', flag: '🇩🇰'),
    LanguageModel(code: 'fi', name: 'Finnish', nativeName: 'Suomi', flag: '🇫🇮'),
    LanguageModel(code: 'sk', name: 'Slovak', nativeName: 'Slovenčina', flag: '🇸🇰'),
    LanguageModel(code: 'sq', name: 'Albanian', nativeName: 'Shqip', flag: '🇦🇱'),
    LanguageModel(code: 'sr', name: 'Serbian', nativeName: 'Српски', flag: '🇷🇸'),
    LanguageModel(code: 'et', name: 'Estonian', nativeName: 'Eesti', flag: '🇪🇪'),
    LanguageModel(code: 'bg', name: 'Bulgarian', nativeName: 'Български', flag: '🇧🇬'),
    LanguageModel(code: 'be', name: 'Belarusian', nativeName: 'Беларуская', flag: '🇧🇾'),
  ];

  static List<Locale> get supportedLocales =>
      supportedLanguages.map((l) => Locale(l.code)).toList();
}
