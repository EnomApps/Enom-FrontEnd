import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';

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
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  String? _selectedGender;
  DateTime? _selectedDob;
  String _selectedCountryCode = '+1';

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _initControllers();
    _fetchProfile();
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
    _bioController = TextEditingController(text: _user?['bio'] as String? ?? '');
    _locationController = TextEditingController(text: _user?['location'] as String? ?? '');
    _selectedGender = _user?['gender'] as String?;
    final dobStr = _user?['dob'] as String?;
    _selectedDob = dobStr != null ? DateTime.tryParse(dobStr) : null;

    // Parse phone: extract country code and number
    final rawPhone = _user?['phone'] as String? ?? '';
    if (rawPhone.startsWith('+')) {
      // Try to split country code from number
      final match = RegExp(r'^(\+\d{1,4})(.*)$').firstMatch(rawPhone);
      if (match != null) {
        _selectedCountryCode = match.group(1)!;
        _phoneController = TextEditingController(text: match.group(2)?.trim() ?? '');
      } else {
        _selectedCountryCode = '+1';
        _phoneController = TextEditingController(text: rawPhone);
      }
    } else {
      _selectedCountryCode = '+1';
      _phoneController = TextEditingController(text: rawPhone);
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
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.black,
              surface: Color(0xFF121212),
              onSurface: Colors.white,
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

    final result = await AuthService.updateProfile(
      name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
      phone: _phoneController.text.trim().isNotEmpty
          ? '$_selectedCountryCode${_phoneController.text.trim()}'
          : null,
      gender: _selectedGender,
      dob: _selectedDob != null
          ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
          : null,
      bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
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
      _showSnackBar(result.message, isError: false);
    } else {
      _showSnackBar(result.message, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFFD4AF37),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading && _user == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildProfileImage(),
          const SizedBox(height: 16),
          if (!_isEditing) ...[
            Text(
              _user?['name'] as String? ?? '',
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _user?['email'] as String? ?? '',
              style: TextStyle(
                color: textColor.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            _buildInfoCard(Icons.phone_outlined, l10n.translate('phone'), _user?['phone'] as String?),
            _buildInfoCard(Icons.person_outline, l10n.translate('gender'), _genderDisplay(l10n)),
            _buildInfoCard(Icons.cake_outlined, l10n.translate('date_of_birth'), _dobDisplay()),
            _buildInfoCard(Icons.info_outline, l10n.translate('bio'), _user?['bio'] as String?),
            _buildInfoCard(Icons.location_on_outlined, l10n.translate('location'), _user?['location'] as String?),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
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
            _buildPhoneField(l10n),
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
            _buildTextField(
              controller: _locationController,
              label: l10n.translate('location'),
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancelEditing,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(color: textColor.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
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
    );
  }

  Widget _buildProfileImage() {
    final profileImageUrl = _user?['profile_image_url'] as String?;
    final hasNetworkImage = profileImageUrl != null && profileImageUrl.isNotEmpty;
    final hasPicked = _pickedImageBytes != null;

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
            color: const Color(0xFF121212),
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFD4AF37),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 104,
            height: 104,
            color: const Color(0xFF121212),
            child: const Icon(Icons.person, size: 52, color: Color(0xFFD4AF37)),
          );
        },
      );
    } else {
      imageWidget = Container(
        width: 104,
        height: 104,
        color: const Color(0xFF121212),
        child: const Icon(Icons.person, size: 52, color: Color(0xFFD4AF37)),
      );
    }

    return Stack(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
          ),
          padding: const EdgeInsets.all(3),
          child: ClipOval(child: imageWidget),
        ),
        if (_isEditing)
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFD4AF37),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String? value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value != null && value.isNotEmpty ? value : '—',
                  style: TextStyle(
                    color: value != null && value.isNotEmpty
                        ? textColor
                        : textColor.withValues(alpha: 0.2),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: const Color(0xFFD4AF37).withValues(alpha: 0.7)),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: textColor.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
      ),
    );
  }

  static const List<String> _countryCodes = [
    '+1', '+7', '+20', '+27', '+30', '+31', '+32', '+33', '+34', '+36',
    '+39', '+40', '+41', '+43', '+44', '+45', '+46', '+47', '+48', '+49',
    '+51', '+52', '+53', '+54', '+55', '+56', '+57', '+58', '+60', '+61',
    '+62', '+63', '+64', '+65', '+66', '+81', '+82', '+84', '+86', '+90',
    '+91', '+92', '+93', '+94', '+95', '+98', '+212', '+213', '+216',
    '+218', '+220', '+221', '+222', '+223', '+224', '+225', '+226', '+227',
    '+228', '+229', '+230', '+231', '+232', '+233', '+234', '+235', '+236',
    '+237', '+238', '+239', '+240', '+241', '+242', '+243', '+244', '+245',
    '+246', '+247', '+248', '+249', '+250', '+251', '+252', '+253', '+254',
    '+255', '+256', '+257', '+258', '+260', '+261', '+262', '+263', '+264',
    '+265', '+266', '+267', '+268', '+269', '+290', '+291', '+297', '+298',
    '+299', '+350', '+351', '+352', '+353', '+354', '+355', '+356', '+357',
    '+358', '+359', '+370', '+371', '+372', '+373', '+374', '+375', '+376',
    '+377', '+378', '+380', '+381', '+382', '+383', '+385', '+386', '+387',
    '+389', '+420', '+421', '+423', '+500', '+501', '+502', '+503', '+504',
    '+505', '+506', '+507', '+508', '+509', '+590', '+591', '+592', '+593',
    '+594', '+595', '+596', '+597', '+598', '+599', '+670', '+672', '+673',
    '+674', '+675', '+676', '+677', '+678', '+679', '+680', '+681', '+682',
    '+683', '+685', '+686', '+687', '+688', '+689', '+690', '+691', '+692',
    '+850', '+852', '+853', '+855', '+856', '+880', '+886', '+960', '+961',
    '+962', '+963', '+964', '+965', '+966', '+967', '+968', '+970', '+971',
    '+972', '+973', '+974', '+975', '+976', '+977', '+992', '+993', '+994',
    '+995', '+996', '+998',
  ];

  Widget _buildPhoneField(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08);
    final borderColor = textColor.withValues(alpha: 0.1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Country code dropdown
        SizedBox(
          width: 100,
          child: DropdownButtonFormField<String>(
            value: _countryCodes.contains(_selectedCountryCode) ? _selectedCountryCode : '+1',
            dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
            style: TextStyle(color: textColor, fontSize: 14),
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.translate('phone'),
              labelStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 12),
              prefixIcon: Icon(Icons.public, color: const Color(0xFFD4AF37).withValues(alpha: 0.7), size: 20),
              filled: true,
              fillColor: fillColor,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
            ),
            items: _countryCodes.map((code) {
              return DropdownMenuItem(value: code, child: Text(code));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedCountryCode = val);
            },
          ),
        ),
        const SizedBox(width: 10),
        // Phone number field
        Expanded(
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: l10n.translate('phone'),
              labelStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
              prefixIcon: Icon(Icons.phone_outlined, color: const Color(0xFFD4AF37).withValues(alpha: 0.7)),
              filled: true,
              fillColor: fillColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFD4AF37)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08);
    final borderColor = textColor.withValues(alpha: 0.1);

    return DropdownButtonFormField<String>(
      value: _selectedGender,
      dropdownColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        labelText: l10n.translate('gender'),
        labelStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
        prefixIcon: Icon(Icons.wc_outlined, color: const Color(0xFFD4AF37).withValues(alpha: 0.7)),
        filled: true,
        fillColor: fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
      ),
      items: [
        DropdownMenuItem(value: 'male', child: Text(l10n.translate('male'))),
        DropdownMenuItem(value: 'female', child: Text(l10n.translate('female'))),
        DropdownMenuItem(value: 'other', child: Text(l10n.translate('other_gender'))),
      ],
      onChanged: (val) => setState(() => _selectedGender = val),
    );
  }

  Widget _buildDateField(AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final fillColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08);
    final borderColor = textColor.withValues(alpha: 0.1);

    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextField(
          style: TextStyle(color: textColor),
          controller: TextEditingController(
            text: _selectedDob != null
                ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
                : '',
          ),
          decoration: InputDecoration(
            labelText: l10n.translate('date_of_birth'),
            labelStyle: TextStyle(color: textColor.withValues(alpha: 0.4)),
            prefixIcon: Icon(Icons.cake_outlined, color: const Color(0xFFD4AF37).withValues(alpha: 0.7)),
            suffixIcon: Icon(Icons.calendar_today, color: textColor.withValues(alpha: 0.3), size: 20),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD4AF37)),
            ),
          ),
        ),
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
}
