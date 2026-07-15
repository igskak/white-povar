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
      return await _recipeService.getRecipes(
        cuisine: cuisine,
        category: category,
        difficulty: difficulty,
        maxTime: maxTime,
        isFeatured: isFeatured,
        limit: limit,
        offset: offset,
      );
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
      // Consumer catalog access is always scoped by X-Tenant-Slug.  Accepting
      // a caller-selected chef here would reintroduce cross-tenant discovery.
      return await _recipeService.getRecipes(limit: limit, offset: offset);
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
