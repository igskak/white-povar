import '../models/recipe.dart';
import '../../../core/api/api_client.dart';
import 'package:dio/dio.dart';

class RecipeService {
  RecipeService(this._apiClient);

  final ApiClient _apiClient;

  // Get a tenant-scoped catalog page. Filters are applied by the API.
  Future<List<Recipe>> getRecipes({
    String? cuisine,
    String? category,
    int? difficulty,
    int? maxTime,
    bool? isFeatured,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/v1/recipes',
        queryParameters: {
          if (cuisine != null) 'cuisine': cuisine,
          if (category != null) 'category': category,
          if (difficulty != null) 'difficulty': difficulty,
          if (maxTime != null) 'max_time': maxTime,
          if (isFeatured != null) 'is_featured': isFeatured,
          'limit': limit,
          'offset': offset,
        },
      );
      if (response.statusCode == 200) {
        final responseData = response.data!;
        final List<dynamic> recipesData =
            responseData['recipes'] as List<dynamic>;
        return recipesData.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load recipes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load recipes: $e');
    }
  }

  // Get featured recipes
  Future<List<Recipe>> getFeaturedRecipes() async {
    try {
      final response =
          await _apiClient.get<List<dynamic>>('/api/v1/recipes/featured');
      if (response.statusCode == 200) {
        final data = response.data!;
        return data.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception(
            'Failed to load featured recipes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load featured recipes: $e');
    }
  }

  // Get recipe by ID
  Future<Recipe> getRecipe(String id) async {
    try {
      final response =
          await _apiClient.get<Map<String, dynamic>>('/api/v1/recipes/$id');
      if (response.statusCode == 200) {
        final data = response.data!;
        return Recipe.fromJson(data);
      } else {
        throw Exception('Failed to load recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load recipe: $e');
    }
  }

  // Create new recipe
  Future<Recipe> createRecipe(Recipe recipe) async {
    try {
      final response = await _apiClient
          .post<Map<String, dynamic>>('/api/v1/recipes', data: recipe.toJson());
      if (response.statusCode == 201) {
        final data = response.data!;
        return Recipe.fromJson(data);
      } else {
        throw Exception('Failed to create recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to create recipe: $e');
    }
  }

  // Update recipe
  Future<Recipe> updateRecipe(String id, Recipe recipe) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
          '/api/v1/recipes/$id',
          data: recipe.toJson());
      if (response.statusCode == 200) {
        final data = response.data!;
        return Recipe.fromJson(data);
      } else {
        throw Exception('Failed to update recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to update recipe: $e');
    }
  }

  // Delete recipe
  Future<void> deleteRecipe(String id) async {
    try {
      final response = await _apiClient.delete<void>('/api/v1/recipes/$id');

      if (response.statusCode != 204) {
        throw Exception('Failed to delete recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete recipe: $e');
    }
  }

  // Search recipes
  Future<List<Recipe>> searchRecipes(
    String query, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/api/v1/search/catalog',
        queryParameters: {'q': query, 'limit': 20, 'offset': 0},
        cancelToken: cancelToken,
      );
      if (response.statusCode == 200) {
        final data = response.data!;
        final List<dynamic> recipes = data['recipes'] ?? [];
        return recipes.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search recipes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search recipes: $e');
    }
  }

  /// Discovery facets are calculated by the tenant-scoped search API.
  Future<Map<String, dynamic>> getSearchFilterOptions() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/search/filters',
    );
    if (response.statusCode != 200 || response.data == null) {
      throw Exception('Failed to load search filters: ${response.statusCode}');
    }
    return response.data!;
  }

  // Get user's favorite recipes
  Future<List<Recipe>> getFavoriteRecipes() async {
    try {
      final response =
          await _apiClient.get<List<dynamic>>('/api/v1/recipes/favorites');
      if (response.statusCode == 200) {
        final data = response.data!;
        return data.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load favorites: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load favorites: $e');
    }
  }

  /// Persist a desired favorite state. This is deliberately not a toggle: a
  /// retry or a second quick tap must not accidentally invert the result.
  Future<bool> setFavorite(String recipeId, bool isFavorite) async {
    try {
      final response = await _apiClient.put<Map<String, dynamic>>(
        '/api/v1/recipes/$recipeId/favorite',
        queryParameters: {'is_favorite': isFavorite},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to save recipe: ${response.statusCode}');
      }
      return response.data?['is_favorite'] == true;
    } catch (e) {
      throw Exception('Failed to save recipe: $e');
    }
  }

  @Deprecated('Use setFavorite with an explicit desired state.')
  Future<void> toggleFavorite(String recipeId) async {
    await setFavorite(recipeId, true);
  }
}
