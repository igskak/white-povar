import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repositories/recipe_repository.dart';
import '../../recipes/repositories/api_recipe_repository.dart';

// Simple Text Search State for basic search functionality
class SimpleSearchState {
  final List<Recipe> results;
  final bool isLoading;
  final String? error;
  final String query;

  const SimpleSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
  });

  SimpleSearchState copyWith({
    List<Recipe>? results,
    bool? isLoading,
    String? error,
    String? query,
  }) {
    return SimpleSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
    );
  }
}

// Recipe Repository Provider
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return ApiRecipeRepository();
});

// Simple Text Search Notifier
class SimpleSearchNotifier extends StateNotifier<SimpleSearchState> {
  final RecipeRepository _recipeRepository;

  SimpleSearchNotifier(this._recipeRepository)
      : super(const SimpleSearchState());

  Future<void> searchRecipes(String query) async {
    if (query.trim().isEmpty) {
      state = const SimpleSearchState();
      return;
    }

    state = state.copyWith(
      isLoading: true,
      error: null,
      query: query,
    );

    try {
      final results = await _recipeRepository.searchRecipes(query);
      state = state.copyWith(
        results: results,
        isLoading: false,
      );
    } on RecipeRepositoryException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'An unexpected error occurred',
      );
    }
  }

  void clearSearch() {
    state = const SimpleSearchState();
  }
}

// Simple Text Search Provider
final simpleTextSearchProvider =
    StateNotifierProvider<SimpleSearchNotifier, SimpleSearchState>((ref) {
  final repository = ref.watch(recipeRepositoryProvider);
  return SimpleSearchNotifier(repository);
});
