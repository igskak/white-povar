import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  final ImagePicker _picker = ImagePicker();

  /// Check if camera permission is granted
  Future<bool> checkCameraPermission() async {
    if (kIsWeb) {
      // Web doesn't need explicit permission check
      return true;
    }

    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Request camera permission
  Future<bool> requestCameraPermission() async {
    if (kIsWeb) {
      return true;
    }

    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Check if storage permission is granted (Android only)
  Future<bool> checkStoragePermission() async {
    if (kIsWeb || Platform.isIOS) {
      return true;
    }

    final status = await Permission.storage.status;
    return status.isGranted;
  }

  /// Request storage permission (Android only)
  Future<bool> requestStoragePermission() async {
    if (kIsWeb || Platform.isIOS) {
      return true;
    }

    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Capture image from camera
  Future<XFile?> captureFromCamera() async {
    try {
      final hasPermission = await checkCameraPermission();
      if (!hasPermission) {
        final granted = await requestCameraPermission();
        if (!granted) {
          throw Exception('Camera permission denied');
        }
      }

      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 2048, // Increased for better quality
        maxHeight: 2048, // Increased for better quality
        preferredCameraDevice:
            CameraDevice.rear, // Use rear camera for better quality
      );

      return image;
    } catch (e) {
      throw Exception('Failed to capture image: $e');
    }
  }

  /// Pick image from gallery
  Future<XFile?> pickFromGallery() async {
    try {
      final hasPermission = await checkStoragePermission();
      if (!hasPermission) {
        final granted = await requestStoragePermission();
        if (!granted) {
          throw Exception('Storage permission denied');
        }
      }

      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 2048, // Increased for better quality
        maxHeight: 2048, // Increased for better quality
      );

      return image;
    } catch (e) {
      throw Exception('Failed to pick image: $e');
    }
  }

  /// Get image as bytes for processing
  Future<Uint8List> getImageBytes(XFile image) async {
    try {
      return await image.readAsBytes();
    } catch (e) {
      throw Exception('Failed to read image bytes: $e');
    }
  }

  /// Check if camera is available on device
  Future<bool> isCameraAvailable() async {
    try {
      if (kIsWeb) {
        // For web, we'll assume camera is available
        // The browser will handle the actual availability
        return true;
      }

      // For mobile platforms, we can check if camera permission can be requested
      final status = await Permission.camera.status;
      return !status.isPermanentlyDenied;
    } catch (e) {
      return false;
    }
  }

  /// Validate image file
  bool isValidImage(XFile? image) {
    if (image == null) return false;

    final extension = image.path.toLowerCase();
    return extension.endsWith('.jpg') ||
        extension.endsWith('.jpeg') ||
        extension.endsWith('.png') ||
        extension.endsWith('.webp');
  }

  /// Get image file size in MB
  Future<double> getImageSizeMB(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      return bytes.length / (1024 * 1024);
    } catch (e) {
      return 0.0;
    }
  }

  /// Check if image size is within limits (max 10MB)
  Future<bool> isImageSizeValid(XFile image) async {
    final sizeMB = await getImageSizeMB(image);
    return sizeMB <= 10.0;
  }
}
