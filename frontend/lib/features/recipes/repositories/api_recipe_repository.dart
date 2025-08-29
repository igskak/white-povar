import 'package:dio/dio.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import 'recipe_repository.dart';
import '../../../core/services/error_handler.dart';

/// API-based implementation of RecipeRepository
/// This wraps the existing RecipeService with proper error handling and abstraction
class ApiRecipeRepository implements RecipeRepository {
  final RecipeService _recipeService;

  ApiRecipeRepository({RecipeService? recipeService})
      : _recipeService = recipeService ?? RecipeService();

  @override
  Future<List<Recipe>> searchRecipes(String query) async {
    try {
      return await _recipeService.searchRecipes(query);
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw RecipeRepositoryException(
        'Failed to search recipes',
        originalError: e,
      );
    }
  }

  @override
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
      // Note: Current RecipeService doesn't support filtering parameters
      // This is a limitation that should be addressed in the service layer
      // For now, we'll get all recipes and filter client-side if needed
      final allRecipes = await _recipeService.getRecipes();

      // Apply client-side filtering if parameters are provided
      var filteredRecipes = allRecipes.where((recipe) {
        if (cuisine != null && recipe.cuisine != cuisine) return false;
        if (category != null && recipe.category != category) return false;
        if (difficulty != null && recipe.difficulty != difficulty) return false;
        if (maxTime != null && recipe.totalTimeMinutes > maxTime) return false;
        if (isFeatured != null && recipe.isFeatured != isFeatured) return false;
        return true;
      }).toList();

      // Apply pagination
      if (offset > 0) {
        filteredRecipes = filteredRecipes.skip(offset).toList();
      }
      if (limit > 0 && filteredRecipes.length > limit) {
        filteredRecipes = filteredRecipes.take(limit).toList();
      }

      return filteredRecipes;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw RecipeRepositoryException(
        'Failed to get recipes',
        originalError: e,
      );
    }
  }

  @override
  Future<Recipe?> getRecipe(String id) async {
    try {
      return await _recipeService.getRecipe(id);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null; // Recipe not found
      }
      throw _handleDioException(e);
    } catch (e) {
      throw RecipeRepositoryException(
        'Failed to get recipe',
        originalError: e,
      );
    }
  }

  @override
  Future<List<Recipe>> getFeaturedRecipes({int limit = 10}) async {
    try {
      return await _recipeService.getFeaturedRecipes();
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw RecipeRepositoryException(
        'Failed to get featured recipes',
        originalError: e,
      );
    }
  }

  @override
  Future<Recipe> createRecipe(Recipe recipe) async {
    try {
      return await _recipeService.createRecipe(recipe);
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw RecipeRepositoryException(
        'Failed to create recipe',
        originalError: e,
      );
    }
  }

  @override
  Future<Recipe> updateRecipe(Recipe recipe) async {
    try {
      return await _recipeService.updateRecipe(recipe.id.toString(), recipe);
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw RecipeRepositoryException(
        'Failed to update recipe',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteRecipe(String id) async {
    try {
      await _recipeService.deleteRecipe(id);
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw RecipeRepositoryException(
        'Failed to delete recipe',
        originalError: e,
      );
    }
  }

  @override
  Future<List<Recipe>> getRecipesByChef(String chefId,
      {int limit = 20, int offset = 0}) async {
    try {
      // Note: Current RecipeService doesn't support chef filtering
      // This is a limitation that should be addressed in the service layer
      // For now, we'll get all recipes and filter by chef client-side
      final allRecipes = await _recipeService.getRecipes();

      var chefRecipes = allRecipes
          .where((recipe) => recipe.chefId.toString() == chefId)
          .toList();

      // Apply pagination
      if (offset > 0) {
        chefRecipes = chefRecipes.skip(offset).toList();
      }
      if (limit > 0 && chefRecipes.length > limit) {
        chefRecipes = chefRecipes.take(limit).toList();
      }

      return chefRecipes;
    } on DioException catch (e) {
      throw _handleDioException(e);
    } catch (e) {
      throw RecipeRepositoryException(
        'Failed to get recipes by chef',
        originalError: e,
      );
    }
  }

  /// Convert DioException to appropriate repository exception using standardized error handler
  RecipeRepositoryException _handleDioException(DioException e) {
    // Log the error for debugging
    ErrorHandler.logError(e);

    // Use the standardized error handler to get user-friendly message
    final message = ErrorHandler.getErrorMessage(e);

    // Determine the appropriate exception type based on error characteristics
    if (ErrorHandler.isNetworkError(e)) {
      return NetworkRecipeRepositoryException(
        message,
        code: 'NETWORK_ERROR',
        originalError: e,
      );
    }

    if (ErrorHandler.isAuthError(e)) {
      return AuthRecipeRepositoryException(
        message,
        code: 'AUTH_ERROR',
        originalError: e,
      );
    }

    if (ErrorHandler.isServerError(e)) {
      return NetworkRecipeRepositoryException(
        message,
        code: 'SERVER_ERROR',
        originalError: e,
      );
    }

    // Handle specific status codes
    if (e.response?.statusCode == 404) {
      return NotFoundRecipeRepositoryException(
        message,
        code: 'NOT_FOUND',
        originalError: e,
      );
    }

    // Default to generic repository exception
    return RecipeRepositoryException(
      message,
      code: e.response?.statusCode?.toString() ?? 'UNKNOWN',
      originalError: e,
    );
  }
}
