import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

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
  String? _pickedImagePath;

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _locationController;
  String? _selectedGender;
  DateTime? _selectedDob;

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
  }

  Future<void> _fetchProfile() async {
    setState(() => _isLoading = true);
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
  }

  void _startEditing() {
    _initControllers();
    _pickedImagePath = null;
    setState(() => _isEditing = true);
  }

  void _cancelEditing() {
    _pickedImagePath = null;
    setState(() => _isEditing = false);
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800);
    if (picked != null && mounted) {
      setState(() => _pickedImagePath = picked.path);
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
      gender: _selectedGender,
      dob: _selectedDob != null
          ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
          : null,
      bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
      location: _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
      imagePath: _pickedImagePath,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.success) {
      setState(() {
        _isEditing = false;
        if (result.user != null) _user = result.user;
        _pickedImagePath = null;
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Profile image
          _buildProfileImage(),
          const SizedBox(height: 16),
          // Name & email (view mode)
          if (!_isEditing) ...[
            Text(
              _user?['name'] as String? ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _user?['email'] as String? ?? '',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),
            // Info cards
            _buildInfoCard(Icons.person_outline, l10n.translate('gender'), _genderDisplay(l10n)),
            _buildInfoCard(Icons.cake_outlined, l10n.translate('date_of_birth'), _dobDisplay()),
            _buildInfoCard(Icons.info_outline, l10n.translate('bio'), _user?['bio'] as String?),
            _buildInfoCard(Icons.location_on_outlined, l10n.translate('location'), _user?['location'] as String?),
            const SizedBox(height: 24),
            // Edit button
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
          // Edit mode
          if (_isEditing) ...[
            const SizedBox(height: 24),
            _buildTextField(
              controller: _nameController,
              label: l10n.translate('full_name'),
              icon: Icons.person_outline,
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
            _buildTextField(
              controller: _locationController,
              label: l10n.translate('location'),
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 28),
            // Save & Cancel buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancelEditing,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
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
    final profileImage = _user?['profile_image'] as String?;
    final hasNetworkImage = profileImage != null && profileImage.isNotEmpty;

    return Stack(
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: const Color(0xFFD4AF37).withValues(alpha: 0.2),
          child: CircleAvatar(
            radius: 52,
            backgroundColor: const Color(0xFF121212),
            backgroundImage: _pickedImagePath != null
                ? FileImage(File(_pickedImagePath!))
                : hasNetworkImage
                    ? NetworkImage('${ApiService.baseUrl}/storage/$profileImage')
                    : null,
            child: (_pickedImagePath == null && !hasNetworkImage)
                ? const Icon(Icons.person, size: 52, color: Color(0xFFD4AF37))
                : null,
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value != null && value.isNotEmpty ? value : '—',
                  style: TextStyle(
                    color: value != null && value.isNotEmpty
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.2),
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
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        prefixIcon: Icon(icon, color: const Color(0xFFD4AF37).withValues(alpha: 0.7)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4AF37)),
        ),
      ),
    );
  }

  Widget _buildGenderDropdown(AppLocalizations l10n) {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      dropdownColor: const Color(0xFF1A1A1A),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: l10n.translate('gender'),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
        prefixIcon: Icon(Icons.wc_outlined, color: const Color(0xFFD4AF37).withValues(alpha: 0.7)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
    return GestureDetector(
      onTap: _pickDate,
      child: AbsorbPointer(
        child: TextField(
          style: const TextStyle(color: Colors.white),
          controller: TextEditingController(
            text: _selectedDob != null
                ? '${_selectedDob!.year}-${_selectedDob!.month.toString().padLeft(2, '0')}-${_selectedDob!.day.toString().padLeft(2, '0')}'
                : '',
          ),
          decoration: InputDecoration(
            labelText: l10n.translate('date_of_birth'),
            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            prefixIcon: Icon(Icons.cake_outlined, color: const Color(0xFFD4AF37).withValues(alpha: 0.7)),
            suffixIcon: Icon(Icons.calendar_today, color: Colors.white.withValues(alpha: 0.3), size: 20),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
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
