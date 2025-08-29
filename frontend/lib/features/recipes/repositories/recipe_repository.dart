import '../models/recipe.dart';

/// Abstract repository interface for recipe operations
/// This decouples business logic from data access implementation
abstract class RecipeRepository {
  /// Search recipes by text query
  Future<List<Recipe>> searchRecipes(String query);
  
  /// Get all recipes with optional filtering
  Future<List<Recipe>> getRecipes({
    String? cuisine,
    String? category,
    int? difficulty,
    int? maxTime,
    bool? isFeatured,
    int limit = 20,
    int offset = 0,
  });
  
  /// Get a single recipe by ID
  Future<Recipe?> getRecipe(String id);
  
  /// Get featured recipes
  Future<List<Recipe>> getFeaturedRecipes({int limit = 10});
  
  /// Create a new recipe
  Future<Recipe> createRecipe(Recipe recipe);
  
  /// Update an existing recipe
  Future<Recipe> updateRecipe(Recipe recipe);
  
  /// Delete a recipe
  Future<void> deleteRecipe(String id);
  
  /// Get recipes by chef ID
  Future<List<Recipe>> getRecipesByChef(String chefId, {int limit = 20, int offset = 0});
}

/// Exception thrown when recipe operations fail
class RecipeRepositoryException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const RecipeRepositoryException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'RecipeRepositoryException: $message';
}

/// Network-related repository exceptions
class NetworkRecipeRepositoryException extends RecipeRepositoryException {
  const NetworkRecipeRepositoryException(
    String message, {
    String? code,
    dynamic originalError,
  }) : super(message, code: code, originalError: originalError);
}

/// Authentication-related repository exceptions
class AuthRecipeRepositoryException extends RecipeRepositoryException {
  const AuthRecipeRepositoryException(
    String message, {
    String? code,
    dynamic originalError,
  }) : super(message, code: code, originalError: originalError);
}

/// Not found repository exceptions
class NotFoundRecipeRepositoryException extends RecipeRepositoryException {
  const NotFoundRecipeRepositoryException(
    String message, {
    String? code,
    dynamic originalError,
  }) : super(message, code: code, originalError: originalError);
}
