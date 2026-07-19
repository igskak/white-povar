import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/app/router/app_router.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/branding/brand_providers.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/providers/recipe_provider.dart';
import 'package:frontend/features/recipes/repositories/recipe_repository.dart';
import 'package:frontend/features/recipes/services/recipe_service.dart';
import 'package:frontend/features/saved/presentation/pages/saved_page.dart';

void main() {
  testWidgets('Saved state goldens at handoff breakpoints', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final state in _SavedFixtureState.values) {
      for (final width in [390.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(
          _savedApp(state, fixtureKey: '${state.name}-$width'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await expectLater(
          find.byType(AdaptiveNavigationShell),
          matchesGoldenFile(
            'goldens/saved_${state.name}_${width.toInt()}.png',
          ),
        );
        expect(tester.takeException(), isNull,
            reason: '${state.name} at $width');
      }
    }
  }, tags: 'golden');
}

Widget _savedApp(
  _SavedFixtureState state, {
  required String fixtureKey,
}) =>
    ProviderScope(
      key: ValueKey(fixtureKey),
      overrides: [
        tenantBootstrapProvider.overrideWithValue(_bootstrap),
        currentUserProvider.overrideWithValue(
          state == _SavedFixtureState.guest ? null : _user,
        ),
        favoriteRecipesProvider.overrideWith(
          (_) async =>
              state == _SavedFixtureState.populated ? _recipes : const [],
        ),
        favoriteIdsProvider.overrideWith(
          (ref) => FavoriteNotifier(_recipeService, ref),
        ),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brand),
        home: const AdaptiveNavigationShell(
          selectedIndex: 2,
          onDestinationSelected: _ignoreDestination,
          child: SavedPage(embeddedInDesktopShell: true),
        ),
      ),
    );

void _ignoreDestination(int _) {}

enum _SavedFixtureState { populated, empty, guest }

const _user = User(
  id: 'saved-user',
  email: 'cook@example.com',
  appMetadata: {},
  userMetadata: {'full_name': 'Олена'},
  aud: 'authenticated',
  createdAt: '2026-07-15T00:00:00Z',
);

final _recipes = List.generate(
  6,
  (index) => Recipe(
    id: 'saved-$index',
    title: [
      'Капрезе 2.0',
      'Томатний тарт',
      'Паста з моцарелою',
      'Теплий салат',
      'Фокача з травами',
      'Запечені овочі',
    ][index],
    description: 'Збережений авторський рецепт для затишної вечері.',
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
    tags: const ['saved'],
    isFeatured: index == 0,
    createdAt: DateTime(2026, 7, 19),
    updatedAt: DateTime(2026, 7, 19),
  ),
);

final _recipeService = _SavedRecipeService();

class _SavedRecipeService extends RecipeService {
  _SavedRecipeService()
      : super(ApiClient(
          baseUrl: 'https://example.invalid',
          tokenProvider: () async => null,
          tenantSlug: 'ohorodnik-oleksandr',
          locale: 'uk',
        ));

  @override
  Future<List<Recipe>> getFavoriteRecipes() async => _recipes;

  @override
  Future<bool> setFavorite(String recipeId, bool isFavorite) async =>
      isFavorite;

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
}

const _brand = BrandConfig(
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
  brandConfig: _brand,
  configVersion: 'saved-golden',
);
