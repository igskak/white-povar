import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/config/app_config.dart';

class RecipeVideoWidget extends StatefulWidget {
  final String? videoUrl;
  final String? videoFilePath;
  final double? height;
  final BorderRadius? borderRadius;

  const RecipeVideoWidget({
    super.key,
    this.videoUrl,
    this.videoFilePath,
    this.height,
    this.borderRadius,
  });

  @override
  State<RecipeVideoWidget> createState() => _RecipeVideoWidgetState();
}

class _RecipeVideoWidgetState extends State<RecipeVideoWidget> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _hasError = false;
  String? _errorMessage;
  bool _triedDoublePrefixFallback = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _initializeVideo() {
    if (widget.videoFilePath != null && widget.videoFilePath!.isNotEmpty) {
      // Handle uploaded video files
      _initializeUploadedVideo();
    } else if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      // Handle external video URLs
      _handleExternalVideoUrl();
    }
  }

  void _initializeUploadedVideo() {
    try {
      // For uploaded videos, we need to get the public URL from Supabase storage
      final initialPath = widget.videoFilePath!;
      final videoUrl = _getSupabaseVideoUrl(initialPath);
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      _videoController!.initialize().then((_) {
        if (mounted) {
          _createChewieController();
        }
      }).catchError((error) async {
        // Fallback: historical records might be missing a duplicated 'recipe-videos/' segment
        if (!_triedDoublePrefixFallback &&
            initialPath.startsWith('recipe-videos/') &&
            !initialPath.startsWith('recipe-videos/recipe-videos/')) {
          _triedDoublePrefixFallback = true;
          final fallbackPath = 'recipe-videos/$initialPath';
          final fallbackUrl = _getSupabaseVideoUrl(fallbackPath);
          try {
            final fallbackController =
                VideoPlayerController.networkUrl(Uri.parse(fallbackUrl));
            await fallbackController.initialize();
            if (mounted) {
              _videoController?.dispose();
              _videoController = fallbackController;
              _createChewieController();
            }
            return;
          } catch (fallbackError) {
            // continue to error state below
          }
        }
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Не вдалося завантажити відео';
          });
        }
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Не вдалося підготувати відео';
      });
    }
  }

  void _createChewieController() {
    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: false,
      looping: false,
      allowFullScreen: true,
      allowMuting: true,
      showControls: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Theme.of(context).primaryColor,
        handleColor: Theme.of(context).primaryColor,
        backgroundColor: SemanticColors.dark.surfaceStrong,
        bufferedColor: SemanticColors.dark.textSecondary,
      ),
      placeholder: Container(
        color: AppColorsV2.ink.withOpacity(.12),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorBuilder: (context, errorMessage) {
        return Container(
          color: AppColorsV2.ink,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error,
                  color: SemanticColors.dark.error,
                  size: 42,
                ),
                const SizedBox(height: 8),
                Text(
                  'Не вдалося завантажити відео',
                  style: TextStyle(color: SemanticColors.dark.textPrimary),
                ),
              ],
            ),
          ),
        );
      },
    );
    setState(() {});
  }

  String _getSupabaseVideoUrl(String filePath) {
    // Use the actual Supabase URL from app configuration
    // The filePath already includes the bucket name (recipe-videos/...)
    final url = '${AppConfig.supabaseUrl}/storage/v1/object/public/$filePath';
    return url;
  }

  void _handleExternalVideoUrl() {
    final url = widget.videoUrl!;

    // Check if it's a direct video URL that can be played inline
    if (_isDirectVideoUrl(url)) {
      try {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(url));

        _videoController!.initialize().then((_) {
          if (mounted) {
            _createChewieController();
          }
        }).catchError((error) {
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = 'Не вдалося завантажити відео';
            });
          }
        });
      } catch (e) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Не вдалося завантажити відео';
        });
      }
    }
    // For platform-specific URLs (YouTube, TikTok, etc.), we'll show a thumbnail with launch button
  }

  bool _isDirectVideoUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final path = uri.path.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.avi') ||
        path.endsWith('.webm') ||
        path.endsWith('.mkv');
  }

  String _getPlatformName(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return 'YouTube';
    } else if (url.contains('tiktok.com')) {
      return 'TikTok';
    } else if (url.contains('instagram.com')) {
      return 'Instagram';
    } else if (url.contains('vimeo.com')) {
      return 'Vimeo';
    } else if (url.contains('facebook.com')) {
      return 'Facebook';
    } else if (url.contains('dailymotion.com')) {
      return 'Dailymotion';
    }
    return 'зовнішньому сервісі';
  }

  IconData _getPlatformIcon(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return Icons.play_circle_fill;
    } else if (url.contains('tiktok.com')) {
      return Icons.music_note;
    } else if (url.contains('instagram.com')) {
      return Icons.camera_alt;
    } else if (url.contains('vimeo.com')) {
      return Icons.videocam;
    } else if (url.contains('facebook.com')) {
      return Icons.facebook;
    }
    return Icons.play_arrow;
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не вдалося відкрити відео'),
            backgroundColor: AppColorsV2.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If no video content, return empty container
    if ((widget.videoUrl == null || widget.videoUrl!.isEmpty) &&
        (widget.videoFilePath == null || widget.videoFilePath!.isEmpty)) {
      return const SizedBox.shrink();
    }

    final borderRadius = widget.borderRadius ?? BorderRadius.circular(12);
    final isCompactExternalLink = widget.videoFilePath == null &&
        widget.videoUrl != null &&
        widget.videoUrl!.isNotEmpty &&
        !_isDirectVideoUrl(widget.videoUrl!);

    if (isCompactExternalLink) {
      return _buildExternalVideoLink();
    }

    final height = widget.height ?? 200.0;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: AppColorsV2.ink.withOpacity(.12),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: _buildVideoContent(),
      ),
    );
  }

  Widget _buildVideoContent() {
    // Show error state
    if (_hasError) {
      return _buildErrorWidget();
    }

    // Show Chewie video player for direct video URLs or uploaded files
    if (_chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    // Show external platform link
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      return _buildExternalVideoLink();
    }

    // Show loading while initializing
    return _buildLoadingWidget();
  }

  Widget _buildExternalVideoLink() {
    final url = widget.videoUrl!;
    final platformName = _getPlatformName(url);
    final platformIcon = _getPlatformIcon(url);

    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: AppColorsV2.accent,
        borderRadius: AppRadius.sm,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _launchUrl(url),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  platformIcon,
                  size: 20,
                  color: AppColorsV2.ink,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Дивитися в $platformName',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColorsV2.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.open_in_new_rounded,
                  size: 16,
                  color: AppColorsV2.ink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: CircularProgressIndicator(
        color: SemanticColors.dark.textPrimary,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: SemanticColors.dark.surfaceStrong,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: SemanticColors.dark.textSecondary,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Не вдалося завантажити відео',
            style: TextStyle(
              color: SemanticColors.dark.textSecondary,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
