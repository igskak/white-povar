import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/config/app_config.dart';
import '../../recipes/models/recipe.dart';
import '../models/detected_ingredient.dart';
import 'image_processing_service.dart';

class PhotoSearchService {
  final Dio _dio;
  final ImageProcessingService _imageProcessingService;

  PhotoSearchService({
    Dio? dio,
    ImageProcessingService? imageProcessingService,
  })  : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: '${AppConfig.apiBaseUrl}/api/v1/search',
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
              headers: {
                'Content-Type': 'application/json',
              },
            )),
        _imageProcessingService =
            imageProcessingService ?? ImageProcessingService();

  /// Search recipes by photo using the existing backend API
  Future<PhotoSearchResponse> searchByPhoto({
    required XFile image,
    String? chefId,
    int maxResults = 10,
  }) async {
    try {
      // Validate and prepare image
      final imageData = await _imageProcessingService.prepareForAPI(
        image,
        chefId: chefId,
        maxResults: maxResults,
      );

      // Make API call to existing endpoint
      final response = await _dio.post('/photo', data: imageData);

      // Parse response
      final data = response.data as Map<String, dynamic>;

      return PhotoSearchResponse(
        ingredients: List<String>.from(data['ingredients'] ?? []),
        suggestedRecipes:
            List<Map<String, dynamic>>.from(data['suggested_recipes'] ?? []),
        confidenceScore: (data['confidence_score'] ?? 0.0).toDouble(),
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('Photo search failed: $e');
    }
  }

  /// Convert API ingredients response to DetectedIngredient objects
  List<DetectedIngredient> parseDetectedIngredients(
    List<String> ingredients,
    double overallConfidence,
  ) {
    return ingredients.asMap().entries.map((entry) {
      final index = entry.key;
      final name = entry.value;

      // Distribute confidence scores (higher for first ingredients)
      final confidence =
          overallConfidence * (1.0 - (index * 0.1)).clamp(0.3, 1.0);

      return DetectedIngredient(
        id: 'detected_$index',
        name: name,
        confidence: confidence,
        isConfirmed: true,
      );
    }).toList();
  }

  /// Convert suggested recipes to Recipe objects
  List<Recipe> parseSuggestedRecipes(List<Map<String, dynamic>> recipesData) {
    return recipesData
        .map((data) {
          try {
            return Recipe.fromJson(data);
          } catch (e) {
            // Log error and skip invalid recipe
            print('Failed to parse recipe: $e');
            return null;
          }
        })
        .where((recipe) => recipe != null)
        .cast<Recipe>()
        .toList();
  }

  /// Get image analysis without recipe search (for ingredient review)
  Future<List<DetectedIngredient>> analyzeIngredientsOnly({
    required XFile image,
    String? chefId,
  }) async {
    try {
      final result = await searchByPhoto(
        image: image,
        chefId: chefId,
        maxResults: 1, // Minimal recipe results since we only want ingredients
      );

      return parseDetectedIngredients(
        result.ingredients,
        result.confidenceScore,
      );
    } catch (e) {
      throw Exception('Ingredient analysis failed: $e');
    }
  }

  /// Search recipes using confirmed ingredients
  Future<List<Recipe>> searchRecipesByIngredients({
    required List<String> ingredients,
    String? chefId,
    int maxResults = 20,
  }) async {
    try {
      // Use text search endpoint with ingredient names
      final query = ingredients.join(' ');

      final response = await _dio.get('/text', queryParameters: {
        'q': query,
        if (chefId != null) 'chef_id': chefId,
        'limit': maxResults,
        'offset': 0,
      });

      final data = response.data as Map<String, dynamic>;
      final recipesData =
          List<Map<String, dynamic>>.from(data['recipes'] ?? []);

      return parseSuggestedRecipes(recipesData);
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw Exception('Recipe search failed: $e');
    }
  }

  /// Handle Dio errors with user-friendly messages
  Exception _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception(
            'Request timed out. Please check your internet connection.');

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        final message = e.response?.data?['detail'] ?? 'Server error';

        switch (statusCode) {
          case 400:
            return Exception('Invalid image. Please try a different photo.');
          case 413:
            return Exception('Image is too large. Please use a smaller image.');
          case 429:
            return Exception(
                'Too many requests. Please wait a moment and try again.');
          case 500:
            return Exception('Server error. Please try again later.');
          default:
            return Exception('Error: $message');
        }

      case DioExceptionType.cancel:
        return Exception('Request was cancelled.');

      case DioExceptionType.unknown:
      default:
        return Exception(
            'Network error. Please check your internet connection.');
    }
  }

  /// Test connection to the API
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
