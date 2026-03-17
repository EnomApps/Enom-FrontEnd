import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final List<_MediaFile> _mediaFiles = [];
  String _visibility = 'public';
  bool _isPosting = false;

  static const int _maxMedia = 10;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  bool get _canPost =>
      _contentController.text.trim().isNotEmpty || _mediaFiles.isNotEmpty;

  Future<void> _pickImages() async {
    if (_mediaFiles.length >= _maxMedia) {
      AppTheme.showSnackBar(context, 'Maximum $_maxMedia media files allowed', isError: true);
      return;
    }

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(maxWidth: 1200);

    if (images.isEmpty) return;

    final remaining = _maxMedia - _mediaFiles.length;
    final toAdd = images.take(remaining);

    for (final img in toAdd) {
      final bytes = await img.readAsBytes();
      if (mounted) {
        setState(() {
          _mediaFiles.add(_MediaFile(
            bytes: bytes,
            name: img.name,
            type: 'image',
          ));
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    if (_mediaFiles.length >= _maxMedia) {
      AppTheme.showSnackBar(context, 'Maximum $_maxMedia media files allowed', isError: true);
      return;
    }

    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );

    if (video == null) return;

    final bytes = await video.readAsBytes();
    if (mounted) {
      setState(() {
        _mediaFiles.add(_MediaFile(
          bytes: bytes,
          name: video.name,
          type: 'video',
        ));
      });
    }
  }

  void _removeMedia(int index) {
    setState(() => _mediaFiles.removeAt(index));
  }

  Future<void> _createPost() async {
    if (!_canPost) return;

    setState(() => _isPosting = true);

    final result = await PostService.createPost(
      content: _contentController.text.trim(),
      visibility: _visibility,
      mediaBytes: _mediaFiles.isNotEmpty ? _mediaFiles.map((f) => f.bytes).toList() : null,
      mediaNames: _mediaFiles.isNotEmpty ? _mediaFiles.map((f) => f.name).toList() : null,
    );

    if (!mounted) return;

    setState(() => _isPosting = false);

    if (result.success) {
      AppTheme.showSnackBar(context, 'Post created successfully!');
      Navigator.of(context).pop(true);
    } else {
      AppTheme.showSnackBar(context, result.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppTheme.text1(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CREATE POST',
          style: AppTheme.label(context, size: 12),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: (_canPost && !_isPosting) ? _createPost : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: (_canPost && !_isPosting) ? AppTheme.goldGradient2 : null,
                  color: (!_canPost || _isPosting) ? AppTheme.glassBg(context) : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isPosting
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: const Color(0xFF1A1612),
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Post',
                        style: GoogleFonts.jost(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _canPost
                              ? const Color(0xFF1A1612)
                              : AppTheme.textMuted(context),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          const EnomScreenBackground(gradientVariant: 2, particleCount: 10),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content input
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.moodCardBg(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.glassBorder(context)),
                        ),
                        child: TextField(
                          controller: _contentController,
                          onChanged: (_) => setState(() {}),
                          maxLines: null,
                          minLines: 6,
                          style: GoogleFonts.jost(
                            color: AppTheme.text1(context),
                            fontSize: 16,
                            height: 1.6,
                          ),
                          decoration: InputDecoration(
                            hintText: "What's on your mind?",
                            hintStyle: GoogleFonts.jost(
                              color: AppTheme.textMuted(context),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(20),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Media preview
                  if (_mediaFiles.isNotEmpty) ...[
                    Text('MEDIA', style: AppTheme.label(context, size: 10)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _mediaFiles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => _buildMediaPreview(i),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action buttons
                  Text('ADD TO POST', style: AppTheme.label(context, size: 10)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.moodCardBg(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.glassBorder(context)),
                        ),
                        child: Row(
                          children: [
                            _buildActionButton(
                              icon: Icons.image_outlined,
                              label: 'Photo',
                              color: Colors.greenAccent,
                              onTap: _pickImages,
                            ),
                            Container(
                              width: 1,
                              height: 32,
                              color: AppTheme.glassBorder(context),
                            ),
                            _buildActionButton(
                              icon: Icons.videocam_outlined,
                              label: 'Video',
                              color: Colors.blueAccent,
                              onTap: _pickVideo,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Visibility picker
                  Text('VISIBILITY', style: AppTheme.label(context, size: 10)),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.moodCardBg(context),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.glassBorder(context)),
                        ),
                        child: Row(
                          children: [
                            _buildVisibilityOption('public', Icons.public, 'Public'),
                            _buildVisibilityOption('followers', Icons.people_outline, 'Followers'),
                            _buildVisibilityOption('private', Icons.lock_outline, 'Private'),
                          ],
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

  Widget _buildMediaPreview(int index) {
    final file = _mediaFiles[index];
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: file.type == 'video'
              ? Container(
                  width: 120,
                  height: 120,
                  color: AppTheme.glassBg(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, color: AppTheme.goldColor(context), size: 32),
                      const SizedBox(height: 4),
                      Text(
                        file.name,
                        style: GoogleFonts.jost(
                          color: AppTheme.textMuted(context),
                          fontSize: 9,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                )
              : Image.memory(
                  file.bytes,
                  width: 120,
                  height: 120,
                  fit: BoxFit.cover,
                ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: () => _removeMedia(index),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.jost(
                  color: AppTheme.text1(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilityOption(String value, IconData icon, String label) {
    final isSelected = _visibility == value;
    final goldC = AppTheme.goldColor(context);

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _visibility = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? goldC.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: goldC.withValues(alpha: 0.3))
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? goldC : AppTheme.textMuted(context),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.jost(
                  fontSize: 11,
                  color: isSelected ? goldC : AppTheme.textMuted(context),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaFile {
  final Uint8List bytes;
  final String name;
  final String type;

  _MediaFile({required this.bytes, required this.name, required this.type});
}
