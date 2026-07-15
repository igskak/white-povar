import '../../../core/api/api_error.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import 'recipe_repository.dart';
import 'package:dio/dio.dart';

/// API-based implementation of RecipeRepository
/// This wraps the existing RecipeService with proper error handling and abstraction
class ApiRecipeRepository implements RecipeRepository {
  final RecipeService _recipeService;

  ApiRecipeRepository({required RecipeService recipeService})
      : _recipeService = recipeService;

  @override
  Future<List<Recipe>> searchRecipes(
    String query, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _recipeService.searchRecipes(query,
          cancelToken: cancelToken);
    } on ApiError catch (e) {
      throw _handleApiError(e);
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
    } on ApiError catch (e) {
      throw _handleApiError(e);
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
    } on ApiError catch (e) {
      if (e.type == ApiErrorType.notFound) {
        return null; // Recipe not found
      }
      throw _handleApiError(e);
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
    } on ApiError catch (e) {
      throw _handleApiError(e);
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
    } on ApiError catch (e) {
      throw _handleApiError(e);
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
    } on ApiError catch (e) {
      throw _handleApiError(e);
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
    } on ApiError catch (e) {
      throw _handleApiError(e);
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
    } on ApiError catch (e) {
      throw _handleApiError(e);
    } catch (e) {
      throw RecipeRepositoryException(
        'Failed to get recipes by chef',
        originalError: e,
      );
    }
  }

  RecipeRepositoryException _handleApiError(ApiError error) {
    switch (error.type) {
      case ApiErrorType.unauthorized:
      case ApiErrorType.forbidden:
        return AuthRecipeRepositoryException(
          error.message,
          code: error.statusCode?.toString(),
          originalError: error,
        );
      case ApiErrorType.notFound:
        return NotFoundRecipeRepositoryException(
          error.message,
          code: 'NOT_FOUND',
          originalError: error,
        );
      case ApiErrorType.network:
      case ApiErrorType.timeout:
        return NetworkRecipeRepositoryException(
          error.message,
          code: error.type.name,
          originalError: error,
        );
      default:
        return RecipeRepositoryException(
          error.message,
          code: error.statusCode?.toString(),
          originalError: error,
        );
    }
  }
}
