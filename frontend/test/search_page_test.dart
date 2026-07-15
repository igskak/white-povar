import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/router/route_models.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/repositories/recipe_repository.dart';
import 'package:frontend/features/search/presentation/pages/search_page.dart';
import 'package:frontend/features/search/providers/search_provider.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('UI-04 search discovery', () {
    testWidgets('tag deep link searches the canonical tag directly',
        (tester) async {
      final repository = _SearchRepository();
      await tester.pumpWidget(_testApp(
        repository: repository,
        initialRoute: const SearchRouteLocation(tag: 'maisternia-oleksandra'),
      ));

      await tester.pump(const Duration(milliseconds: 300));

      expect(repository.queries, ['maisternia-oleksandra']);
      expect(find.text('Тег: maisternia-oleksandra'), findsOneWidget);
    });

    testWidgets('query changes are serialized into the web route',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/search',
        routes: [
          GoRoute(
            path: '/search',
            builder: (_, state) => ProviderScope(
              overrides: [
                recipeRepositoryProvider.overrideWithValue(_SearchRepository()),
                authProvider.overrideWith((ref) => AuthNotifier.testing()),
              ],
              child: SearchPage(
                initialRoute: SearchRouteLocation.fromUri(state.uri),
              ),
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(
        theme: AppThemeV2.light(_brandConfig),
        routerConfig: router,
      ));

      await tester.enterText(find.byType(TextField), 'борщ');
      await tester.pump();

      expect(router.routeInformationProvider.value.uri.toString(),
          '/search?q=%D0%B1%D0%BE%D1%80%D1%89');
    });

    testWidgets('result layouts have no exceptions at 390, 768 and 1280',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [390.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(_testApp(repository: _SearchRepository()));
        await tester.enterText(find.byType(TextField), 'паста');
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'width: $width');
      }
    });

    test('debounce and cancellation never publish stale results', () async {
      final repository = _DeferredSearchRepository();
      final container = ProviderContainer(overrides: [
        recipeRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);
      final notifier = container.read(simpleTextSearchProvider.notifier);

      notifier.searchRecipes('перший');
      await Future<void>.delayed(const Duration(milliseconds: 260));
      notifier.searchRecipes('другий');
      await Future<void>.delayed(const Duration(milliseconds: 260));
      repository.complete('перший', [_recipe('stale')]);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(simpleTextSearchProvider).query, 'другий');
      expect(container.read(simpleTextSearchProvider).results, isEmpty);

      repository.complete('другий', [_recipe('fresh')]);
      await Future<void>.delayed(Duration.zero);
      expect(
          container.read(simpleTextSearchProvider).results.single.id, 'fresh');
    });
  });
}

Widget _testApp({
  required RecipeRepository repository,
  SearchRouteLocation? initialRoute,
}) =>
    ProviderScope(
      overrides: [
        recipeRepositoryProvider.overrideWithValue(repository),
        authProvider.overrideWith((ref) => AuthNotifier.testing()),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brandConfig),
        home: SearchPage(initialRoute: initialRoute),
      ),
    );

class _SearchRepository extends _RepositoryBase {
  final List<String> queries = [];

  @override
  Future<List<Recipe>> searchRecipes(String query,
      {CancelToken? cancelToken}) async {
    queries.add(query);
    return [_recipe('search-$query')];
  }
}

class _DeferredSearchRepository extends _RepositoryBase {
  final Map<String, Completer<List<Recipe>>> _requests = {};

  @override
  Future<List<Recipe>> searchRecipes(String query,
          {CancelToken? cancelToken}) =>
      (_requests[query] ??= Completer<List<Recipe>>()).future;

  void complete(String query, List<Recipe> recipes) =>
      _requests[query]!.complete(recipes);
}

abstract class _RepositoryBase implements RecipeRepository {
  @override
  Future<Recipe> createRecipe(Recipe recipe) async => recipe;
  @override
  Future<void> deleteRecipe(String id) async {}
  @override
  Future<Recipe?> getRecipe(String id) async => _recipe(id);
  @override
  Future<List<Recipe>> getRecipes(
          {String? cuisine,
          String? category,
          int? difficulty,
          int? maxTime,
          bool? isFeatured,
          int limit = 20,
          int offset = 0}) async =>
      [_recipe('all')];
  @override
  Future<List<Recipe>> getRecipesByChef(String chefId,
          {int limit = 20, int offset = 0}) async =>
      [_recipe('chef')];
  @override
  Future<List<Recipe>> getFeaturedRecipes({int limit = 10}) async =>
      [_recipe('featured')];
  @override
  Future<Recipe> updateRecipe(Recipe recipe) async => recipe;
}

Recipe _recipe(String id) => Recipe(
      id: id,
      title: 'Тестова паста',
      description: 'Швидка вечеря',
      chefId: 'chef',
      cuisine: 'Українська',
      category: 'Вечеря',
      difficulty: 1,
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      totalTimeMinutes: 15,
      servings: 2,
      ingredients: const [],
      instructions: const [],
      images: const [],
      tags: const ['maisternia-oleksandra'],
      isFeatured: false,
      isPremium: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
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
      greeting: 'Ой, друзі',
      loginTitle: 'Готуйте',
      paywallTitle: 'Колекції',
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
