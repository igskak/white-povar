import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import '../../recipes/models/recipe.dart';
import '../models/detected_ingredient.dart';
import 'image_processing_service.dart';

class PhotoSearchService {
  final ApiClient _apiClient;
  final ImageProcessingService _imageProcessingService;

  PhotoSearchService({
    required ApiClient apiClient,
    ImageProcessingService? imageProcessingService,
  })  : _apiClient = apiClient,
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
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/v1/search/photo',
        data: imageData,
      );

      // Parse response
      final data = response.data!;

      return PhotoSearchResponse(
        ingredients: List<String>.from(data['ingredients'] ?? []),
        suggestedRecipes:
            List<Map<String, dynamic>>.from(data['suggested_recipes'] ?? []),
        confidenceScore: (data['confidence_score'] ?? 0.0).toDouble(),
      );
    } on ApiError {
      rethrow;
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
            debugPrint('Failed to parse recipe: $e');
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

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/v1/search/text',
        queryParameters: {
          'q': query,
          if (chefId != null) 'chef_id': chefId,
          'limit': maxResults,
          'offset': 0,
        },
      );

      final data = response.data!;
      final recipesData =
          List<Map<String, dynamic>>.from(data['recipes'] ?? []);

      return parseSuggestedRecipes(recipesData);
    } on ApiError {
      rethrow;
    } catch (e) {
      throw Exception('Recipe search failed: $e');
    }
  }
}
