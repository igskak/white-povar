import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/detected_ingredient.dart';
import '../../providers/camera_provider.dart';
import '../../providers/photo_search_provider.dart';
import '../widgets/loading_overlay.dart';

class CameraCaptureePage extends ConsumerStatefulWidget {
  const CameraCaptureePage({super.key});

  @override
  ConsumerState<CameraCaptureePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends ConsumerState<CameraCaptureePage> {
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);
    final photoSearchState = ref.watch(photoSearchProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Capture Ingredients',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          _buildMainContent(cameraState),
          if (cameraState.isLoading || photoSearchState.isLoading)
            LoadingOverlay(
              message: photoSearchState.isLoading
                  ? 'Analyzing ingredients...'
                  : 'Preparing camera...',
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent(CameraState cameraState) {
    if (cameraState.error != null) {
      return _buildErrorView(cameraState.error!);
    }

    if (!cameraState.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (!cameraState.hasPermission) {
      return _buildPermissionView();
    }

    if (_capturedImage != null) {
      return _buildImagePreview();
    }

    return _buildCameraInterface();
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Camera Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(cameraProvider.notifier).clearError();
                ref.read(cameraProvider.notifier).initialize();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt,
              size: 64,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              'Camera Permission Required',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We need camera access to help you identify ingredients in your photos.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final granted =
                    await ref.read(cameraProvider.notifier).requestPermission();
                if (!granted) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Camera permission is required for this feature'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Grant Permission'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => _pickFromGallery(),
              child: const Text(
                'Choose from Gallery Instead',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraInterface() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            color: Colors.grey[900],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt,
                    size: 80,
                    color: Colors.white54,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Point camera at your ingredients',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Make sure ingredients are well-lit and clearly visible',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildCameraControls(),
      ],
    );
  }

  Widget _buildCameraControls() {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Gallery button
          IconButton(
            onPressed: _pickFromGallery,
            icon: const Icon(
              Icons.photo_library,
              color: Colors.white,
              size: 32,
            ),
          ),
          // Capture button
          GestureDetector(
            onTap: _capturePhoto,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          // Placeholder for symmetry
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: kIsWeb
                  ? Image.network(
                      _capturedImage!.path,
                      fit: BoxFit.contain,
                    )
                  : Image.file(
                      File(_capturedImage!.path),
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _capturedImage = null;
                  });
                },
                child: const Text(
                  'Retake',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              ElevatedButton(
                onPressed: _analyzeImage,
                child: const Text('Analyze Ingredients'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _capturePhoto() async {
    final image = await ref.read(cameraProvider.notifier).captureFromCamera();
    if (image != null) {
      setState(() {
        _capturedImage = image;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    final image = await ref.read(cameraProvider.notifier).pickFromGallery();
    if (image != null) {
      setState(() {
        _capturedImage = image;
      });
    }
  }

  Future<void> _analyzeImage() async {
    if (_capturedImage == null) return;

    await ref.read(photoSearchProvider.notifier).analyzeImage(
          image: _capturedImage!,
        );

    final photoSearchState = ref.read(photoSearchProvider);
    if (photoSearchState.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(photoSearchState.error!)),
        );
      }
    } else {
      // Navigate to ingredient review page
      if (mounted) {
        context.push('/camera/review', extra: _capturedImage);
      }
    }
  }
}
