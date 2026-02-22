import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
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
            _errorMessage = 'Failed to load video: $error';
          });
        }
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Error initializing video: $e';
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
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey[300]!,
      ),
      placeholder: Container(
        color: Colors.black12,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorBuilder: (context, errorMessage) {
        return Container(
          color: Colors.black,
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 42,
                ),
                SizedBox(height: 8),
                Text(
                  'Error loading video',
                  style: TextStyle(color: Colors.white),
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
              _errorMessage = 'Failed to load video: $error';
            });
          }
        });
      } catch (e) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error loading video: $e';
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
    return 'External Video';
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
          SnackBar(
            content: Text('Failed to open video: $e'),
            backgroundColor: Colors.red,
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

    final height = widget.height ?? 200.0;
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(12);

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: Colors.black12,
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
