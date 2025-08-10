import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';

// Recipe list provider
final recipeListProvider = StateNotifierProvider<RecipeListNotifier, AsyncValue<List<Recipe>>>((ref) {
  final recipeService = ref.watch(recipeServiceProvider);
  return RecipeListNotifier(recipeService);
});

class RecipeListNotifier extends StateNotifier<AsyncValue<List<Recipe>>> {
  final RecipeService _recipeService;

  RecipeListNotifier(this._recipeService) : super(const AsyncValue.loading());

  Future<void> loadRecipes() async {
    state = const AsyncValue.loading();
    try {
      final recipes = await _recipeService.getRecipes();
      state = AsyncValue.data(recipes);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

// Recipe detail provider
final recipeDetailProvider = FutureProvider.family<Recipe, String>((ref, recipeId) async {
  final recipeService = ref.watch(recipeServiceProvider);
  return recipeService.getRecipe(recipeId);
});

// Recipe service provider
final recipeServiceProvider = Provider<RecipeService>((ref) {
  return RecipeService();
});
