import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/widgets/state_views.dart';
import '../../models/detected_ingredient.dart';
import '../../providers/camera_provider.dart';
import '../../providers/photo_search_provider.dart';
import '../widgets/camera_flow_scaffold.dart';

class CameraCapturePage extends ConsumerStatefulWidget {
  const CameraCapturePage({super.key});

  @override
  ConsumerState<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends ConsumerState<CameraCapturePage> {
  XFile? _capturedImage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cameraProvider.notifier).initialize();
      ref.read(photoSearchProvider.notifier).clearResults();
      ref.read(ingredientEditProvider.notifier).clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = ref.watch(cameraProvider);
    final photoSearchState = ref.watch(photoSearchProvider);

    return CameraFlowScaffold(
      title: 'Сканування продуктів',
      step: CameraFlowStep.capture,
      child: _buildContent(cameraState, photoSearchState),
    );
  }

  Widget _buildContent(CameraState cameraState, PhotoSearchState searchState) {
    if (searchState.error != null) {
      return CameraFlowStatusView.error(
        title: 'Не вдалося розпізнати фото',
        subtitle: searchState.error,
        onRetry: _analyzeImage,
      );
    }

    if (cameraState.error != null) {
      return CameraFlowStatusView.error(
        title: 'Камера недоступна',
        subtitle: cameraState.error,
        onRetry: () {
          ref.read(cameraProvider.notifier).clearError();
          ref.read(cameraProvider.notifier).initialize();
        },
      );
    }

    if (cameraState.isLoading || searchState.isLoading) {
      return CameraFlowStatusView.loading(
        title: searchState.isLoading ? 'Аналізуємо фото' : 'Готуємо камеру',
        subtitle: searchState.isLoading
            ? 'Шукаємо продукти та інгредієнти.'
            : 'Перевіряємо доступ до камери.',
      );
    }

    if (!cameraState.hasPermission) {
      return _PermissionView(
        onGrant: _requestPermission,
        onGallery: _pickFromGallery,
      );
    }

    if (_capturedImage != null) {
      return _CapturedPreview(
        image: _capturedImage!,
        onRetake: () => setState(() => _capturedImage = null),
        onAnalyze: _analyzeImage,
      );
    }

    return _CameraActionView(
      onCapture: _capturePhoto,
      onGallery: _pickFromGallery,
    );
  }

  Future<void> _requestPermission() async {
    ref.read(photoSearchProvider.notifier).clearError();
    await ref.read(cameraProvider.notifier).requestPermission();
  }

  Future<void> _capturePhoto() async {
    ref.read(photoSearchProvider.notifier).clearError();
    final image = await ref.read(cameraProvider.notifier).captureFromCamera();
    if (image != null && mounted) {
      setState(() {
        _capturedImage = image;
      });
    }
  }

  Future<void> _pickFromGallery() async {
    ref.read(photoSearchProvider.notifier).clearError();
    final image = await ref.read(cameraProvider.notifier).pickFromGallery();
    if (image != null && mounted) {
      setState(() {
        _capturedImage = image;
      });
    }
  }

  Future<void> _analyzeImage() async {
    final capturedImage = _capturedImage;
    if (capturedImage == null) {
      return;
    }

    ref.read(photoSearchProvider.notifier).clearError();
    await ref.read(photoSearchProvider.notifier).analyzeImage(
          image: capturedImage,
        );

    if (!mounted) {
      return;
    }

    final photoSearchState = ref.read(photoSearchProvider);
    if (photoSearchState.error != null) {
      return;
    }

    context.push('/camera/review', extra: capturedImage);
  }
}

class _PermissionView extends StatelessWidget {
  const _PermissionView({
    required this.onGrant,
    required this.onGallery,
  });

  final VoidCallback onGrant;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const StateView.empty(
            title: 'Потрібен доступ до камери',
            subtitle:
                'Дайте доступ до камери або оберіть готове фото з галереї.',
            icon: Icons.photo_camera_outlined,
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Дати доступ до камери',
            button: true,
            child: ElevatedButton(
              onPressed: onGrant,
              child: const Text('Дати доступ'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Обрати з галереї'),
          ),
        ],
      ),
    );
  }
}

class _CameraActionView extends StatelessWidget {
  const _CameraActionView({
    required this.onCapture,
    required this.onGallery,
  });

  final VoidCallback onCapture;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: theme.colorScheme.surface,
              border: Border.all(color: Colors.white.withOpacity(.10)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 56),
                SizedBox(height: 12),
                Text('Наведіть камеру на продукти'),
                SizedBox(height: 6),
                Text('Добре освітліть кадр і не перекривайте упаковки'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            label: 'Зробити фото продуктів',
            button: true,
            child: ElevatedButton.icon(
              onPressed: onCapture,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Зробити фото'),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Обрати з галереї'),
          ),
        ],
      ),
    );
  }
}

class _CapturedPreview extends StatelessWidget {
  const _CapturedPreview({
    required this.image,
    required this.onRetake,
    required this.onAnalyze,
  });

  final XFile image;
  final VoidCallback onRetake;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: kIsWeb
                  ? Image.network(image.path, fit: BoxFit.cover)
                  : Image.file(File(image.path), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onRetake,
                  child: const Text('Перезняти'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Semantics(
                  label: 'Розпізнати продукти на фото',
                  button: true,
                  child: ElevatedButton(
                    onPressed: onAnalyze,
                    child: const Text('Розпізнати'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
