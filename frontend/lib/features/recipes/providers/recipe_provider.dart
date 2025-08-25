import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';

// Recipe filter state
class RecipeFilter {
  final String? cuisine;
  final String? category;
  final int? difficulty;
  final int? maxTime;
  final bool? isFeatured;

  const RecipeFilter({
    this.cuisine,
    this.category,
    this.difficulty,
    this.maxTime,
    this.isFeatured,
  });

  RecipeFilter copyWith({
    String? cuisine,
    String? category,
    int? difficulty,
    int? maxTime,
    bool? isFeatured,
  }) {
    return RecipeFilter(
      cuisine: cuisine ?? this.cuisine,
      category: category ?? this.category,
      difficulty: difficulty ?? this.difficulty,
      maxTime: maxTime ?? this.maxTime,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }

  bool get isEmpty =>
      cuisine == null &&
      category == null &&
      difficulty == null &&
      maxTime == null &&
      isFeatured == null;
}

// Recipe filter provider
final recipeFilterProvider =
    StateProvider<RecipeFilter>((ref) => const RecipeFilter());

// Recipe list provider
final recipeListProvider =
    StateNotifierProvider<RecipeListNotifier, AsyncValue<List<Recipe>>>((ref) {
  final recipeService = ref.watch(recipeServiceProvider);
  final filter = ref.watch(recipeFilterProvider);
  return RecipeListNotifier(recipeService, filter);
});

class RecipeListNotifier extends StateNotifier<AsyncValue<List<Recipe>>> {
  final RecipeService _recipeService;
  RecipeFilter _currentFilter;

  RecipeListNotifier(this._recipeService, this._currentFilter)
      : super(const AsyncValue.loading());

  Future<void> loadRecipes([RecipeFilter? filter]) async {
    if (filter != null) {
      _currentFilter = filter;
    }

    state = const AsyncValue.loading();
    try {
      List<Recipe> recipes;

      if (_currentFilter.isFeatured == true) {
        recipes = await _recipeService.getFeaturedRecipes();
      } else {
        recipes = await _recipeService.getRecipes();
      }

      // Apply client-side filtering
      if (!_currentFilter.isEmpty) {
        recipes = recipes.where((recipe) {
          if (_currentFilter.cuisine != null &&
              recipe.cuisine != _currentFilter.cuisine) {
            return false;
          }
          if (_currentFilter.category != null &&
              recipe.category != _currentFilter.category) {
            return false;
          }
          if (_currentFilter.difficulty != null &&
              recipe.difficulty != _currentFilter.difficulty) {
            return false;
          }
          if (_currentFilter.maxTime != null &&
              recipe.totalTimeMinutes > _currentFilter.maxTime!) {
            return false;
          }
          return true;
        }).toList();
      }

      state = AsyncValue.data(recipes);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

// Recipe detail provider
final recipeDetailProvider =
    FutureProvider.family<Recipe, String>((ref, recipeId) async {
  final recipeService = ref.watch(recipeServiceProvider);
  return recipeService.getRecipe(recipeId);
});

// Recipe service provider
final recipeServiceProvider = Provider<RecipeService>((ref) {
  return RecipeService();
});
