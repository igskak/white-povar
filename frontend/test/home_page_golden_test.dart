import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/router/app_router.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/branding/brand_providers.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/collections/providers/collection_provider.dart';
import 'package:frontend/features/home/presentation/pages/home_page.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/providers/recipe_provider.dart';
import 'package:frontend/features/recipes/repositories/recipe_repository.dart';
import 'package:frontend/features/recipes/services/recipe_service.dart';
import 'package:frontend/features/subscription/providers/subscription_provider.dart';

void main() {
  testWidgets('Home state goldens at handoff breakpoints', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final state in _HomeFixtureState.values) {
      for (final width in [390.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(_homeApp(state));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));

        await expectLater(
          find.byType(AdaptiveNavigationShell),
          matchesGoldenFile(
            'goldens/home_${state.name}_${width.toInt()}.png',
          ),
        );
        expect(tester.takeException(), isNull,
            reason: '${state.name} at $width');
      }
    }
  }, tags: 'golden');
}

Widget _homeApp(_HomeFixtureState state) => ProviderScope(
      overrides: [
        tenantBootstrapProvider.overrideWithValue(_bootstrap),
        authProvider.overrideWith((_) => AuthNotifier.testing()),
        isPremiumProvider.overrideWithValue(false),
        recipeServiceProvider.overrideWithValue(_HomeRecipeService(state)),
        collectionListProvider.overrideWith((_) async => const []),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brandConfig),
        home: const AdaptiveNavigationShell(
          selectedIndex: 0,
          onDestinationSelected: _ignoreDestination,
          child: HomePage(),
        ),
      ),
    );

void _ignoreDestination(int _) {}

enum _HomeFixtureState { data, loading, empty, error }

class _HomeRecipeService extends RecipeService {
  _HomeRecipeService(this.fixtureState)
      : super(ApiClient(
          baseUrl: 'https://example.invalid',
          tokenProvider: () async => null,
          tenantSlug: 'ohorodnik-oleksandr',
          locale: 'uk',
        ));

  final _HomeFixtureState fixtureState;
  final Completer<List<Recipe>> _loading = Completer<List<Recipe>>();

  @override
  Future<List<Recipe>> getRecipes({
    String? cuisine,
    String? category,
    int? difficulty,
    int? maxTime,
    bool? isFeatured,
    int limit = 20,
    int offset = 0,
  }) {
    return switch (fixtureState) {
      _HomeFixtureState.data => Future.value(_recipes),
      _HomeFixtureState.loading => _loading.future,
      _HomeFixtureState.empty => Future.value(const []),
      _HomeFixtureState.error => Future.error(StateError('offline')),
    };
  }

  @override
  Future<Recipe> getRecipe(String id) async => _recipes.first;

  @override
  Future<List<Recipe>> getFeaturedRecipes() async => [_recipes.first];

  @override
  Future<List<Recipe>> getFavoriteRecipes() async => const [];

  @override
  Future<bool> setFavorite(String recipeId, bool isFavorite) async =>
      isFavorite;

  @override
  Future<void> toggleFavorite(String recipeId) async {}

  @override
  Future<void> recordHistory(String recipeId, String event) async {}

  @override
  Future<Recipe> createRecipe(Recipe recipe) async => recipe;

  @override
  Future<Recipe> updateRecipe(String id, Recipe recipe) async => recipe;

  @override
  Future<void> deleteRecipe(String id) async {}

  @override
  Future<List<Recipe>> searchRecipes(
    String query, {
    CancelToken? cancelToken,
  }) async =>
      const [];

  @override
  Future<VoiceIntentSearchResult> searchVoiceIntent(
    String transcript, {
    CancelToken? cancelToken,
  }) async =>
      const VoiceIntentSearchResult(
        recipes: [],
        confirmationRequired: [],
      );

  @override
  Future<Map<String, dynamic>> getSearchFilterOptions() async => const {};
}

final _recipes = List.generate(5, (index) {
  final featured = index == 0;
  return Recipe(
    id: 'home-$index',
    title: featured
        ? 'Капрезе 2.0 з фаршированим томатом'
        : 'Авторський рецепт ${index + 1}',
    description:
        'Сезонна страва від Олександра з простими кроками та чесним смаком.',
    chefId: 'chef',
    cuisine: index.isEven ? 'Українська' : 'Італійська',
    category: 'Вечеря',
    difficulty: 2,
    prepTimeMinutes: 10,
    cookTimeMinutes: 20,
    totalTimeMinutes: 30,
    servings: 4,
    ingredients: const [],
    instructions: const ['Підготуйте продукти.', 'Завершіть страву.'],
    images: const [],
    tags: const ['seasonal'],
    isFeatured: featured,
    createdAt: DateTime(2026, 7, 19),
    updatedAt: DateTime(2026, 7, 19),
  );
});

const _brandConfig = BrandConfig(
  schemaVersion: 1,
  tenantSlug: 'ohorodnik-oleksandr',
  locale: 'uk',
  brand: BrandDetails(
    name: 'Огороднік Олександр',
    creatorName: 'Олександр',
    avatar: 'PENDING:/avatar.png',
    accent: '#5D7183',
    font: 'grotesque',
    voice: BrandVoice(
      greeting: 'Ой, друзі, ну це щось...',
      loginTitle: 'Готуйте з Олександром',
      paywallTitle: 'Колекції Олександра',
      courseName: 'Майстерня Олександра',
    ),
    derived: DerivedBrandColors(
      accentPressed: '#4B5E70',
      accentOnDark: '#6B8092',
      onAccent: '#FFFFFF',
      lightCtaMode: 'accentFill',
    ),
    heroPhotos: [],
    courseTag: 'maisternia-oleksandra',
  ),
);

const _bootstrap = TenantBootstrap(
  tenantSlug: 'ohorodnik-oleksandr',
  brandConfig: _brandConfig,
  configVersion: 'home-golden',
);
