import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repositories/recipe_repository.dart';
import '../../recipes/repositories/api_recipe_repository.dart';
import '../../recipes/providers/recipe_provider.dart';

/// A dietary constraint, sent to the catalogue as `diet=<wireName>`.
///
/// This is an *exclusion*: the server answers it from a derived per-recipe
/// diet rather than by matching text, because "без м'яса" is a property of the
/// ingredient list and no recipe's title contains the phrase.
enum DietFilter {
  noMeat('no_meat', 'Без м’яса'),
  vegan('vegan', 'Веганські'),
  pescatarian('pescatarian', 'Риба, без м’яса');

  const DietFilter(this.wireName, this.label);

  final String wireName;
  final String label;

  /// Which recipe diets satisfy this filter. An unclassified recipe
  /// (`diet == null`) satisfies none of them: a dietary promise fails closed.
  bool allows(RecipeDiet? diet) => switch (this) {
        DietFilter.noMeat =>
          diet == RecipeDiet.vegetarian || diet == RecipeDiet.vegan,
        DietFilter.vegan => diet == RecipeDiet.vegan,
        DietFilter.pescatarian => diet == RecipeDiet.fish ||
            diet == RecipeDiet.vegetarian ||
            diet == RecipeDiet.vegan,
      };
}

/// Structured Discover filters.
///
/// Every facet here is one the catalogue endpoint can actually answer, so a
/// filter always reaches the server rather than being pasted into the search
/// box as text.
class SearchFilters {
  const SearchFilters({
    this.cuisine,
    this.category,
    this.difficulty,
    this.maxTime,
    this.isFeatured,
    this.diet,
    this.minServings,
  });

  final String? cuisine;
  final String? category;
  final int? difficulty;
  final int? maxTime;
  final bool? isFeatured;
  final DietFilter? diet;
  final int? minServings;

  static const empty = SearchFilters();

  bool get isActive =>
      cuisine != null ||
      category != null ||
      difficulty != null ||
      maxTime != null ||
      isFeatured != null ||
      diet != null ||
      minServings != null;

  int get activeCount => [
        cuisine,
        category,
        difficulty,
        maxTime,
        isFeatured,
        diet,
        minServings,
      ].where((value) => value != null).length;

  /// `null` clears a facet; omitting the argument keeps it.
  SearchFilters copyWith({
    Object? cuisine = _unset,
    Object? category = _unset,
    Object? difficulty = _unset,
    Object? maxTime = _unset,
    Object? isFeatured = _unset,
    Object? diet = _unset,
    Object? minServings = _unset,
  }) =>
      SearchFilters(
        cuisine: identical(cuisine, _unset) ? this.cuisine : cuisine as String?,
        category:
            identical(category, _unset) ? this.category : category as String?,
        difficulty: identical(difficulty, _unset)
            ? this.difficulty
            : difficulty as int?,
        maxTime: identical(maxTime, _unset) ? this.maxTime : maxTime as int?,
        isFeatured: identical(isFeatured, _unset)
            ? this.isFeatured
            : isFeatured as bool?,
        diet: identical(diet, _unset) ? this.diet : diet as DietFilter?,
        minServings: identical(minServings, _unset)
            ? this.minServings
            : minServings as int?,
      );

  /// Narrows an existing result list, used when a text query already ran
  /// server-side and the facets refine it.
  bool matches(Recipe recipe) {
    if (cuisine != null &&
        recipe.cuisine.toLowerCase() != cuisine!.toLowerCase()) {
      return false;
    }
    if (category != null &&
        recipe.category.toLowerCase() != category!.toLowerCase()) {
      return false;
    }
    if (difficulty != null && recipe.difficulty != difficulty) return false;
    if (maxTime != null && recipe.totalTimeMinutes > maxTime!) return false;
    if (isFeatured != null && recipe.isFeatured != isFeatured) return false;
    // The diet the server derived, not a word list re-implemented here: the
    // lexicon lives once, on the backend, and rides along on the recipe.
    if (diet != null && !diet!.allows(recipe.diet)) return false;
    if (minServings != null && recipe.servings < minServings!) return false;
    return true;
  }

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.cuisine == cuisine &&
      other.category == category &&
      other.difficulty == difficulty &&
      other.maxTime == maxTime &&
      other.isFeatured == isFeatured &&
      other.diet == diet &&
      other.minServings == minServings;

  @override
  int get hashCode => Object.hash(
      cuisine, category, difficulty, maxTime, isFeatured, diet, minServings);
}

const Object _unset = Object();

// Simple Text Search State for basic search functionality
class SimpleSearchState {
  final List<Recipe> results;
  final bool isLoading;
  final String? error;
  final String query;
  final List<String> confirmationRequired;
  final List<VoiceRecommendation> recommendations;
  final bool isVoiceIntentSearch;
  final SearchFilters filters;

  const SimpleSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
    this.confirmationRequired = const [],
    this.recommendations = const [],
    this.isVoiceIntentSearch = false,
    this.filters = SearchFilters.empty,
  });

  SimpleSearchState copyWith({
    List<Recipe>? results,
    bool? isLoading,
    String? error,
    String? query,
    List<String>? confirmationRequired,
    List<VoiceRecommendation>? recommendations,
    bool? isVoiceIntentSearch,
    SearchFilters? filters,
  }) {
    return SimpleSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
      confirmationRequired: confirmationRequired ?? this.confirmationRequired,
      recommendations: recommendations ?? this.recommendations,
      isVoiceIntentSearch: isVoiceIntentSearch ?? this.isVoiceIntentSearch,
      filters: filters ?? this.filters,
    );
  }
}

// Recipe Repository Provider
final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return ApiRecipeRepository(recipeService: ref.watch(recipeServiceProvider));
});

// Simple Text Search Notifier
class SimpleSearchNotifier extends StateNotifier<SimpleSearchState> {
  final RecipeRepository _recipeRepository;
  Timer? _debounce;
  CancelToken? _cancelToken;

  SimpleSearchNotifier(this._recipeRepository)
      : super(const SimpleSearchState());

  Future<void> searchRecipes(String query) async {
    _debounce?.cancel();
    _cancelToken?.cancel('Superseded by a newer search query.');
    final filters = state.filters;
    if (query.trim().isEmpty) {
      // An empty query with facets still has something to show: browse the
      // catalogue through the structured endpoint instead of going blank.
      if (filters.isActive) {
        await _browseWithFilters(filters);
      } else {
        state = const SimpleSearchState();
      }
      return;
    }

    // Start a fresh state so an earlier error cannot remain visible while a
    // newer request is being debounced.
    state = SimpleSearchState(
      results: state.results,
      isLoading: true,
      query: query,
      filters: filters,
    );

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await _recipeRepository.searchRecipes(
          query,
          // The diet goes to the server so paging stays honest; `matches`
          // below only narrows the facets the text endpoint cannot express.
          diet: filters.diet?.wireName,
          cancelToken: cancelToken,
        );
        if (identical(_cancelToken, cancelToken)) {
          state = SimpleSearchState(
            results: results.where(filters.matches).toList(growable: false),
            query: query,
            filters: filters,
          );
        }
      } on RecipeRepositoryException catch (e) {
        if (identical(_cancelToken, cancelToken)) {
          state = SimpleSearchState(
            results: state.results,
            error: e.message,
            query: query,
            filters: filters,
          );
        }
      } catch (_) {
        if (identical(_cancelToken, cancelToken) && !cancelToken.isCancelled) {
          state = SimpleSearchState(
            results: state.results,
            error: 'Не вдалося виконати пошук. Спробуйте ще раз.',
            query: query,
            filters: filters,
          );
        }
      }
    });
  }

  /// Applies the structured facets, re-running whichever retrieval path the
  /// current query implies.
  Future<void> applyFilters(SearchFilters filters) async {
    state = state.copyWith(filters: filters);
    if (state.query.trim().isEmpty) {
      if (filters.isActive) {
        await _browseWithFilters(filters);
      } else {
        clearSearch();
      }
      return;
    }
    await searchRecipes(state.query);
  }

  Future<void> _browseWithFilters(SearchFilters filters) async {
    _debounce?.cancel();
    _cancelToken?.cancel('Superseded by a filter change.');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = SimpleSearchState(
        results: state.results, isLoading: true, filters: filters);
    try {
      final results = await _recipeRepository.getRecipes(
        cuisine: filters.cuisine,
        category: filters.category,
        difficulty: filters.difficulty,
        maxTime: filters.maxTime,
        isFeatured: filters.isFeatured,
        diet: filters.diet?.wireName,
        minServings: filters.minServings,
      );
      if (identical(_cancelToken, cancelToken)) {
        state = SimpleSearchState(results: results, filters: filters);
      }
    } on RecipeRepositoryException catch (e) {
      if (identical(_cancelToken, cancelToken)) {
        state = SimpleSearchState(
            results: state.results, error: e.message, filters: filters);
      }
    } catch (_) {
      if (identical(_cancelToken, cancelToken) && !cancelToken.isCancelled) {
        state = SimpleSearchState(
          results: state.results,
          error: 'Не вдалося застосувати фільтри. Спробуйте ще раз.',
          filters: filters,
        );
      }
    }
  }

  Future<void> searchVoiceIntent(String transcript) async {
    _debounce?.cancel();
    _cancelToken?.cancel('Superseded by voice intent retrieval.');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    state = SimpleSearchState(
        results: state.results, isLoading: true, query: transcript);
    try {
      final result = await _recipeRepository.searchVoiceIntent(transcript,
          cancelToken: cancelToken);
      if (identical(_cancelToken, cancelToken)) {
        state = SimpleSearchState(
            results: result.recipes,
            query: transcript,
            confirmationRequired: result.confirmationRequired,
            recommendations: result.recommendations,
            isVoiceIntentSearch: true);
      }
    } on RecipeRepositoryException catch (e) {
      if (identical(_cancelToken, cancelToken)) {
        state = SimpleSearchState(
            results: state.results, error: e.message, query: transcript);
      }
    }
  }

  void clearSearch() {
    _debounce?.cancel();
    _cancelToken?.cancel('Search cleared.');
    state = const SimpleSearchState();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelToken?.cancel('Search notifier disposed.');
    super.dispose();
  }
}

// Simple Text Search Provider
final simpleTextSearchProvider =
    StateNotifierProvider<SimpleSearchNotifier, SimpleSearchState>((ref) {
  final repository = ref.watch(recipeRepositoryProvider);
  return SimpleSearchNotifier(repository);
});
