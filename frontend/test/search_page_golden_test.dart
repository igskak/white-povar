import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/router/app_router.dart';
import 'package:frontend/app/router/route_models.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/branding/brand_providers.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/repositories/recipe_repository.dart';
import 'package:frontend/features/search/presentation/pages/search_page.dart';
import 'package:frontend/features/search/providers/search_provider.dart';

void main() {
  testWidgets('Search state goldens at handoff breakpoints', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final state in _SearchFixtureState.values) {
      for (final width in [390.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(_searchApp(state));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        if (state == _SearchFixtureState.filter && width < 1024) {
          // The structured facets now live behind "Усі фільтри"; this toggle
          // reveals the quick-suggestion chips.
          final filterButton = find.text('Підказки');
          expect(filterButton, findsOneWidget);
          await tester.tap(filterButton);
          await tester.pumpAndSettle();
        }

        await expectLater(
          find.byType(AdaptiveNavigationShell),
          matchesGoldenFile(
            'goldens/search_${state.name}_${width.toInt()}.png',
          ),
        );
        expect(tester.takeException(), isNull,
            reason: '${state.name} at $width');
      }
    }
  }, tags: 'golden');
}

Widget _searchApp(_SearchFixtureState state) => ProviderScope(
      overrides: [
        tenantBootstrapProvider.overrideWithValue(_bootstrap),
        authProvider.overrideWith((_) => AuthNotifier.testing()),
        recipeRepositoryProvider.overrideWithValue(
          _SearchGoldenRepository(state),
        ),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brandConfig),
        home: AdaptiveNavigationShell(
          selectedIndex: 1,
          onDestinationSelected: _ignoreDestination,
          child: SearchPage(initialRoute: _routeFor(state)),
        ),
      ),
    );

void _ignoreDestination(int _) {}

SearchRouteLocation? _routeFor(_SearchFixtureState state) => switch (state) {
      _SearchFixtureState.start => null,
      _SearchFixtureState.results =>
        const SearchRouteLocation(query: 'сезонна вечеря'),
      _SearchFixtureState.noResults =>
        const SearchRouteLocation(query: 'марсіанська страва'),
      _SearchFixtureState.filter => const SearchRouteLocation(tag: 'До 30 хв'),
    };

enum _SearchFixtureState { start, results, noResults, filter }

class _SearchGoldenRepository implements RecipeRepository {
  const _SearchGoldenRepository(this.fixtureState);

  final _SearchFixtureState fixtureState;

  @override
  Future<List<Recipe>> searchRecipes(
    String query, {
    CancelToken? cancelToken,
  }) async =>
      fixtureState == _SearchFixtureState.noResults ? const [] : _recipes;

  @override
  Future<VoiceIntentSearchResult> searchVoiceIntent(
    String transcript, {
    CancelToken? cancelToken,
  }) async =>
      VoiceIntentSearchResult(
        recipes: await searchRecipes(transcript, cancelToken: cancelToken),
        confirmationRequired: const [],
      );

  @override
  Future<Recipe> createRecipe(Recipe recipe) async => recipe;

  @override
  Future<void> deleteRecipe(String id) async {}

  @override
  Future<Recipe?> getRecipe(String id) async => _recipes.first;

  @override
  Future<List<Recipe>> getRecipes({
    String? cuisine,
    String? category,
    int? difficulty,
    int? maxTime,
    bool? isFeatured,
    int limit = 20,
    int offset = 0,
  }) async =>
      _recipes;

  @override
  Future<List<Recipe>> getRecipesByChef(
    String chefId, {
    int limit = 20,
    int offset = 0,
  }) async =>
      _recipes;

  @override
  Future<List<Recipe>> getFeaturedRecipes({int limit = 10}) async => _recipes;

  @override
  Future<Recipe> updateRecipe(Recipe recipe) async => recipe;
}

final _recipes = List.generate(
  6,
  (index) => Recipe(
    id: 'search-$index',
    title: [
      'Паста з печеними томатами',
      'Теплий салат із сезонних овочів',
      'Кремова полента з грибами',
      'Запечена цвітна капуста',
      'Різото з зеленим горошком',
      'Домашня фокача з травами',
    ][index],
    description: 'Авторський рецепт Олександра для затишної вечері.',
    chefId: 'chef',
    cuisine: index.isEven ? 'Італійська' : 'Українська',
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
    isFeatured: index == 0,
    createdAt: DateTime(2026, 7, 19),
    updatedAt: DateTime(2026, 7, 19),
  ),
);

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
  configVersion: 'search-golden',
);
