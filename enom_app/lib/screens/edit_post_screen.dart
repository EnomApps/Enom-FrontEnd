import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../services/post_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class EditPostScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _contentController;
  final List<_ExistingMedia> _existingMedia = [];
  final List<_NewMediaFile> _newMedia = [];
  String _visibility = 'public';
  bool _isSaving = false;
  bool _isCompressing = false;
  double _compressionProgress = 0.0;

  static const int _maxMedia = 10;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.post['content'] as String? ?? '',
    );
    _visibility = widget.post['visibility'] as String? ?? 'public';

    // Load existing media
    final media = widget.post['media'] as List<dynamic>? ?? [];
    for (final item in media) {
      if (item is Map<String, dynamic>) {
        final id = item['id'] as int?;
        final url = _getMediaUrl(item);
        final type = _getMediaType(item);
        if (id != null) {
          _existingMedia.add(_ExistingMedia(id: id, url: url, type: type));
        }
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  String _getMediaUrl(Map<String, dynamic> item) {
    final url = (item['url'] ?? item['file_url'] ?? item['path'] ?? item['file_path'] ?? item['media_url'] ?? '').toString();
    return url.startsWith('http') ? url : '${ApiService.baseUrl}/${url.replaceAll(RegExp(r'^/'), '')}';
  }

  String _getMediaType(Map<String, dynamic> item) {
    return (item['type'] ?? item['mime_type'] ?? item['file_type'] ?? 'image').toString();
  }

  int get _totalMedia => _existingMedia.length + _newMedia.length;

  bool get _canSave =>
      _contentController.text.trim().isNotEmpty || _existingMedia.isNotEmpty || _newMedia.isNotEmpty;

  Future<bool> _requestMediaPermission({bool isVideo = false}) async {
    final l10n = AppLocalizations.of(context)!;
    PermissionStatus status;
    if (Platform.isAndroid) {
      status = isVideo ? await Permission.videos.request() : await Permission.photos.request();
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied && mounted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.bg2(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(l10n.translate('permission_required'),
              style: GoogleFonts.jost(color: AppTheme.text1(context), fontWeight: FontWeight.w600)),
          content: Text(
              l10n.translate(isVideo ? 'permission_media_videos' : 'permission_media_photos'),
              style: GoogleFonts.jost(color: AppTheme.textMuted(context))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.translate('cancel'), style: GoogleFonts.jost(color: AppTheme.textMuted(context))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.translate('open_settings'), style: GoogleFonts.jost(color: AppTheme.goldColor(context))),
            ),
          ],
        ),
      );
      if (open == true) await openAppSettings();
    } else if (mounted) {
      AppTheme.showSnackBar(context, l10n.translate('permission_denied'), isError: true);
    }
    return false;
  }

  Future<void> _pickImages() async {
    if (_totalMedia >= _maxMedia) {
      final l10n = AppLocalizations.of(context)!;
      AppTheme.showSnackBar(context, l10n.translate('max_media_allowed').replaceAll('{count}', '$_maxMedia'), isError: true);
      return;
    }

    if (!await _requestMediaPermission()) return;

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (images.isEmpty) return;

    final remaining = _maxMedia - _totalMedia;
    final toAdd = images.take(remaining);

    for (final img in toAdd) {
      final bytes = await img.readAsBytes();
      if (mounted) {
        setState(() {
          _newMedia.add(_NewMediaFile(
            bytes: bytes,
            name: img.name,
            type: 'image',
            filePath: img.path,
          ));
        });
      }
    }
  }

  Future<({String path, Uint8List bytes})?> _compressVideo(String filePath) async {
    final subscription = VideoCompress.compressProgress$.subscribe((progress) {
      if (mounted) {
        setState(() => _compressionProgress = progress / 100.0);
      }
    });

    setState(() {
      _isCompressing = true;
      _compressionProgress = 0.0;
    });

    try {
      final info = await VideoCompress.compressVideo(
        filePath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (info == null || info.file == null) return null;

      final compressedBytes = await info.file!.readAsBytes();
      return (path: info.file!.path, bytes: compressedBytes);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        AppTheme.showSnackBar(context, l10n.translate('video_compression_failed'), isError: true);
      }
      return null;
    } finally {
      subscription.unsubscribe();
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _compressionProgress = 0.0;
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickVideo() async {
    if (_totalMedia >= _maxMedia) {
      final l10n = AppLocalizations.of(context)!;
      AppTheme.showSnackBar(context, l10n.translate('max_media_allowed').replaceAll('{count}', '$_maxMedia'), isError: true);
      return;
    }

    if (!await _requestMediaPermission(isVideo: true)) return;

    final picker = ImagePicker();

    while (_totalMedia < _maxMedia) {
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video == null) break;

      final originalBytes = await video.readAsBytes();
      final originalSize = originalBytes.length;

      final compressed = await _compressVideo(video.path);

      if (compressed == null) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          AppTheme.showSnackBar(context, l10n.translate('video_skipped'), isError: true);
        }
        break;
      }

      final compressedSize = compressed.bytes.length;

      if (mounted) {
        final saved = originalSize - compressedSize;
        if (saved > 0) {
          AppTheme.showSnackBar(
            context,
            'Compressed: ${_formatFileSize(originalSize)} → ${_formatFileSize(compressedSize)} (saved ${_formatFileSize(saved)})',
          );
        }
        setState(() {
          _newMedia.add(_NewMediaFile(
            bytes: compressed.bytes,
            name: video.name,
            type: 'video',
            filePath: compressed.path,
          ));
        });
      }

      if (!mounted) break;

      if (_totalMedia < _maxMedia) {
        final l10n = AppLocalizations.of(context)!;
        final addMore = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.moodCardBg(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(l10n.translate('add_another_video'),
                style: GoogleFonts.jost(color: AppTheme.text1(context), fontWeight: FontWeight.w600)),
            content: Text(
                '$_totalMedia of $_maxMedia media added.',
                style: GoogleFonts.jost(color: AppTheme.textMuted(context))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(l10n.translate('done'), style: GoogleFonts.jost(color: AppTheme.textMuted(context))),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(l10n.translate('add_more'), style: GoogleFonts.jost(color: AppTheme.goldColor(context))),
              ),
            ],
          ),
        );
        if (addMore != true) break;
      }
    }
  }

  void _removeExistingMedia(int index) {
    setState(() => _existingMedia.removeAt(index));
  }

  void _removeNewMedia(int index) {
    setState(() => _newMedia.removeAt(index));
  }

  Future<void> _savePost() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    final keepIds = _existingMedia.map((m) => m.id).toList();

    final result = await PostService.updatePostWithMedia(
      widget.post['id'] as int,
      content: _contentController.text.trim(),
      visibility: _visibility,
      keepMediaIds: keepIds,
      newMediaBytes: _newMedia.isNotEmpty ? _newMedia.map((f) => f.bytes).toList() : null,
      newMediaNames: _newMedia.isNotEmpty ? _newMedia.map((f) => f.name).toList() : null,
    );

    if (!mounted) return;

    setState(() => _isSaving = false);

    if (result.success) {
      final l10n = AppLocalizations.of(context)!;
      AppTheme.showSnackBar(context, l10n.translate('post_updated'));
      Navigator.of(context).pop(true);
    } else {
      AppTheme.showSnackBar(context, result.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
        title: Text(l10n.translate('edit_post').toUpperCase(), style: AppTheme.label(context, size: 12)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: (_canSave && !_isSaving) ? _savePost : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: (_canSave && !_isSaving) ? AppTheme.goldGradient2 : null,
                  color: (!_canSave || _isSaving) ? AppTheme.glassBg(context) : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Color(0xFF1A1612),
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        l10n.translate('save'),
                        style: GoogleFonts.jost(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _canSave
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
          const EnomScreenBackground(gradientVariant: 2, particleCount: 35),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content input
                  Container(
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
                        hintText: l10n.translate('whats_on_your_mind'),
                        hintStyle: GoogleFonts.jost(
                          color: AppTheme.textMuted(context),
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Existing media
                  if (_existingMedia.isNotEmpty || _newMedia.isNotEmpty) ...[
                    Text(l10n.translate('media').toUpperCase(), style: AppTheme.label(context, size: 10)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _existingMedia.length + _newMedia.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          if (i < _existingMedia.length) {
                            return _buildExistingMediaPreview(i);
                          }
                          return _buildNewMediaPreview(i - _existingMedia.length);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action buttons
                  Text(l10n.translate('add_to_post').toUpperCase(), style: AppTheme.label(context, size: 10)),
                  const SizedBox(height: 12),
                  Container(
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
                          label: l10n.translate('photo'),
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
                          label: l10n.translate('video'),
                          color: Colors.blueAccent,
                          onTap: _pickVideo,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Visibility picker
                  Text(l10n.translate('visibility').toUpperCase(), style: AppTheme.label(context, size: 10)),
                  const SizedBox(height: 12),
                  Container(
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
                ],
              ),
            ),
          ),
          // Compression overlay
          if (_isCompressing)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppTheme.bg2(context),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.goldColor(context).withValues(alpha: 0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 56,
                        height: 56,
                        child: CircularProgressIndicator(
                          value: _compressionProgress > 0 ? _compressionProgress : null,
                          strokeWidth: 4,
                          color: AppTheme.goldColor(context),
                          backgroundColor: AppTheme.glassBorder(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Compressing Video...',
                        style: GoogleFonts.jost(
                          color: AppTheme.text1(context),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_compressionProgress * 100).toInt()}%',
                        style: GoogleFonts.jost(
                          color: AppTheme.goldColor(context),
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Optimizing for faster upload',
                        style: GoogleFonts.jost(
                          color: AppTheme.textMuted(context),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExistingMediaPreview(int index) {
    final l10n = AppLocalizations.of(context)!;
    final media = _existingMedia[index];
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (media.type.contains('video'))
            Container(
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.videocam, color: AppTheme.goldColor(context), size: 32),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                  ),
                ],
              ),
            )
          else
            Image.network(
              media.url,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.goldColor(context),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.glassBg(context),
                child: Icon(Icons.broken_image_outlined, color: AppTheme.textMuted(context)),
              ),
            ),
          // Type badge
          if (media.type.contains('video'))
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(l10n.translate('video').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeExistingMedia(index),
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
      ),
    );
  }

  Widget _buildNewMediaPreview(int index) {
    final l10n = AppLocalizations.of(context)!;
    final file = _newMedia[index];
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (file.type == 'video')
            _VideoThumbnail(filePath: file.filePath, name: file.name)
          else if (file.filePath != null)
            Image.file(
              File(file.filePath!),
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, __, ___) => Image.memory(
                file.bytes,
                width: 120,
                height: 120,
                fit: BoxFit.cover,
              ),
            )
          else
            Image.memory(
              file.bytes,
              width: 120,
              height: 120,
              fit: BoxFit.cover,
            ),
          // Type badge
          if (file.type == 'video')
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                    const SizedBox(width: 2),
                    Text(l10n.translate('video').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          // "NEW" badge
          Positioned(
            bottom: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.goldColor(context),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(l10n.translate('new_badge').toUpperCase(), style: const TextStyle(color: Color(0xFF1A1612), fontSize: 8, fontWeight: FontWeight.w700)),
            ),
          ),
          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeNewMedia(index),
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
      ),
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
            border: isSelected ? Border.all(color: goldC.withValues(alpha: 0.3)) : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: isSelected ? goldC : AppTheme.textMuted(context)),
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

class _ExistingMedia {
  final int id;
  final String url;
  final String type;

  _ExistingMedia({required this.id, required this.url, required this.type});
}

class _NewMediaFile {
  final Uint8List bytes;
  final String name;
  final String type;
  final String? filePath;

  _NewMediaFile({required this.bytes, required this.name, required this.type, this.filePath});
}

// Video thumbnail widget
class _VideoThumbnail extends StatefulWidget {
  final String? filePath;
  final String name;

  const _VideoThumbnail({required this.filePath, required this.name});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initThumbnail();
  }

  Future<void> _initThumbnail() async {
    if (widget.filePath == null) return;
    final controller = VideoPlayerController.file(File(widget.filePath!));
    try {
      await controller.initialize();
      if (mounted) {
        setState(() {
          _controller = controller;
          _initialized = true;
        });
      } else {
        controller.dispose();
      }
    } catch (_) {
      controller.dispose();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized && _controller != null) {
      return SizedBox(
        width: 120,
        height: 120,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      );
    }
    return Container(
      width: 120,
      height: 120,
      color: AppTheme.glassBg(context),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam, color: AppTheme.goldColor(context), size: 32),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              widget.name,
              style: GoogleFonts.jost(color: AppTheme.textMuted(context), fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
