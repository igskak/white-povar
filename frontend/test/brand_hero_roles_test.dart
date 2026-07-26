import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/branding/brand_providers.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/collections/models/collection.dart';
import 'package:frontend/features/collections/presentation/pages/collection_list_page.dart';
import 'package:frontend/features/collections/providers/collection_provider.dart';
import 'package:frontend/features/home/presentation/pages/home_page.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/providers/recipe_provider.dart';
import 'package:frontend/features/recipes/services/recipe_service.dart';
import 'package:frontend/features/subscription/providers/subscription_provider.dart';

const _homeHero = ValueKey('home-brand-hero');
const _collectionsHero = ValueKey('collections-brand-hero');

void main() {
  testWidgets('Home shows the published home photo at every breakpoint',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    // Mobile and desktop Home are separate layouts; both must honour the role.
    for (final width in [390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(
        _homeApp(_brand(heroRoles: const ['home']), key: ValueKey(width)),
      );
      await _settleFeed(tester);

      expect(find.byKey(_homeHero), findsOneWidget, reason: 'width: $width');
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('Home keeps its plain layout when no home photo is published',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final width in [390.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 1000);
      // A photo published for another role must not leak onto Home.
      await tester.pumpWidget(
        _homeApp(_brand(heroRoles: const ['paywall']), key: ValueKey(width)),
      );
      await _settleFeed(tester);

      // Guard against a false pass from a Home that never finished loading.
      expect(find.text(_recipe.title), findsWidgets, reason: 'width: $width');
      expect(find.byKey(_homeHero), findsNothing, reason: 'width: $width');
    }
  });

  testWidgets('the collection index shows the published collection photo',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester
        .pumpWidget(_collectionApp(_brand(heroRoles: const ['collection'])));
    await tester.pump();

    expect(find.byKey(_collectionsHero), findsOneWidget);
    expect(find.text('Колекції'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the collection index omits the banner when none is published',
      (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_collectionApp(_brand(heroRoles: const ['home'])));
    await tester.pump();

    expect(find.byKey(_collectionsHero), findsNothing);
    expect(find.text('Колекції'), findsWidgets);
  });

  test('heroFor returns only a photo carrying the requested role', () {
    final brand =
        _brand(heroRoles: const ['home', 'paywall']).brandConfig.brand;

    expect(brand.heroFor('home')?.url, 'https://cdn.example.com/hero.webp');
    expect(brand.heroFor('paywall'), isNotNull);
    expect(brand.heroFor('collection'), isNull);
    expect(brand.heroFor('login'), isNull);
  });
}

/// Home loads its feed in a post-frame callback; desktop only builds its column
/// once that future resolves.
Future<void> _settleFeed(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
}

/// [key] forces a fresh [HomePage] state per breakpoint: without it Flutter
/// reuses the element across `pumpWidget` calls, `initState` never re-runs and
/// the feed stays in its loading state for the second layout.
Widget _homeApp(TenantBootstrap bootstrap, {Key? key}) => ProviderScope(
      key: key,
      overrides: [
        tenantBootstrapProvider.overrideWithValue(bootstrap),
        authProvider.overrideWith((_) => AuthNotifier.testing()),
        isPremiumProvider.overrideWithValue(false),
        recipeServiceProvider.overrideWithValue(_StubRecipeService()),
        collectionListProvider.overrideWith((_) async => const []),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(bootstrap.brandConfig),
        home: const HomePage(),
      ),
    );

Widget _collectionApp(TenantBootstrap bootstrap) => ProviderScope(
      overrides: [
        tenantBootstrapProvider.overrideWithValue(bootstrap),
        collectionListProvider.overrideWith((_) async => _collections),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(bootstrap.brandConfig),
        home: const CollectionListPage(),
      ),
    );

final _collections = [
  const ContentCollection(
    id: 'collection-0',
    slug: 'collection-0',
    title: 'Колекція 1',
    description: 'Авторська добірка',
    itemCount: 8,
  ),
];

class _StubRecipeService extends RecipeService {
  _StubRecipeService()
      : super(ApiClient(
          baseUrl: 'https://example.invalid',
          tokenProvider: () async => null,
          tenantSlug: 'ohorodnik-oleksandr',
          locale: 'uk',
        ));

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
      [_recipe];

  @override
  Future<List<Recipe>> getFeaturedRecipes() async => [_recipe];

  @override
  Future<void> recordHistory(String recipeId, String event) async {}
}

final _recipe = Recipe(
  id: 'recipe-1',
  title: 'Лосось із зеленою сальсою',
  description: 'Приклад картки рецепта.',
  chefId: 'chef-1',
  cuisine: 'Вечеря',
  category: 'Основні страви',
  difficulty: 2,
  prepTimeMinutes: 10,
  cookTimeMinutes: 20,
  totalTimeMinutes: 30,
  servings: 2,
  ingredients: const [],
  instructions: const [],
  images: const [],
  tags: const [],
  isFeatured: true,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

TenantBootstrap _brand({required List<String> heroRoles}) => TenantBootstrap(
      tenantSlug: 'ohorodnik-oleksandr',
      configVersion: 'test',
      brandConfig: BrandConfig.fromJson({
        'schemaVersion': 1,
        'tenantSlug': 'ohorodnik-oleksandr',
        'locale': 'uk',
        'brand': {
          'name': 'Огороднік Олександр',
          'creatorName': 'Олександр',
          'avatar': 'PENDING:/avatar.png',
          'accent': '#5D7183',
          'font': 'grotesque',
          'voice': {
            'greeting': 'Вітаю',
            'loginTitle': 'Вхід',
            'paywallTitle': 'Premium',
          },
          'heroPhotos': [
            {
              'url': 'https://cdn.example.com/hero.webp',
              'roles': heroRoles,
              'focal': {'x': 0.5, 'y': 0.4},
            },
          ],
          'derived': {
            'accentPressed': '#4B5E70',
            'accentOnDark': '#6B8092',
            'onAccent': '#FFFFFF',
            'lightCtaMode': 'accentFill',
          },
        },
      }),
    );
