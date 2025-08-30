import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/detected_ingredient.dart';
import '../services/photo_search_service.dart';

// Service provider
final photoSearchServiceProvider = Provider<PhotoSearchService>(
  (ref) => PhotoSearchService(),
);

// Photo search state provider
final photoSearchProvider =
    StateNotifierProvider<PhotoSearchNotifier, PhotoSearchState>((ref) {
  return PhotoSearchNotifier(
    photoSearchService: ref.watch(photoSearchServiceProvider),
  );
});

// Ingredient editing provider
final ingredientEditProvider =
    StateNotifierProvider<IngredientEditNotifier, List<DetectedIngredient>>(
        (ref) {
  return IngredientEditNotifier();
});

class PhotoSearchNotifier extends StateNotifier<PhotoSearchState> {
  final PhotoSearchService _photoSearchService;

  PhotoSearchNotifier({
    required PhotoSearchService photoSearchService,
  })  : _photoSearchService = photoSearchService,
        super(const PhotoSearchState());

  /// Analyze image and detect ingredients
  Future<void> analyzeImage({
    required XFile image,
    String? chefId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      detectedIngredients: [],
    );

    try {
      final detectedIngredients =
          await _photoSearchService.analyzeIngredientsOnly(
        image: image,
        chefId: chefId,
      );

      state = state.copyWith(
        isLoading: false,
        detectedIngredients: detectedIngredients,
        confidence: detectedIngredients.isNotEmpty
            ? detectedIngredients
                    .map((i) => i.confidence)
                    .reduce((a, b) => a + b) /
                detectedIngredients.length
            : 0.0,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Search recipes using detected ingredients
  Future<void> searchRecipes({
    required List<String> ingredients,
    String? chefId,
    int maxResults = 20,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final recipes = await _photoSearchService.searchRecipesByIngredients(
        ingredients: ingredients,
        chefId: chefId,
        maxResults: maxResults,
      );

      // Convert Recipe objects to Map for compatibility
      final recipeMaps = recipes
          .map((recipe) => recipe.toJson())
          .toList()
          .cast<Map<String, dynamic>>();

      state = state.copyWith(
        isLoading: false,
        suggestedRecipes: recipeMaps,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Perform complete photo search (analyze + search recipes)
  Future<void> searchByPhoto({
    required XFile image,
    String? chefId,
    int maxResults = 10,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      detectedIngredients: [],
      suggestedRecipes: [],
    );

    try {
      final response = await _photoSearchService.searchByPhoto(
        image: image,
        chefId: chefId,
        maxResults: maxResults,
      );

      final detectedIngredients = _photoSearchService.parseDetectedIngredients(
        response.ingredients,
        response.confidenceScore,
      );

      state = state.copyWith(
        isLoading: false,
        detectedIngredients: detectedIngredients,
        suggestedRecipes: response.suggestedRecipes,
        confidence: response.confidenceScore,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Clear search results
  void clearResults() {
    state = const PhotoSearchState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

class IngredientEditNotifier extends StateNotifier<List<DetectedIngredient>> {
  IngredientEditNotifier() : super([]);

  /// Set initial ingredients from detection
  void setIngredients(List<DetectedIngredient> ingredients) {
    state = ingredients;
  }

  /// Add a new ingredient
  void addIngredient(String name, {String? notes}) {
    final newIngredient = DetectedIngredient(
      id: 'manual_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      confidence: 1.0, // Manual entries have full confidence
      isConfirmed: true,
      notes: notes,
    );

    state = [...state, newIngredient];
  }

  /// Update an existing ingredient
  void updateIngredient(
    String id, {
    String? name,
    bool? isConfirmed,
    String? notes,
  }) {
    state = state.map((ingredient) {
      if (ingredient.id == id) {
        return ingredient.copyWith(
          name: name ?? ingredient.name,
          isConfirmed: isConfirmed ?? ingredient.isConfirmed,
          notes: notes ?? ingredient.notes,
        );
      }
      return ingredient;
    }).toList();
  }

  /// Remove an ingredient
  void removeIngredient(String id) {
    state = state.where((ingredient) => ingredient.id != id).toList();
  }

  /// Toggle ingredient confirmation
  void toggleConfirmation(String id) {
    state = state.map((ingredient) {
      if (ingredient.id == id) {
        return ingredient.copyWith(isConfirmed: !ingredient.isConfirmed);
      }
      return ingredient;
    }).toList();
  }

  /// Get confirmed ingredients only
  List<DetectedIngredient> getConfirmedIngredients() {
    return state.where((ingredient) => ingredient.isConfirmed).toList();
  }

  /// Get ingredient names for recipe search
  List<String> getConfirmedIngredientNames() {
    return getConfirmedIngredients()
        .map((ingredient) => ingredient.name)
        .toList();
  }

  /// Clear all ingredients
  void clear() {
    state = [];
  }
}
