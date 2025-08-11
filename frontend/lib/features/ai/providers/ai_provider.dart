import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ai_service.dart';
import '../models/recipe_suggestion.dart';
import '../models/ingredient_substitution.dart';
import '../models/nutrition_info.dart';

// AI Service Provider
final aiServiceProvider = Provider<AIService>((ref) {
  final service = AIService.instance;
  service.initialize();
  return service;
});

// Recipe Suggestions State
class RecipeSuggestionsState {
  final List<RecipeSuggestion> suggestions;
  final bool isLoading;
  final String? error;

  const RecipeSuggestionsState({
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
  });

  RecipeSuggestionsState copyWith({
    List<RecipeSuggestion>? suggestions,
    bool? isLoading,
    String? error,
  }) {
    return RecipeSuggestionsState(
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Recipe Suggestions Provider
class RecipeSuggestionsNotifier extends StateNotifier<RecipeSuggestionsState> {
  final AIService _aiService;

  RecipeSuggestionsNotifier(this._aiService) : super(const RecipeSuggestionsState());

  Future<void> getRecipeSuggestions({
    required List<String> ingredients,
    String? cuisinePreference,
    List<String>? dietaryRestrictions,
    String? difficultyLevel,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final suggestions = await _aiService.getRecipeSuggestions(
        ingredients: ingredients,
        cuisinePreference: cuisinePreference,
        dietaryRestrictions: dietaryRestrictions,
        difficultyLevel: difficultyLevel,
      );

      state = state.copyWith(
        suggestions: suggestions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearSuggestions() {
    state = const RecipeSuggestionsState();
  }
}

final recipeSuggestionsProvider = StateNotifierProvider<RecipeSuggestionsNotifier, RecipeSuggestionsState>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return RecipeSuggestionsNotifier(aiService);
});

// Ingredient Substitutions State
class SubstitutionsState {
  final List<IngredientSubstitution> substitutions;
  final bool isLoading;
  final String? error;

  const SubstitutionsState({
    this.substitutions = const [],
    this.isLoading = false,
    this.error,
  });

  SubstitutionsState copyWith({
    List<IngredientSubstitution>? substitutions,
    bool? isLoading,
    String? error,
  }) {
    return SubstitutionsState(
      substitutions: substitutions ?? this.substitutions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// Ingredient Substitutions Provider
class SubstitutionsNotifier extends StateNotifier<SubstitutionsState> {
  final AIService _aiService;

  SubstitutionsNotifier(this._aiService) : super(const SubstitutionsState());

  Future<void> getSubstitutions({
    required String originalIngredient,
    required String recipeContext,
    List<String>? dietaryRestrictions,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final substitutions = await _aiService.getIngredientSubstitutions(
        originalIngredient: originalIngredient,
        recipeContext: recipeContext,
        dietaryRestrictions: dietaryRestrictions,
      );

      state = state.copyWith(
        substitutions: substitutions,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearSubstitutions() {
    state = const SubstitutionsState();
  }
}

final substitutionsProvider = StateNotifierProvider<SubstitutionsNotifier, SubstitutionsState>((ref) {
  final aiService = ref.watch(aiServiceProvider);
  return SubstitutionsNotifier(aiService);
});

// Cooking Tips Provider
final cookingTipsProvider = FutureProvider.family<List<String>, Map<String, String>>((ref, params) async {
  final aiService = ref.watch(aiServiceProvider);
  
  return await aiService.getCookingTips(
    recipeTitle: params['recipeTitle'] ?? '',
    cookingMethod: params['cookingMethod'] ?? '',
    difficultyLevel: params['difficultyLevel'] ?? '',
  );
});

// Nutrition Analysis Provider
final nutritionAnalysisProvider = FutureProvider.family<NutritionInfo, Map<String, dynamic>>((ref, params) async {
  final aiService = ref.watch(aiServiceProvider);
  
  return await aiService.analyzeNutrition(
    ingredients: List<Map<String, dynamic>>.from(params['ingredients'] ?? []),
    servings: params['servings'] ?? 1,
  );
});

// Improved Instructions Provider
final improvedInstructionsProvider = FutureProvider.family<List<String>, Map<String, dynamic>>((ref, params) async {
  final aiService = ref.watch(aiServiceProvider);
  
  return await aiService.improveInstructions(
    currentInstructions: List<String>.from(params['currentInstructions'] ?? []),
    recipeTitle: params['recipeTitle'] ?? '',
  );
});

// Quick Suggestions Provider
final quickSuggestionsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, ingredients) async {
  final aiService = ref.watch(aiServiceProvider);
  
  return await aiService.getQuickSuggestions(ingredients: ingredients);
});
