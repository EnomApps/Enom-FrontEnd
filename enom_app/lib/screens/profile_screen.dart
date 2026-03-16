import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onUserUpdated;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isLoading = false;
  Map<String, dynamic>? _user;
  XFile? _pickedImage;
  Uint8List? _pickedImageBytes;

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  late TextEditingController _countryController;
  late TextEditingController _cityController;
  late TextEditingController _regionController;
  String? _selectedGender;
  DateTime? _selectedDob;
  String? _selectedProfession;
  String? _selectedSocialPersonality;
  String? _selectedPrivacySetting;
  List<String> _selectedContentPreferences = [];
  List<String> _selectedLanguages = [];
  List<int> _selectedInterestIds = [];

  // Available interests from API
  List<Map<String, dynamic>> _availableInterests = [];

  static const List<String> _professions = [
    'Student', 'Entrepreneur', 'Developer', 'Designer',
    'Business Owner', 'Creator', 'Musician', 'Other',
  ];

  static const List<String> _socialPersonalities = [
    'Creator', 'Viewer', 'Influencer', 'Business', 'Community Builder',
  ];

  static const List<String> _privacySettings = [
    'public', 'private', 'friends_only',
  ];

  static const List<String> _contentPreferenceOptions = [
    'Short videos', 'Articles', 'Podcasts', 'Live streams',
    'Photos', 'Stories', 'Tutorials', 'News',
  ];

  static const List<String> _languageOptions = [
    'English', 'Hindi', 'Tamil', 'Telugu', 'Malayalam', 'Kannada',
    'Bengali', 'Marathi', 'Gujarati', 'Punjabi', 'Urdu',
    'Spanish', 'French', 'German', 'Arabic', 'Chinese',
    'Japanese', 'Korean', 'Portuguese', 'Russian',
  ];

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _initControllers();
    _fetchProfile();
    _fetchInterests();
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user != oldWidget.user) {
      _user = widget.user;
      _initControllers();
    }
  }

  void _initControllers() {
    _nameController = TextEditingController(text: _user?['name'] as String? ?? '');
    _usernameController = TextEditingController(text: _user?['username'] as String? ?? '');
    _bioController = TextEditingController(text: _user?['bio'] as String? ?? '');
    _locationController = TextEditingController(text: _user?['location'] as String? ?? '');
    _countryController = TextEditingController(text: _user?['country'] as String? ?? '');
    _cityController = TextEditingController(text: _user?['city'] as String? ?? '');
    _regionController = TextEditingController(text: _user?['region'] as String? ?? '');
    _selectedGender = _user?['gender'] as String?;
    _selectedProfession = _user?['profession'] as String?;
    _selectedSocialPersonality = _user?['social_personality'] as String?;
    _selectedPrivacySetting = _user?['privacy_setting'] as String? ?? 'public';

    final dobStr = _user?['dob'] as String?;
    _selectedDob = dobStr != null ? DateTime.tryParse(dobStr) : null;

    // Parse content_preferences
    final cpRaw = _user?['content_preferences'];
    if (cpRaw is List) {
      _selectedContentPreferences = cpRaw.map((e) => e.toString()).toList();
    } else if (cpRaw is String && cpRaw.isNotEmpty) {
      try {
        final decoded = json.decode(cpRaw);
        if (decoded is List) {
          _selectedContentPreferences = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        _selectedContentPreferences = [];
      }
    } else {
      _selectedContentPreferences = [];
    }

    // Parse languages
    final langRaw = _user?['languages'];
    if (langRaw is List) {
      _selectedLanguages = langRaw.map((e) => e.toString()).toList();
    } else if (langRaw is String && langRaw.isNotEmpty) {
      try {
        final decoded = json.decode(langRaw);
        if (decoded is List) {
          _selectedLanguages = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        _selectedLanguages = [];
      }
    } else {
      _selectedLanguages = [];
    }

    // Parse interests
    final interestsRaw = _user?['interests'];
    if (interestsRaw is List) {
      _selectedInterestIds = interestsRaw
          .map((e) => e is Map ? (e['id'] as int?) : null)
          .whereType<int>()
          .toList();
    } else {
      _selectedInterestIds = [];
    }
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.getProfile();
      if (mounted && result.success && result.user != null) {
        setState(() {
          _user = result.user;
          _isLoading = false;
        });
        _initControllers();
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchInterests() async {
    try {
      final result = await AuthService.getInterests();
      if (mounted && result.success) {
        setState(() => _availableInterests = result.interests);
      }
    } catch (_) {}
  }

  void _startEditing() {
    _initControllers();
    _pickedImage = null;
    _pickedImageBytes = null;
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    _pickedImage = null;
    _pickedImageBytes = null;
    setState(() => _isEditing = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked != null && mounted) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _pickedImage = picked;
        _pickedImageBytes = bytes;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (context, child) {
        final g = AppTheme.goldColor(context);
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme(
              brightness: AppTheme.isDark(context) ? Brightness.dark : Brightness.light,
              primary: g,
              onPrimary: AppTheme.isDark(context) ? Colors.black : Colors.white,
              surface: AppTheme.bg(context),
              onSurface: AppTheme.text1(context),
              secondary: g,
              onSecondary: AppTheme.isDark(context) ? Colors.black : Colors.white,
              error: Colors.redAccent,
              onError: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _selectedDob = picked);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final result = await AuthService.updateProfile(
        name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
        username: _usernameController.text.trim().isNotEmpty ? _usernameController.text.trim() : null,
        gender: _selectedGender,
        dob: _selectedDob != null
            ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
            : null,
        bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
        location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        profession: _selectedProfession,
        country: _countryController.text.trim().isNotEmpty ? _countryController.text.trim() : null,
        city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
        region: _regionController.text.trim().isNotEmpty ? _regionController.text.trim() : null,
        contentPreferences: _selectedContentPreferences.isNotEmpty
            ? json.encode(_selectedContentPreferences)
            : null,
        socialPersonality: _selectedSocialPersonality,
        languages: _selectedLanguages.isNotEmpty
            ? json.encode(_selectedLanguages)
            : null,
        privacySetting: _selectedPrivacySetting,
        interestIds: _selectedInterestIds.isNotEmpty
            ? _selectedInterestIds.join(',')
            : null,
        imagePath: (!kIsWeb && _pickedImage != null) ? _pickedImage!.path : null,
        imageBytes: _pickedImageBytes,
        imageFileName: _pickedImage?.name,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (result.success) {
        setState(() {
          _isEditing = false;
          if (result.user != null) _user = result.user;
          _pickedImage = null;
          _pickedImageBytes = null;
        });
        widget.onUserUpdated();
        AppTheme.showSnackBar(context, result.message, isError: false);
      } else {
        AppTheme.showSnackBar(context, result.message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      AppTheme.showSnackBar(context, 'Network error: $e', isError: true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading && _user == null) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.goldColor(context)),
      );
    }

    return Stack(
      children: [
        const EnomScreenBackground(gradientVariant: 2, particleCount: 10),
        SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildProfileImage(),
          const SizedBox(height: 16),
          if (!_isEditing) ...[
            Text(
              _user?['name'] as String? ?? '',
              style: AppTheme.heading(context, size: 18),
            ),
            if ((_user?['username'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                '@${_user!['username']}',
                style: GoogleFonts.cormorantGaramond(
                  color: AppTheme.goldColor(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              _user?['email'] as String? ?? '',
              style: TextStyle(
                color: AppTheme.text2(context),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            _buildStatsRow(),
            const SizedBox(height: 20),
            AppTheme.goldDivider(context),
            const SizedBox(height: 20),
            _buildMenuRow(Icons.analytics_outlined, 'Mood Analytics', onTap: () {}),
            _buildMenuRow(Icons.notifications_outlined, 'Notifications', onTap: () {}),
            _buildMenuRow(Icons.shield_outlined, 'Privacy & Security', onTap: () {}),
            _buildPremiumRow(),
            AppTheme.goldDivider(context),
            const SizedBox(height: 20),
            _buildInfoCard(Icons.alternate_email, l10n.translate('username'), _user?['username'] as String?),
            _buildInfoCard(Icons.person_outline, l10n.translate('gender'), _genderDisplay(l10n)),
            _buildInfoCard(Icons.cake_outlined, l10n.translate('date_of_birth'), _dobDisplay()),
            _buildInfoCard(Icons.info_outline, l10n.translate('bio'), _user?['bio'] as String?),
            _buildInfoCard(Icons.work_outline, 'Profession', _user?['profession'] as String?),
            _buildInfoCard(Icons.location_on_outlined, l10n.translate('location'), _user?['location'] as String?),
            _buildInfoCard(Icons.flag_outlined, 'Country', _user?['country'] as String?),
            _buildInfoCard(Icons.location_city_outlined, 'City', _user?['city'] as String?),
            _buildInfoCard(Icons.map_outlined, 'Region', _user?['region'] as String?),
            _buildInfoCard(Icons.psychology_outlined, 'Social Personality', _user?['social_personality'] as String?),
            _buildInfoCard(Icons.lock_outline, 'Privacy', _privacyDisplay()),
            _buildChipsCard(Icons.video_library_outlined, 'Content Preferences', _contentPrefsDisplay()),
            _buildChipsCard(Icons.language, 'Languages', _languagesDisplay()),
            _buildChipsCard(Icons.interests_outlined, 'Interests', _interestsDisplay()),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startEditing,
                icon: const Icon(Icons.edit, size: 20),
                label: Text(
                  l10n.translate('edit_profile'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: AppTheme.primaryButton(context),
              ),
            ),
          ],
          if (_isEditing) ...[
            const SizedBox(height: 24),
            _buildTextField(
              controller: _nameController,
              label: l10n.translate('full_name'),
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _usernameController,
              label: l10n.translate('username'),
              icon: Icons.alternate_email,
            ),
            const SizedBox(height: 16),
            _buildGenderDropdown(l10n),
            const SizedBox(height: 16),
            _buildDateField(l10n),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _bioController,
              label: l10n.translate('bio'),
              icon: Icons.info_outline,
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              label: 'Profession',
              icon: Icons.work_outline,
              value: _selectedProfession,
              items: _professions,
              onChanged: (val) => setState(() => _selectedProfession = val),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _locationController,
              label: l10n.translate('location'),
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _countryController,
              label: 'Country',
              icon: Icons.flag_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _cityController,
              label: 'City',
              icon: Icons.location_city_outlined,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _regionController,
              label: 'Region',
              icon: Icons.map_outlined,
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              label: 'Social Personality',
              icon: Icons.psychology_outlined,
              value: _selectedSocialPersonality,
              items: _socialPersonalities,
              onChanged: (val) => setState(() => _selectedSocialPersonality = val),
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              label: 'Privacy Setting',
              icon: Icons.lock_outline,
              value: _selectedPrivacySetting,
              items: _privacySettings,
              onChanged: (val) => setState(() => _selectedPrivacySetting = val),
            ),
            const SizedBox(height: 16),
            _buildMultiSelectChips(
              label: 'Content Preferences',
              icon: Icons.video_library_outlined,
              options: _contentPreferenceOptions,
              selected: _selectedContentPreferences,
              onChanged: (list) => setState(() => _selectedContentPreferences = list),
            ),
            const SizedBox(height: 16),
            _buildMultiSelectChips(
              label: 'Languages',
              icon: Icons.language,
              options: _languageOptions,
              selected: _selectedLanguages,
              onChanged: (list) => setState(() => _selectedLanguages = list),
            ),
            const SizedBox(height: 16),
            if (_availableInterests.isNotEmpty)
              _buildInterestsSelector(),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancelEditing,
                      style: AppTheme.outlineButton(context),
                      child: Text(l10n.translate('cancel'), style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: AppTheme.primaryButton(context),
                      child: _isSaving
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.toggleBg(context),
                              ),
                            )
                          : Text(l10n.translate('save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    ),
      ],
    );
  }

  Widget _buildProfileImage() {
    // API may return 'profile_image_url' (full URL) or 'profile_image' (relative path)
    var profileImageUrl = _user?['profile_image_url'] as String? ?? _user?['profile_image'] as String?;
    if (profileImageUrl != null && profileImageUrl.isNotEmpty && !profileImageUrl.startsWith('http')) {
      profileImageUrl = '${ApiService.baseUrl}/storage/$profileImageUrl';
    }
    final hasNetworkImage = profileImageUrl != null && profileImageUrl.isNotEmpty;
    final hasPicked = _pickedImageBytes != null;

    final goldC = AppTheme.goldColor(context);
    final goldF = AppTheme.goldFill(context);

    Widget imageWidget;
    if (hasPicked) {
      imageWidget = Image.memory(
        _pickedImageBytes!,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
      );
    } else if (hasNetworkImage) {
      imageWidget = Image.network(
        profileImageUrl,
        width: 104,
        height: 104,
        fit: BoxFit.cover,
        cacheWidth: 300,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 104,
            height: 104,
            color: AppTheme.bg2(context),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: goldC,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 104,
            height: 104,
            color: AppTheme.bg2(context),
            child: Icon(Icons.person, size: 52, color: goldC),
          );
        },
      );
    } else {
      imageWidget = Container(
        width: 104,
        height: 104,
        color: AppTheme.bg2(context),
        child: Icon(Icons.person, size: 52, color: goldC),
      );
    }

    return Stack(
      children: [
        Container(
          width: 114,
          height: 114,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [goldC, goldC.withValues(alpha: 0.5)],
            ),
            boxShadow: [
              BoxShadow(
                color: goldF,
                blurRadius: 24,
                spreadRadius: 6,
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.bg(context),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipOval(child: imageWidget),
          ),
        ),
        if (_isEditing)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: goldC,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt, size: 20, color: AppTheme.toggleBg(context)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('0', 'Entries'),
        _buildStatDivider(),
        _buildStatItem('0', 'Streak'),
        _buildStatDivider(),
        _buildStatItem('0', 'Friends'),
      ],
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: AppTheme.heading(context, size: 16)),
        const SizedBox(height: 2),
        Text(label, style: AppTheme.label(context)),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      width: 1,
      height: 28,
      color: AppTheme.cardBorder(context),
    );
  }

  Widget _buildMenuRow(IconData icon, String title, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.goldColor(context), size: 22),
        title: Text(
          title,
          style: TextStyle(color: AppTheme.text1(context), fontSize: 14),
        ),
        trailing: Icon(Icons.chevron_right, color: AppTheme.text2(context), size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Widget _buildPremiumRow() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 4),
      decoration: AppTheme.cardDecoration(context),
      child: ListTile(
        leading: Icon(Icons.workspace_premium, color: AppTheme.goldColor(context), size: 22),
        title: Text(
          'ENOM Premium',
          style: TextStyle(color: AppTheme.text1(context), fontSize: 14),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.goldFill(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.goldColor(context).withValues(alpha: 0.3)),
          ),
          child: Text(
            'UPGRADE',
            style: GoogleFonts.dmSans(
              color: AppTheme.goldColor(context),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        onTap: () {},
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String? value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.goldColor(context), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTheme.label(context, size: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  value != null && value.isNotEmpty ? value : '—',
                  style: TextStyle(
                    color: value != null && value.isNotEmpty
                        ? AppTheme.text1(context)
                        : AppTheme.text2(context),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipsCard(IconData icon, String label, List<String> items) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.goldColor(context), size: 22),
              const SizedBox(width: 14),
              Text(
                label,
                style: AppTheme.label(context, size: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text('—', style: TextStyle(color: AppTheme.text2(context), fontSize: 15))
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: items.map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.goldFill(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.goldColor(context).withValues(alpha: 0.3)),
                ),
                child: Text(
                  item,
                  style: TextStyle(color: AppTheme.text1(context), fontSize: 13),
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: AppTheme.text1(context)),
      decoration: AppTheme.inputDecoration(context, hint: label, prefixIcon: icon),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : null,
      dropdownColor: AppTheme.isDark(context) ? const Color(0xFF111111) : Colors.white,
      style: TextStyle(color: AppTheme.text1(context)),
      decoration: AppTheme.inputDecoration(context, hint: label, prefixIcon: icon),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildGenderDropdown(AppLocalizations l10n) {
    return _buildDropdownField(
      label: l10n.translate('gender'),
      icon: Icons.wc_outlined,
      value: _selectedGender,
      items: const ['male', 'female', 'other'],
      onChanged: (val) => setState(() => _selectedGender = val),
    );
  }

  Widget _buildDateField(AppLocalizations l10n) {
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextField(
          style: TextStyle(color: AppTheme.text1(context)),
          controller: TextEditingController(
            text: _selectedDob != null
                ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
                : '',
          ),
          decoration: AppTheme.inputDecoration(
            context,
            hint: l10n.translate('date_of_birth'),
            prefixIcon: Icons.cake_outlined,
            suffixIcon: Icon(Icons.calendar_today, color: AppTheme.text2(context), size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectChips({
    required String label,
    required IconData icon,
    required List<String> options,
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
  }) {
    final goldC = AppTheme.goldColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.inputBg(context),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.inputBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: goldC.withValues(alpha: 0.7), size: 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(color: AppTheme.text2(context), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              final isSelected = selected.contains(option);
              return FilterChip(
                label: Text(
                  option,
                  style: TextStyle(
                    color: isSelected ? AppTheme.toggleBg(context) : AppTheme.text1(context),
                    fontSize: 13,
                  ),
                ),
                selected: isSelected,
                selectedColor: goldC,
                backgroundColor: AppTheme.cardBg(context),
                checkmarkColor: AppTheme.toggleBg(context),
                side: BorderSide(
                  color: isSelected
                      ? goldC
                      : AppTheme.cardBorder(context),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (val) {
                  final updated = List<String>.from(selected);
                  if (val) {
                    updated.add(option);
                  } else {
                    updated.remove(option);
                  }
                  onChanged(updated);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSelector() {
    final goldC = AppTheme.goldColor(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.inputBg(context),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.inputBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.interests_outlined, color: goldC.withValues(alpha: 0.7), size: 22),
              const SizedBox(width: 10),
              Text(
                'Interests (max 10)',
                style: TextStyle(color: AppTheme.text2(context), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableInterests.map((interest) {
              final id = interest['id'] as int;
              final name = interest['name'] as String? ?? '';
              final isSelected = _selectedInterestIds.contains(id);
              return FilterChip(
                label: Text(
                  name,
                  style: TextStyle(
                    color: isSelected ? AppTheme.toggleBg(context) : AppTheme.text1(context),
                    fontSize: 13,
                  ),
                ),
                selected: isSelected,
                selectedColor: goldC,
                backgroundColor: AppTheme.cardBg(context),
                checkmarkColor: AppTheme.toggleBg(context),
                side: BorderSide(
                  color: isSelected
                      ? goldC
                      : AppTheme.cardBorder(context),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      if (_selectedInterestIds.length < 10) {
                        _selectedInterestIds.add(id);
                      } else {
                        AppTheme.showSnackBar(context, 'Maximum 10 interests allowed', isError: true);
                      }
                    } else {
                      _selectedInterestIds.remove(id);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String? _genderDisplay(AppLocalizations l10n) {
    final gender = _user?['gender'] as String?;
    if (gender == null) return null;
    switch (gender) {
      case 'male':
        return l10n.translate('male');
      case 'female':
        return l10n.translate('female');
      case 'other':
        return l10n.translate('other_gender');
      default:
        return gender;
    }
  }

  String? _dobDisplay() {
    final dob = _user?['dob'] as String?;
    if (dob == null) return null;
    final date = DateTime.tryParse(dob);
    if (date == null) return dob;
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String? _privacyDisplay() {
    final p = _user?['privacy_setting'] as String?;
    if (p == null) return null;
    switch (p) {
      case 'friends_only':
        return 'Friends Only';
      default:
        return p[0].toUpperCase() + p.substring(1);
    }
  }

  List<String> _contentPrefsDisplay() {
    final raw = _user?['content_preferences'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  List<String> _languagesDisplay() {
    final raw = _user?['languages'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) return decoded.map((e) => e.toString()).toList();
      } catch (_) {}
    }
    return [];
  }

  List<String> _interestsDisplay() {
    final raw = _user?['interests'];
    if (raw is List) {
      return raw.map((e) => e is Map ? (e['name']?.toString() ?? '') : e.toString()).toList();
    }
    return [];
  }
}
