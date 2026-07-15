import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
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
      final recipes = await _recipeService.getRecipes(
        cuisine: _currentFilter.cuisine,
        category: _currentFilter.category,
        difficulty: _currentFilter.difficulty,
        maxTime: _currentFilter.maxTime,
        isFeatured: _currentFilter.isFeatured,
      );

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

final favoriteRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const [];
  final recipeService = ref.watch(recipeServiceProvider);
  return recipeService.getFavoriteRecipes();
});

/// The single in-memory source of truth for saved state across cards, detail
/// and Saved. It is cleared as soon as the auth session ends.
final favoriteIdsProvider =
    StateNotifierProvider<FavoriteNotifier, Set<String>>((ref) {
  final notifier = FavoriteNotifier(ref.read(recipeServiceProvider), ref);
  ref.listen(currentUserProvider, (previous, next) {
    if (next != null) {
      notifier.onAuthenticated();
    } else if (previous != null) {
      notifier.clearForLogout();
    }
  }, fireImmediately: true);
  return notifier;
});

class FavoriteNotifier extends StateNotifier<Set<String>> {
  FavoriteNotifier(this._recipeService, this._ref) : super(<String>{});

  final RecipeService _recipeService;
  final Ref _ref;
  final Map<String, Future<void>> _writes = {};
  String? _guestIntentRecipeId;

  bool isFavorite(String recipeId) => state.contains(recipeId);

  void queueGuestIntent(String recipeId) {
    _guestIntentRecipeId = recipeId;
  }

  Future<void> onAuthenticated() async {
    try {
      final recipes = await _recipeService.getFavoriteRecipes();
      state = recipes.map((recipe) => recipe.id).toSet();
      _ref.invalidate(favoriteRecipesProvider);
      final intent = _guestIntentRecipeId;
      _guestIntentRecipeId = null;
      if (intent != null) await setFavorite(intent, true);
    } catch (_) {
      // Cards remain usable; a mutation will expose its own recoverable error.
    }
  }

  void clearForLogout() {
    _guestIntentRecipeId = null;
    state = <String>{};
    _ref.invalidate(favoriteRecipesProvider);
  }

  /// Optimistically changes the local canonical state and serializes writes per
  /// recipe. A failure rolls back only when no newer intent has superseded it.
  Future<void> setFavorite(String recipeId, bool shouldSave) {
    final before = Set<String>.from(state);
    state = {...state}
      ..remove(recipeId)
      ..addAll(shouldSave ? [recipeId] : []);

    final previous =
        (_writes[recipeId] ?? Future<void>.value()).catchError((_) {});
    final write = previous.then((_) async {
      try {
        final confirmed =
            await _recipeService.setFavorite(recipeId, shouldSave);
        if (state.contains(recipeId) == shouldSave) {
          state = {...state}
            ..remove(recipeId)
            ..addAll(confirmed ? [recipeId] : []);
        }
        _ref.invalidate(favoriteRecipesProvider);
      } catch (_) {
        if (state.contains(recipeId) == shouldSave) state = before;
        rethrow;
      }
    });
    late final Future<void> tracked;
    tracked = write.whenComplete(() {
      if (identical(_writes[recipeId], tracked)) _writes.remove(recipeId);
    });
    _writes[recipeId] = tracked;
    return tracked;
  }
}

// Recipe service provider
final recipeServiceProvider = Provider<RecipeService>((ref) {
  return RecipeService(ref.watch(apiClientProvider));
});
