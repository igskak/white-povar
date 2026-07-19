import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../models/detected_ingredient.dart';
import '../../providers/camera_provider.dart';
import '../../providers/photo_search_provider.dart';
import '../../services/camera_service.dart';
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
        permanentlyDenied: cameraState.permissionState ==
            CameraPermissionState.permanentlyDenied,
        onGrant: _requestPermission,
        onOpenSettings: _openSettings,
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

  Future<void> _openSettings() async {
    await openAppSettings();
    if (mounted) {
      await ref.read(cameraProvider.notifier).initialize();
    }
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
    required this.permanentlyDenied,
    required this.onGrant,
    required this.onOpenSettings,
    required this.onGallery,
  });

  final bool permanentlyDenied;
  final VoidCallback onGrant;
  final VoidCallback onOpenSettings;
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
          if (permanentlyDenied) ...[
            Text(
              'Доступ заблоковано в налаштуваннях пристрою. Увімкніть його там, щоб робити фото в застосунку.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Відкрити налаштування',
              icon: Icons.settings_outlined,
              onPressed: onOpenSettings,
              expand: true,
            ),
          ] else
            AppButton(
              label: 'Дати доступ',
              icon: Icons.photo_camera_outlined,
              onPressed: onGrant,
              expand: true,
            ),
          const SizedBox(height: 8),
          AppButton(
            label: 'Обрати з галереї',
            icon: Icons.photo_library_outlined,
            onPressed: onGallery,
            variant: AppButtonVariant.secondary,
            expand: true,
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

    final dropzone = Container(
      height: 420,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: theme.colorScheme.surface,
        border: Border.all(color: Colors.white.withOpacity(.18), width: 1.5),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo_outlined, size: 64),
          SizedBox(height: 16),
          Text('Завантажте або зробіть фото продуктів'),
          SizedBox(height: 8),
          Text('Добре освітліть кадр і не перекривайте упаковки'),
        ],
      ),
    );
    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Сканування продуктів', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text('Ми визначимо інгредієнти й підберемо рецепти з каталогу.',
            style: theme.textTheme.bodyLarge),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: kIsWeb ? 'Зробити фото в браузері' : 'Зробити фото',
          icon: Icons.camera_alt,
          onPressed: onCapture,
          expand: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: kIsWeb ? 'Завантажити фото' : 'Обрати з галереї',
          icon: Icons.photo_library_outlined,
          onPressed: onGallery,
          variant: AppButtonVariant.secondary,
          expand: true,
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => Padding(
        padding: const EdgeInsets.all(32),
        child: constraints.maxWidth >= 760
            ? Row(children: [
                Expanded(flex: 6, child: dropzone),
                const SizedBox(width: 40),
                Expanded(flex: 4, child: actions),
              ])
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 220, child: dropzone),
                  const SizedBox(height: AppSpacing.lg),
                  actions,
                ],
              ),
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
                child: AppButton(
                  label: 'Розпізнати',
                  onPressed: onAnalyze,
                  expand: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
