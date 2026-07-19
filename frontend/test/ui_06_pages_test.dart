import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/branding/brand_providers.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/profile/presentation/pages/profile_page.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/providers/recipe_provider.dart';
import 'package:frontend/features/recipes/services/recipe_service.dart';
import 'package:frontend/features/saved/presentation/pages/saved_page.dart';
import 'package:frontend/features/studio/studio_brand_draft_service.dart';
import 'package:frontend/features/subscription/providers/subscription_provider.dart';

void main() {
  testWidgets('saved guest CTA preserves saved as the login return path',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/saved',
      routes: [
        GoRoute(path: '/saved', builder: (_, __) => const SavedPage()),
        GoRoute(
          path: '/login',
          builder: (_, state) => Text(state.uri.queryParameters['returnTo']!),
        ),
      ],
    );
    await tester.pumpWidget(_app(router));

    await tester.tap(find.text('Увійти, щоб зберігати'));
    await tester.pumpAndSettle();

    expect(find.text('/saved'), findsOneWidget);
  });

  testWidgets('saved desktop uses global header and a three-column grid',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const user = User(
      id: 'user-1',
      email: 'cook@example.com',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: '2026-07-15T00:00:00Z',
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tenantBootstrapProvider.overrideWithValue(_bootstrap),
        currentUserProvider.overrideWithValue(user),
        favoriteRecipesProvider.overrideWith(
          (ref) async => List.generate(4, _recipe),
        ),
        favoriteIdsProvider.overrideWith(
          (ref) => FavoriteNotifier(
            RecipeService(ApiClient(
              baseUrl: 'https://example.invalid',
              tokenProvider: () async => null,
              tenantSlug: 'ohorodnik-oleksandr',
              locale: 'uk',
            )),
            ref,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brand),
        home: const SavedPage(embeddedInDesktopShell: true),
      ),
    ));
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    final grid = tester.widget<SliverGrid>(
      find.byKey(const ValueKey('saved-recipes-grid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 3);
  });

  testWidgets('profile guest uses a user glyph instead of a brand avatar',
      (tester) async {
    await tester.pumpWidget(_app(GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        GoRoute(path: '/login', builder: (_, __) => const SizedBox()),
      ],
    )));

    expect(find.byIcon(Icons.person_outline), findsWidgets);
    expect(find.text('Зробіть кухню своєю'), findsOneWidget);
  });

  testWidgets('profile guest adapts at design breakpoints', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [390.0, 768.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_app(_profileRouter()));
      expect(find.text('Зробіть кухню своєю'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width: $width');
    }
  });

  testWidgets('desktop profile relies on global shell header and shows access',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const user = User(
      id: 'user-1',
      email: 'cook@example.com',
      appMetadata: {},
      userMetadata: {'full_name': 'Cook'},
      aud: 'authenticated',
      createdAt: '2026-07-15T00:00:00Z',
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(user),
        isPremiumProvider.overrideWithValue(true),
        studioSessionProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brand),
        home: const ProfilePage(embeddedInDesktopShell: true),
      ),
    ));
    await tester.pump();

    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Premium активна'), findsOneWidget);
    expect(find.text('Premium доступ активний'), findsOneWidget);
  });

  testWidgets('profile guest goldens at design breakpoints', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [390.0, 768.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_app(_profileRouter()));
      await expectLater(
        find.byType(ProfilePage),
        matchesGoldenFile('goldens/profile_guest_${width.toInt()}.png'),
      );
    }
  }, tags: 'golden');
}

GoRouter _profileRouter() => GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        GoRoute(path: '/login', builder: (_, __) => const SizedBox()),
      ],
    );

Widget _app(GoRouter router) => ProviderScope(
      overrides: [currentUserProvider.overrideWithValue(null)],
      child: MaterialApp.router(
        theme: AppThemeV2.light(_brand),
        routerConfig: router,
      ),
    );

final _brand = BrandConfig.fromJson({
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
    'derived': {
      'accentPressed': '#4B5E70',
      'accentOnDark': '#6B8092',
      'onAccent': '#FFFFFF',
      'lightCtaMode': 'accentFill',
    },
  },
});

final _bootstrap = TenantBootstrap(
  tenantSlug: 'ohorodnik-oleksandr',
  brandConfig: _brand,
  configVersion: 'test',
);

Recipe _recipe(int index) => Recipe(
      id: 'recipe-$index',
      title: 'Рецепт $index',
      description: 'Опис рецепта',
      chefId: 'chef-1',
      cuisine: 'Українська',
      category: 'Вечеря',
      difficulty: 1,
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      totalTimeMinutes: 30,
      servings: 2,
      ingredients: const [],
      instructions: const [],
      images: const [],
      tags: const [],
      isFeatured: false,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
