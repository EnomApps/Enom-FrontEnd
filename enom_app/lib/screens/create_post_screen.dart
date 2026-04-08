import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import '../services/upload_manager.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _HashtagTextEditingController _contentController = _HashtagTextEditingController();
  final List<_MediaFile> _mediaFiles = [];
  String _visibility = 'public';

  static const int _maxMedia = 10;
  static const int _maxHashtags = 5;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  bool get _canPost =>
      _contentController.text.trim().isNotEmpty || _mediaFiles.isNotEmpty;

  /// Extract hashtags from content text (max 5).
  List<String> _extractHashtags() {
    final regex = RegExp(r'#(\w+)');
    final matches = regex.allMatches(_contentController.text);
    return matches.map((m) => m.group(1)!).toSet().take(_maxHashtags).toList();
  }

  /// Count hashtags currently in text.
  int get _hashtagCount {
    final regex = RegExp(r'#\w+');
    return regex.allMatches(_contentController.text).map((m) => m.group(0)).toSet().length;
  }

  Future<bool> _requestMediaPermission({bool isVideo = false}) async {
    PermissionStatus status;
    if (Platform.isAndroid) {
      if (isVideo) {
        status = await Permission.videos.request();
      } else {
        status = await Permission.photos.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied && mounted) {
      final l10n = AppLocalizations.of(context)!;
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
      final l10n = AppLocalizations.of(context)!;
      AppTheme.showSnackBar(context, l10n.translate('permission_denied'), isError: true);
    }
    return false;
  }

  Future<void> _pickImages() async {
    if (_mediaFiles.length >= _maxMedia) {
      final l10n = AppLocalizations.of(context)!;
      AppTheme.showSnackBar(context, l10n.translate('max_media_allowed').replaceAll('{count}', '$_maxMedia'), isError: true);
      return;
    }

    if (!await _requestMediaPermission()) return;

    final picker = ImagePicker();
    // WhatsApp-style: cap at 1600px and 85% quality
    final images = await picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

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
            filePath: img.path,
          ));
        });
      }
    }
  }

  Future<void> _pickVideo() async {
    if (_mediaFiles.length >= _maxMedia) {
      final l10n = AppLocalizations.of(context)!;
      AppTheme.showSnackBar(context, l10n.translate('max_media_allowed').replaceAll('{count}', '$_maxMedia'), isError: true);
      return;
    }

    if (!await _requestMediaPermission(isVideo: true)) {
      return;
    }

    final picker = ImagePicker();
    // Pick multiple videos one at a time until user cancels or limit reached
    while (_mediaFiles.length < _maxMedia) {
      final video = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video == null) break;

      final videoBytes = await video.readAsBytes();

      if (mounted) {
        setState(() {
          _mediaFiles.add(_MediaFile(
            bytes: videoBytes,
            name: video.name,
            type: 'video',
            filePath: video.path,
          ));
        });
      }

      if (!mounted) break;

      // Ask if user wants to add more videos
      if (_mediaFiles.length < _maxMedia) {
        final l10n = AppLocalizations.of(context)!;
        final addMore = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.moodCardBg(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(l10n.translate('add_another_video'),
                style: GoogleFonts.jost(color: AppTheme.text1(context), fontWeight: FontWeight.w600)),
            content: Text(
                '${_mediaFiles.length} of $_maxMedia media added.',
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

  void _removeMedia(int index) {
    setState(() => _mediaFiles.removeAt(index));
  }

  void _createPost() {
    if (!_canPost) return;

    if (_hashtagCount > _maxHashtags) {
      final l10n = AppLocalizations.of(context)!;
      AppTheme.showSnackBar(context, l10n.translate('max_hashtags_allowed').replaceAll('{count}', '$_maxHashtags'), isError: true);
      return;
    }

    final hashtags = _extractHashtags();

    // Start background compress + upload via UploadManager
    UploadManager.instance.startUpload(
      content: _contentController.text.trim(),
      visibility: _visibility,
      hashtags: hashtags,
      mediaBytes: _mediaFiles.isNotEmpty ? _mediaFiles.map((f) => f.bytes).toList() : null,
      mediaNames: _mediaFiles.isNotEmpty ? _mediaFiles.map((f) => f.name).toList() : null,
      mediaTypes: _mediaFiles.isNotEmpty ? _mediaFiles.map((f) => f.type).toList() : null,
      mediaFilePaths: _mediaFiles.isNotEmpty ? _mediaFiles.map((f) => f.filePath).toList() : null,
    );

    // Navigate back to feed immediately (Instagram-style)
    Navigator.of(context).pop(true);
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
        title: Text(
          l10n.translate('create_post').toUpperCase(),
          style: AppTheme.label(context, size: 12),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _canPost ? _createPost : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  gradient: _canPost ? AppTheme.goldGradient2 : null,
                  color: !_canPost ? AppTheme.glassBg(context) : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.translate('post'),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
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
                        if (_hashtagCount > 0)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: Text(
                              '$_hashtagCount / $_maxHashtags hashtags',
                              style: GoogleFonts.jost(
                                fontSize: 12,
                                color: _hashtagCount > _maxHashtags
                                    ? Colors.redAccent
                                    : AppTheme.textMuted(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Media preview
                  if (_mediaFiles.isNotEmpty) ...[
                    Text(l10n.translate('media').toUpperCase(), style: AppTheme.label(context, size: 10)),
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
                        _buildVisibilityOption('public', Icons.public, l10n.translate('public')),
                        _buildVisibilityOption('followers', Icons.people_outline, l10n.translate('followers')),
                        _buildVisibilityOption('private', Icons.lock_outline, l10n.translate('private')),
                      ],
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

  void _showMediaPreview(int index) {
    final file = _mediaFiles[index];
    if (file.type == 'video' && file.filePath != null) {
      _showVideoPreview(file);
    } else if (file.type == 'image') {
      _showImagePreview(file);
    }
  }

  void _showImagePreview(_MediaFile file) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.memory(
                file.bytes,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoPreview(_MediaFile file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _VideoPreviewScreen(filePath: file.filePath!),
      ),
    );
  }

  Widget _buildMediaPreview(int index) {
    final l10n = AppLocalizations.of(context)!;
    final file = _mediaFiles[index];
    return GestureDetector(
      onTap: () => _showMediaPreview(index),
      child: Container(
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
            // Image/Video thumbnail
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
            // Remove button
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
        ),
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

// Video thumbnail widget - shows first frame of video
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

// Full-screen video preview
class _VideoPreviewScreen extends StatefulWidget {
  final String filePath;

  const _VideoPreviewScreen({required this.filePath});

  @override
  State<_VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<_VideoPreviewScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(l10n.translate('preview'), style: GoogleFonts.jost(color: Colors.white, fontSize: 16)),
        centerTitle: true,
      ),
      body: Center(
        child: _initialized
            ? GestureDetector(
                onTap: () {
                  setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  });
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                    if (!_controller.value.isPlaying)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                      ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
      bottomNavigationBar: _initialized
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: AppTheme.goldColor(context),
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _MediaFile {
  final Uint8List bytes;
  final String name;
  final String type;
  final String? filePath;

  _MediaFile({required this.bytes, required this.name, required this.type, this.filePath});
}

/// Custom TextEditingController that highlights #hashtags in blue.
class _HashtagTextEditingController extends TextEditingController {
  static final _hashtagRegex = RegExp(r'#\w+');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = this.text;
    final children = <TextSpan>[];
    int lastEnd = 0;

    for (final match in _hashtagRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        children.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: style,
        ));
      }
      children.add(TextSpan(
        text: match.group(0),
        style: style?.copyWith(
          color: const Color(0xFF3897F0),
          fontWeight: FontWeight.w600,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      children.add(TextSpan(
        text: text.substring(lastEnd),
        style: style,
      ));
    }

    return TextSpan(children: children, style: style);
  }
}
