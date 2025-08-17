import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../models/recipe_suggestion.dart';
import '../models/ingredient_substitution.dart';
import '../models/nutrition_info.dart';

class AIService {
  static AIService? _instance;
  static AIService get instance => _instance ??= AIService._();
  
  AIService._();
  
  late final Dio _dio;
  
  void initialize() {
    _dio = Dio(BaseOptions(
      baseUrl: '${AppConfig.apiBaseUrl}/api/v1/ai',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ));
    
    // Add auth interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Add auth token if available
        // final token = AuthService.instance.currentToken;
        // if (token != null) {
        //   options.headers['Authorization'] = 'Bearer $token';
        // }
        handler.next(options);
      },
    ));
  }
  
  Future<List<RecipeSuggestion>> getRecipeSuggestions({
    required List<String> ingredients,
    String? cuisinePreference,
    List<String>? dietaryRestrictions,
    String? difficultyLevel,
  }) async {
    try {
      final response = await _dio.post('/recipe-suggestions', data: {
        'ingredients': ingredients,
        'cuisine_preference': cuisinePreference,
        'dietary_restrictions': dietaryRestrictions,
        'difficulty_level': difficultyLevel,
      });
      
      final List<dynamic> data = response.data;
      return data.map((json) => RecipeSuggestion.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<List<IngredientSubstitution>> getIngredientSubstitutions({
    required String originalIngredient,
    required String recipeContext,
    List<String>? dietaryRestrictions,
  }) async {
    try {
      final response = await _dio.post('/ingredient-substitutions', data: {
        'original_ingredient': originalIngredient,
        'recipe_context': recipeContext,
        'dietary_restrictions': dietaryRestrictions,
      });
      
      final List<dynamic> data = response.data;
      return data.map((json) => IngredientSubstitution.fromJson(json)).toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<List<String>> getCookingTips({
    required String recipeTitle,
    required String cookingMethod,
    required String difficultyLevel,
  }) async {
    try {
      final response = await _dio.post('/cooking-tips', data: {
        'recipe_title': recipeTitle,
        'cooking_method': cookingMethod,
        'difficulty_level': difficultyLevel,
      });
      
      return List<String>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<NutritionInfo> analyzeNutrition({
    required List<Map<String, dynamic>> ingredients,
    required int servings,
  }) async {
    try {
      final response = await _dio.post('/nutrition-analysis', data: {
        'ingredients': ingredients,
        'servings': servings,
      });
      
      return NutritionInfo.fromJson(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<List<String>> improveInstructions({
    required List<String> currentInstructions,
    required String recipeTitle,
  }) async {
    try {
      final response = await _dio.post('/improve-instructions', data: {
        'current_instructions': currentInstructions,
        'recipe_title': recipeTitle,
      });
      
      return List<String>.from(response.data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  Future<List<Map<String, dynamic>>> getQuickSuggestions({
    required String ingredients,
  }) async {
    try {
      final response = await _dio.get('/suggestions/quick', queryParameters: {
        'ingredients': ingredients,
      });
      
      return List<Map<String, dynamic>>.from(response.data['suggestions']);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }
  
  String _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        if (e.response?.statusCode == 401) {
          return 'Authentication required. Please log in.';
        } else if (e.response?.statusCode == 403) {
          return 'Access denied. AI features require premium subscription.';
        } else if (e.response?.statusCode == 429) {
          return 'Too many requests. Please try again later.';
        }
        return e.response?.data['detail'] ?? 'Server error occurred.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'Network error. Please check your connection.';
    }
  }
}
