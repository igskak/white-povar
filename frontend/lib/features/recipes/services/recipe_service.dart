import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/recipe.dart';
import '../../../core/config/app_config.dart';
import '../../auth/services/auth_service.dart';

class RecipeService {
  final AuthService _authService = AuthService();
  
  // Get auth headers for API calls
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _authService.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Get all recipes
  Future<List<Recipe>> getRecipes() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(AppConfig.recipesEndpoint),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load recipes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load recipes: $e');
    }
  }

  // Get recipe by ID
  Future<Recipe> getRecipe(String id) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${AppConfig.recipesEndpoint}/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse(AppConfig.recipesEndpoint),
        headers: headers,
        body: jsonEncode(recipe.toJson()),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
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
      final headers = await _getAuthHeaders();
      final response = await http.put(
        Uri.parse('${AppConfig.recipesEndpoint}/$id'),
        headers: headers,
        body: jsonEncode(recipe.toJson()),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
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
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('${AppConfig.recipesEndpoint}/$id'),
        headers: headers,
      );

      if (response.statusCode != 204) {
        throw Exception('Failed to delete recipe: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to delete recipe: $e');
    }
  }

  // Search recipes
  Future<List<Recipe>> searchRecipes(String query) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${AppConfig.searchEndpoint}?q=${Uri.encodeComponent(query)}'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to search recipes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to search recipes: $e');
    }
  }

  // Get user's favorite recipes
  Future<List<Recipe>> getFavoriteRecipes() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${AppConfig.recipesEndpoint}/favorites'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Recipe.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load favorites: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load favorites: $e');
    }
  }

  // Toggle recipe favorite status
  Future<void> toggleFavorite(String recipeId) async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${AppConfig.recipesEndpoint}/$recipeId/favorite'),
        headers: headers,
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to toggle favorite: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to toggle favorite: $e');
    }
  }
}
