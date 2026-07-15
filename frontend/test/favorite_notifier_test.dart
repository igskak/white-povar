import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/providers/recipe_provider.dart';
import 'package:frontend/features/recipes/services/recipe_service.dart';

void main() {
  test('rapid save then unsave serializes desired server states', () async {
    final service = _FavoriteService();
    final container = ProviderContainer(
      overrides: [
        recipeServiceProvider.overrideWithValue(service),
        authProvider.overrideWith((ref) => AuthNotifier.testing()),
      ],
    );
    addTearDown(container.dispose);
    final favorites = container.read(favoriteIdsProvider.notifier);

    final save = favorites.setFavorite('recipe-1', true);
    final unsave = favorites.setFavorite('recipe-1', false);
    await Future.wait([save, unsave]);

    expect(service.requests, [true, false]);
    expect(container.read(favoriteIdsProvider), isEmpty);
  });

  test('guest save intent is applied after authentication', () async {
    final service = _FavoriteService();
    final container = ProviderContainer(
      overrides: [
        recipeServiceProvider.overrideWithValue(service),
        authProvider.overrideWith((ref) => AuthNotifier.testing()),
      ],
    );
    addTearDown(container.dispose);
    final favorites = container.read(favoriteIdsProvider.notifier)
      ..queueGuestIntent('recipe-1');

    await favorites.onAuthenticated();

    expect(service.requests, [true]);
    expect(container.read(favoriteIdsProvider), {'recipe-1'});
  });
}

class _FavoriteService implements RecipeService {
  final requests = <bool>[];

  @override
  Future<bool> setFavorite(String recipeId, bool isFavorite) async {
    requests.add(isFavorite);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    return isFavorite;
  }

  @override
  Future<Recipe> createRecipe(Recipe recipe) async => recipe;
  @override
  Future<void> deleteRecipe(String id) async {}
  @override
  Future<List<Recipe>> getFavoriteRecipes() async => [];
  @override
  Future<List<Recipe>> getFeaturedRecipes() async => [];
  @override
  Future<Recipe> getRecipe(String id) => throw UnimplementedError();
  @override
  Future<List<Recipe>> getRecipes() async => [];
  @override
  Future<List<Recipe>> searchRecipes(String query,
          {CancelToken? cancelToken}) async =>
      [];
  @override
  Future<void> toggleFavorite(String recipeId) async {}
  @override
  Future<Recipe> updateRecipe(String id, Recipe recipe) async => recipe;
}
