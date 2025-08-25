import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/detected_ingredient.dart';
import '../services/camera_service.dart';
import '../services/image_processing_service.dart';

// Service providers
final cameraServiceProvider = Provider<CameraService>((ref) => CameraService());

final imageProcessingServiceProvider = Provider<ImageProcessingService>(
  (ref) => ImageProcessingService(),
);

// Camera state provider
final cameraProvider = StateNotifierProvider<CameraNotifier, CameraState>((ref) {
  return CameraNotifier(
    cameraService: ref.watch(cameraServiceProvider),
    imageProcessingService: ref.watch(imageProcessingServiceProvider),
  );
});

class CameraNotifier extends StateNotifier<CameraState> {
  final CameraService _cameraService;
  final ImageProcessingService _imageProcessingService;

  CameraNotifier({
    required CameraService cameraService,
    required ImageProcessingService imageProcessingService,
  }) : _cameraService = cameraService,
       _imageProcessingService = imageProcessingService,
       super(const CameraState());

  /// Initialize camera and check permissions
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Check if camera is available
      final isAvailable = await _cameraService.isCameraAvailable();
      if (!isAvailable) {
        throw Exception('Camera is not available on this device');
      }

      // Check permissions
      final hasPermission = await _cameraService.checkCameraPermission();
      
      state = state.copyWith(
        isInitialized: true,
        isLoading: false,
        hasPermission: hasPermission,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Request camera permission
  Future<bool> requestPermission() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final granted = await _cameraService.requestCameraPermission();
      
      state = state.copyWith(
        isLoading: false,
        hasPermission: granted,
        error: granted ? null : 'Camera permission denied',
      );

      return granted;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  /// Capture image from camera
  Future<XFile?> captureFromCamera() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final image = await _cameraService.captureFromCamera();
      
      if (image != null) {
        // Validate the captured image
        final validation = await _imageProcessingService.validateForAI(image);
        
        if (!validation.isValid) {
          throw Exception(validation.errors.join(', '));
        }

        state = state.copyWith(
          isLoading: false,
          capturedImagePath: image.path,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }

      return image;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Pick image from gallery
  Future<XFile?> pickFromGallery() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final image = await _cameraService.pickFromGallery();
      
      if (image != null) {
        // Validate the selected image
        final validation = await _imageProcessingService.validateForAI(image);
        
        if (!validation.isValid) {
          throw Exception(validation.errors.join(', '));
        }

        state = state.copyWith(
          isLoading: false,
          capturedImagePath: image.path,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }

      return image;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// Clear captured image
  void clearImage() {
    state = state.copyWith(capturedImagePath: null);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Reset camera state
  void reset() {
    state = const CameraState();
  }
}
