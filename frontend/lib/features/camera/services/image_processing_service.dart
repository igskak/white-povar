import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class ImageProcessingService {
  /// Convert image to base64 string for API upload
  Future<String> convertToBase64(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      throw Exception('Failed to convert image to base64: $e');
    }
  }

  /// Validate image format (supports iPhone HEIC and all common formats)
  bool isValidFormat(XFile image) {
    // Check file extension first
    final extension = image.path.toLowerCase();
    final validExtensions = [
      '.jpg', '.jpeg', '.png', '.webp',
      '.heic', '.heif', // iPhone formats
      '.bmp', '.gif' // Additional common formats
    ];

    if (validExtensions.any((ext) => extension.endsWith(ext))) {
      return true;
    }

    // For web and mobile, check MIME type as fallback
    final mimeType = image.mimeType?.toLowerCase();
    if (mimeType != null) {
      final validMimeTypes = [
        'image/jpeg',
        'image/jpg',
        'image/png',
        'image/webp',
        'image/heic', // iPhone HEIC
        'image/heif', // iPhone HEIF
        'image/bmp',
        'image/gif'
      ];
      return validMimeTypes.contains(mimeType);
    }

    // If no extension and no MIME type, assume it's valid
    // This handles camera captures on different platforms
    return true;
  }

  /// Get image format from file extension or MIME type
  String getImageFormat(XFile image) {
    final extension = image.path.toLowerCase();

    if (extension.endsWith('.jpg') || extension.endsWith('.jpeg')) {
      return 'JPEG';
    } else if (extension.endsWith('.png')) {
      return 'PNG';
    } else if (extension.endsWith('.webp')) {
      return 'WEBP';
    } else if (extension.endsWith('.heic')) {
      return 'HEIC';
    } else if (extension.endsWith('.heif')) {
      return 'HEIF';
    } else if (extension.endsWith('.bmp')) {
      return 'BMP';
    } else if (extension.endsWith('.gif')) {
      return 'GIF';
    }

    // Fallback to MIME type for web/mobile captures
    final mimeType = image.mimeType?.toLowerCase();
    if (mimeType != null) {
      if (mimeType.contains('jpeg') || mimeType.contains('jpg')) {
        return 'JPEG';
      } else if (mimeType.contains('png')) {
        return 'PNG';
      } else if (mimeType.contains('webp')) {
        return 'WEBP';
      } else if (mimeType.contains('heic')) {
        return 'HEIC';
      } else if (mimeType.contains('heif')) {
        return 'HEIF';
      } else if (mimeType.contains('bmp')) {
        return 'BMP';
      } else if (mimeType.contains('gif')) {
        return 'GIF';
      }
    }

    // Default to JPEG for unknown formats (most compatible)
    return 'JPEG';
  }

  /// Check if image size is within API limits (increased for modern phones)
  Future<bool> isWithinSizeLimit(XFile image, {int maxSizeMB = 20}) async {
    try {
      final bytes = await image.readAsBytes();
      final sizeMB = bytes.length / (1024 * 1024);
      return sizeMB <= maxSizeMB;
    } catch (e) {
      return false;
    }
  }

  /// Get image dimensions (basic implementation)
  Future<Map<String, int>?> getImageDimensions(XFile image) async {
    try {
      // This is a basic implementation
      // For more accurate dimensions, you might want to use a package like 'image'
      final bytes = await image.readAsBytes();

      // For now, return null as we don't have image package
      // In a real implementation, you would decode the image and get actual dimensions
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Validate image for AI processing
  Future<ImageValidationResult> validateForAI(XFile image) async {
    final errors = <String>[];
    final warnings = <String>[];

    // Check format (more lenient for web)
    if (!isValidFormat(image)) {
      warnings
          .add('Image format could not be determined. Proceeding with upload.');
    }

    // Check size (more generous for modern phone cameras)
    final isValidSize = await isWithinSizeLimit(image);
    if (!isValidSize) {
      errors.add('Image is too large. Maximum size is 20MB.');
    }

    // Check file size for optimal processing
    try {
      final bytes = await image.readAsBytes();
      final sizeMB = bytes.length / (1024 * 1024);

      if (sizeMB < 0.1) {
        warnings.add('Image might be too small for optimal recognition.');
      } else if (sizeMB > 10) {
        warnings.add('Large image may take longer to process.');
      }
    } catch (e) {
      errors.add('Failed to read image file.');
    }

    return ImageValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Prepare image data for API request
  Future<Map<String, dynamic>> prepareForAPI(
    XFile image, {
    String? chefId,
    int maxResults = 10,
  }) async {
    final validation = await validateForAI(image);
    if (!validation.isValid) {
      throw Exception(
          'Image validation failed: ${validation.errors.join(', ')}');
    }

    final base64Image = await convertToBase64(image);

    return {
      'image': base64Image,
      if (chefId != null) 'chef_id': chefId,
      'max_results': maxResults,
    };
  }

  /// Get image metadata for debugging
  Future<Map<String, dynamic>> getImageMetadata(XFile image) async {
    try {
      final bytes = await image.readAsBytes();
      final sizeMB = bytes.length / (1024 * 1024);

      return {
        'path': image.path,
        'name': image.name,
        'size_bytes': bytes.length,
        'size_mb': double.parse(sizeMB.toStringAsFixed(2)),
        'format': getImageFormat(image),
        'mime_type': image.mimeType,
      };
    } catch (e) {
      return {
        'error': 'Failed to get metadata: $e',
      };
    }
  }

  /// Get device-optimized image quality settings
  Map<String, dynamic> getOptimizedSettings() {
    // Optimize based on platform capabilities
    return {
      'maxWidth': 2048,
      'maxHeight': 2048,
      'imageQuality': 85,
      'maxSizeMB': 20,
      'supportedFormats': ['JPEG', 'PNG', 'WEBP', 'HEIC', 'HEIF', 'BMP', 'GIF'],
    };
  }

  /// Check if format is supported by backend
  bool isBackendCompatible(String format) {
    // Backend typically supports these formats well
    final backendFormats = ['JPEG', 'PNG', 'WEBP'];
    return backendFormats.contains(format.toUpperCase());
  }

  /// Provide user-friendly format information
  String getFormatDescription(String format) {
    switch (format.toUpperCase()) {
      case 'HEIC':
      case 'HEIF':
        return 'iPhone photo format (will be processed)';
      case 'JPEG':
      case 'JPG':
        return 'Standard photo format';
      case 'PNG':
        return 'High quality format';
      case 'WEBP':
        return 'Modern web format';
      default:
        return 'Supported image format';
    }
  }
}

class ImageValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ImageValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
  });

  bool get hasWarnings => warnings.isNotEmpty;
  bool get hasErrors => errors.isNotEmpty;
}
