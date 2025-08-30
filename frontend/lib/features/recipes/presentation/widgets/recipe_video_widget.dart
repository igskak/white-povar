import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

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
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _controller?.dispose();
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
      final videoUrl = _getSupabaseVideoUrl(widget.videoFilePath!);
      _controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));

      _controller!.initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
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
        _errorMessage = 'Error initializing video: $e';
      });
    }
  }

  String _getSupabaseVideoUrl(String filePath) {
    // This should match your Supabase storage configuration
    // You might want to get this from your app configuration
    const supabaseUrl =
        'https://your-project.supabase.co'; // TODO: Replace with actual URL
    return '$supabaseUrl/storage/v1/object/public/recipe-videos/$filePath';
  }

  void _handleExternalVideoUrl() {
    final url = widget.videoUrl!;

    // Check if it's a direct video URL that can be played inline
    if (_isDirectVideoUrl(url)) {
      try {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));

        _controller!.initialize().then((_) {
          if (mounted) {
            setState(() {
              _isInitialized = true;
            });
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

    // Show video player for direct video URLs or uploaded files
    if (_controller != null) {
      if (_isInitialized) {
        return _buildVideoPlayer();
      } else {
        return _buildLoadingWidget();
      }
    }

    // Show external platform link
    if (widget.videoUrl != null && widget.videoUrl!.isNotEmpty) {
      return _buildExternalVideoLink();
    }

    return _buildErrorWidget();
  }

  Widget _buildVideoPlayer() {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
        ),
        _buildVideoControls(),
      ],
    );
  }

  Widget _buildVideoControls() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(0.3),
          ],
        ),
      ),
      child: Center(
        child: IconButton(
          onPressed: () {
            setState(() {
              if (_controller!.value.isPlaying) {
                _controller!.pause();
              } else {
                _controller!.play();
              }
            });
          },
          icon: Icon(
            _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildExternalVideoLink() {
    final url = widget.videoUrl!;
    final platformName = _getPlatformName(url);
    final platformIcon = _getPlatformIcon(url);

    return InkWell(
      onTap: () => _launchUrl(url),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withOpacity(0.8),
              Colors.purple.withOpacity(0.8),
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              platformIcon,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              'Watch on $platformName',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to open',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: CircularProgressIndicator(
        color: Colors.white,
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Failed to load video',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
