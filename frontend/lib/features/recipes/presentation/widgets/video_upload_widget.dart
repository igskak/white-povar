import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class VideoUploadWidget extends StatefulWidget {
  final String? initialVideoUrl;
  final String? initialVideoFilePath;
  final Function(String?)? onVideoUrlChanged;
  final Function(File?)? onVideoFileChanged;
  final bool enabled;

  const VideoUploadWidget({
    super.key,
    this.initialVideoUrl,
    this.initialVideoFilePath,
    this.onVideoUrlChanged,
    this.onVideoFileChanged,
    this.enabled = true,
  });

  @override
  State<VideoUploadWidget> createState() => _VideoUploadWidgetState();
}

class _VideoUploadWidgetState extends State<VideoUploadWidget> {
  final TextEditingController _urlController = TextEditingController();
  File? _selectedVideoFile;
  String _selectedOption = 'none'; // 'none', 'url', 'file'
  bool _isValidUrl = true;
  String? _urlError;

  @override
  void initState() {
    super.initState();
    _initializeValues();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _initializeValues() {
    if (widget.initialVideoUrl != null && widget.initialVideoUrl!.isNotEmpty) {
      _urlController.text = widget.initialVideoUrl!;
      _selectedOption = 'url';
      _validateUrl(widget.initialVideoUrl!);
    } else if (widget.initialVideoFilePath != null && widget.initialVideoFilePath!.isNotEmpty) {
      _selectedOption = 'file';
      // Note: We can't recreate the File object from just the path
      // In a real app, you might want to show the filename or a preview
    }
  }

  void _validateUrl(String url) {
    if (url.isEmpty) {
      setState(() {
        _isValidUrl = true;
        _urlError = null;
      });
      return;
    }

    // Basic URL validation
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      setState(() {
        _isValidUrl = false;
        _urlError = 'Please enter a valid URL';
      });
      return;
    }

    // Check for supported platforms
    final supportedPlatforms = [
      'youtube.com',
      'youtu.be',
      'tiktok.com',
      'instagram.com',
      'vimeo.com',
      'facebook.com',
      'dailymotion.com',
    ];

    final host = uri.host.toLowerCase();
    final isSupported = supportedPlatforms.any((platform) => 
        host.contains(platform) || host.endsWith(platform));

    if (!isSupported) {
      setState(() {
        _isValidUrl = false;
        _urlError = 'URL must be from a supported platform (YouTube, TikTok, Instagram, Vimeo, Facebook, Dailymotion)';
      });
      return;
    }

    setState(() {
      _isValidUrl = true;
      _urlError = null;
    });
  }

  Future<void> _pickVideoFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        
        // Check file size (max 100MB)
        final fileSizeInBytes = await file.length();
        final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
        
        if (fileSizeInMB > 100) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video file is too large. Maximum size is 100MB.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        setState(() {
          _selectedVideoFile = file;
        });

        widget.onVideoFileChanged?.call(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick video file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onOptionChanged(String? value) {
    if (value == null || !widget.enabled) return;

    setState(() {
      _selectedOption = value;
    });

    switch (value) {
      case 'none':
        _urlController.clear();
        _selectedVideoFile = null;
        widget.onVideoUrlChanged?.call(null);
        widget.onVideoFileChanged?.call(null);
        break;
      case 'url':
        _selectedVideoFile = null;
        widget.onVideoFileChanged?.call(null);
        if (_urlController.text.isNotEmpty && _isValidUrl) {
          widget.onVideoUrlChanged?.call(_urlController.text);
        }
        break;
      case 'file':
        _urlController.clear();
        widget.onVideoUrlChanged?.call(null);
        if (_selectedVideoFile != null) {
          widget.onVideoFileChanged?.call(_selectedVideoFile);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recipe Video (Optional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a video to help users follow your recipe',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Video option selection
            Column(
              children: [
                RadioListTile<String>(
                  title: const Text('No video'),
                  value: 'none',
                  groupValue: _selectedOption,
                  onChanged: widget.enabled ? _onOptionChanged : null,
                  dense: true,
                ),
                RadioListTile<String>(
                  title: const Text('Video URL (YouTube, TikTok, etc.)'),
                  value: 'url',
                  groupValue: _selectedOption,
                  onChanged: widget.enabled ? _onOptionChanged : null,
                  dense: true,
                ),
                RadioListTile<String>(
                  title: const Text('Upload video file'),
                  value: 'file',
                  groupValue: _selectedOption,
                  onChanged: widget.enabled ? _onOptionChanged : null,
                  dense: true,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // URL input field
            if (_selectedOption == 'url') ...[
              TextField(
                controller: _urlController,
                enabled: widget.enabled,
                decoration: InputDecoration(
                  labelText: 'Video URL',
                  hintText: 'https://youtube.com/watch?v=...',
                  border: const OutlineInputBorder(),
                  errorText: _urlError,
                  prefixIcon: const Icon(Icons.link),
                ),
                onChanged: (value) {
                  _validateUrl(value);
                  if (_isValidUrl && value.isNotEmpty) {
                    widget.onVideoUrlChanged?.call(value);
                  } else {
                    widget.onVideoUrlChanged?.call(null);
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Supported platforms: YouTube, TikTok, Instagram, Vimeo, Facebook, Dailymotion',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],

            // File upload section
            if (_selectedOption == 'file') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (_selectedVideoFile == null) ...[
                      Icon(
                        Icons.video_file,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No video selected',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: widget.enabled ? _pickVideoFile : null,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Choose Video File'),
                      ),
                    ] else ...[
                      Icon(
                        Icons.video_file,
                        size: 48,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedVideoFile!.path.split('/').last,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      FutureBuilder<int>(
                        future: _selectedVideoFile!.length(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            final sizeInMB = snapshot.data! / (1024 * 1024);
                            return Text(
                              '${sizeInMB.toStringAsFixed(1)} MB',
                              style: TextStyle(color: Colors.grey[600]),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: widget.enabled ? _pickVideoFile : null,
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Change'),
                          ),
                          TextButton.icon(
                            onPressed: widget.enabled ? () {
                              setState(() {
                                _selectedVideoFile = null;
                              });
                              widget.onVideoFileChanged?.call(null);
                            } : null,
                            icon: const Icon(Icons.delete),
                            label: const Text('Remove'),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Supported formats: MP4, MOV, AVI, WebM, MKV (Max 100MB)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
