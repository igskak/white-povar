import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../recipes/models/recipe.dart';
import '../../recipes/repositories/recipe_repository.dart';
import '../../recipes/repositories/api_recipe_repository.dart';
import '../../recipes/providers/recipe_provider.dart';

// Simple Text Search State for basic search functionality
class SimpleSearchState {
  final List<Recipe> results;
  final bool isLoading;
  final String? error;
  final String query;
  final List<String> confirmationRequired;

  const SimpleSearchState({
    this.results = const [],
    this.isLoading = false,
    this.error,
    this.query = '',
    this.confirmationRequired = const [],
  });

  SimpleSearchState copyWith({
    List<Recipe>? results,
    bool? isLoading,
    String? error,
    String? query,
    List<String>? confirmationRequired,
  }) {
    return SimpleSearchState(
      results: results ?? this.results,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      query: query ?? this.query,
      confirmationRequired: confirmationRequired ?? this.confirmationRequired,
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
    if (query.trim().isEmpty) {
      state = const SimpleSearchState();
      return;
    }

    // Start a fresh state so an earlier error cannot remain visible while a
    // newer request is being debounced.
    state = SimpleSearchState(
      results: state.results,
      isLoading: true,
      query: query,
    );

    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final results = await _recipeRepository.searchRecipes(
          query,
          cancelToken: cancelToken,
        );
        if (identical(_cancelToken, cancelToken)) {
          state = SimpleSearchState(results: results, query: query);
        }
      } on RecipeRepositoryException catch (e) {
        if (identical(_cancelToken, cancelToken)) {
          state = SimpleSearchState(
            results: state.results,
            error: e.message,
            query: query,
          );
        }
      } catch (_) {
        if (identical(_cancelToken, cancelToken) && !cancelToken.isCancelled) {
          state = SimpleSearchState(
            results: state.results,
            error: 'Не вдалося виконати пошук. Спробуйте ще раз.',
            query: query,
          );
        }
      }
    });
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
            confirmationRequired: result.confirmationRequired);
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
