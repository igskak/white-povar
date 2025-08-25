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

  /// Validate image format
  bool isValidFormat(XFile image) {
    final extension = image.path.toLowerCase();
    final validExtensions = ['.jpg', '.jpeg', '.png', '.webp'];
    
    return validExtensions.any((ext) => extension.endsWith(ext));
  }

  /// Get image format from file extension
  String getImageFormat(XFile image) {
    final extension = image.path.toLowerCase();
    
    if (extension.endsWith('.jpg') || extension.endsWith('.jpeg')) {
      return 'JPEG';
    } else if (extension.endsWith('.png')) {
      return 'PNG';
    } else if (extension.endsWith('.webp')) {
      return 'WEBP';
    }
    
    return 'UNKNOWN';
  }

  /// Check if image size is within API limits
  Future<bool> isWithinSizeLimit(XFile image, {int maxSizeMB = 10}) async {
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

    // Check format
    if (!isValidFormat(image)) {
      errors.add('Invalid image format. Please use JPEG, PNG, or WEBP.');
    }

    // Check size
    final isValidSize = await isWithinSizeLimit(image);
    if (!isValidSize) {
      errors.add('Image is too large. Maximum size is 10MB.');
    }

    // Check file size for optimal processing
    try {
      final bytes = await image.readAsBytes();
      final sizeMB = bytes.length / (1024 * 1024);
      
      if (sizeMB < 0.1) {
        warnings.add('Image might be too small for optimal recognition.');
      } else if (sizeMB > 5) {
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
      throw Exception('Image validation failed: ${validation.errors.join(', ')}');
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
