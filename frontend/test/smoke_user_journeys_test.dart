import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/camera/models/detected_ingredient.dart';
import 'package:frontend/features/camera/presentation/pages/photo_search_results_page.dart';
import 'package:frontend/features/camera/providers/photo_search_provider.dart';
import 'package:frontend/features/camera/services/photo_search_service.dart';
import 'package:frontend/features/home/presentation/pages/home_page.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/providers/recipe_provider.dart';
import 'package:frontend/features/recipes/repositories/recipe_repository.dart';
import 'package:frontend/features/recipes/services/recipe_service.dart';
import 'package:frontend/features/search/presentation/pages/search_page.dart';
import 'package:frontend/features/search/providers/search_provider.dart';

void main() {
  group('Smoke user journeys', () {
    testWidgets('Home journey: home feed renders recipe cards', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipeServiceProvider.overrideWithValue(_FakeRecipeService()),
          ],
          child: const MaterialApp(
            home: HomePage(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Сканувати інгредієнти'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Test Pasta'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Test Pasta'), findsOneWidget);
    });

    testWidgets('Search journey: typing query shows search results', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recipeRepositoryProvider.overrideWithValue(_FakeRecipeRepository()),
          ],
          child: const MaterialApp(
            home: SearchPage(),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'pasta');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Нічого не знайшли'), findsOneWidget);
    });

    testWidgets('Camera journey: results screen renders recipe matches', (
      WidgetTester tester,
    ) async {
      final ingredientNotifier = IngredientEditNotifier()
        ..setIngredients(const [
          DetectedIngredient(
            id: 'ing-1',
            name: 'tomato',
            confidence: 0.9,
            isConfirmed: true,
          ),
        ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            photoSearchProvider.overrideWith(
              (ref) => _FakePhotoSearchNotifier(),
            ),
            ingredientEditProvider.overrideWith((ref) => ingredientNotifier),
          ],
          child: const MaterialApp(
            home: PhotoSearchResultsPage(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Рецепти не знайдено'), findsOneWidget);
    });
  });
}

class _FakeRecipeService implements RecipeService {
  @override
  Future<Recipe> createRecipe(Recipe recipe) async => recipe;

  @override
  Future<void> deleteRecipe(String id) async {}

  @override
  Future<List<Recipe>> getRecipes() async {
    return [_testRecipe(id: 'home-1', title: 'Test Pasta')];
  }

  @override
  Future<Recipe> getRecipe(String id) async {
    return _testRecipe(id: id, title: 'Recipe Detail');
  }

  @override
  Future<List<Recipe>> getFavoriteRecipes() async {
    return [_testRecipe(id: 'fav-1', title: 'Favorite')];
  }

  @override
  Future<List<Recipe>> getFeaturedRecipes() async {
    return [_testRecipe(id: 'home-2', title: 'Featured Pasta')];
  }

  @override
  Future<List<Recipe>> searchRecipes(
    String query, {
    CancelToken? cancelToken,
  }) async {
    return [];
  }

  @override
  Future<void> toggleFavorite(String recipeId) async {}

  @override
  Future<Recipe> updateRecipe(String id, Recipe recipe) async => recipe;
}

class _FakeRecipeRepository implements RecipeRepository {
  @override
  Future<Recipe> createRecipe(Recipe recipe) async => recipe;

  @override
  Future<void> deleteRecipe(String id) async {}

  @override
  Future<Recipe?> getRecipe(String id) async => _testRecipe(id: id);

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
    return [_testRecipe(id: 'repo-1', title: 'Repository Pasta')];
  }

  @override
  Future<List<Recipe>> getRecipesByChef(
    String chefId, {
    int limit = 20,
    int offset = 0,
  }) async {
    return [_testRecipe(id: 'repo-2', title: 'Chef Pasta')];
  }

  @override
  Future<List<Recipe>> getFeaturedRecipes({int limit = 10}) async {
    return [_testRecipe(id: 'repo-3', title: 'Featured Repo Pasta')];
  }

  @override
  Future<List<Recipe>> searchRecipes(
    String query, {
    CancelToken? cancelToken,
  }) async {
    return [];
  }

  @override
  Future<Recipe> updateRecipe(Recipe recipe) async => recipe;
}

class _FakePhotoSearchNotifier extends PhotoSearchNotifier {
  _FakePhotoSearchNotifier()
      : super(
          photoSearchService: PhotoSearchService(
            apiClient: ApiClient(
              baseUrl: 'https://example.com',
              tenantSlug: 'ohorodnik-oleksandr',
              locale: 'uk',
              tokenProvider: () async => null,
            ),
          ),
        ) {
    state = const PhotoSearchState(
      suggestedRecipes: [],
      detectedIngredients: [
        DetectedIngredient(
          id: 'ing-1',
          name: 'tomato',
          confidence: 0.9,
          isConfirmed: true,
        ),
      ],
    );
  }
}

Recipe _testRecipe({
  required String id,
  String title = 'Recipe',
}) {
  final now = DateTime(2025, 1, 1);
  return Recipe(
    id: id,
    title: title,
    description: 'Quick pasta for smoke test',
    chefId: 'chef-1',
    cuisine: 'Italian',
    category: 'Main',
    difficulty: 1,
    prepTimeMinutes: 5,
    cookTimeMinutes: 10,
    totalTimeMinutes: 15,
    servings: 2,
    ingredients: const [
      Ingredient(
        id: 'i-1',
        recipeId: 'r-1',
        name: 'Pasta',
        amount: 200,
        unit: 'g',
        order: 1,
      ),
    ],
    instructions: const ['Boil water', 'Cook pasta'],
    images: const [],
    tags: const ['quick'],
    isFeatured: false,
    createdAt: now,
    updatedAt: now,
  );
}
