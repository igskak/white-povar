import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/app/theme/tokens/app_tokens.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/presentation/pages/recipe_detail_page.dart';
import 'package:frontend/features/recipes/providers/recipe_provider.dart';
import 'package:frontend/features/subscription/providers/subscription_provider.dart';

void main() {
  group('UI-05 recipe detail', () {
    testWidgets('does not build protected payload for a locked premium recipe',
        (tester) async {
      await tester.pumpWidget(_app(recipe: _recipe(isPremium: true)));
      await tester.pump();

      expect(find.text('Рецепт від шефа — у Premium'), findsOneWidget);
      expect(find.text('Секретний інгредієнт'), findsNothing);
      expect(find.text('Не показувати цей крок'), findsNothing);
      expect(find.text('Почати готувати'), findsNothing);
    });

    testWidgets('renders recipe sections for a user with premium access',
        (tester) async {
      await tester.pumpWidget(_app(
        recipe: _recipe(isPremium: true),
        hasPremiumAccess: true,
      ));
      await tester.pump();

      expect(find.text('Секретний інгредієнт'), findsOneWidget);
      expect(find.text('Не показувати цей крок'), findsOneWidget);
      expect(find.text('Почати готувати'), findsOneWidget);
    });

    testWidgets('has no overflow at mobile, tablet and desktop widths',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [390.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(_app(
          recipe: _recipe(isPremium: false),
          hasPremiumAccess: true,
        ));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'width: $width');
      }
    });

    testWidgets('desktop has 4:3 hero, two-column body and in-header actions',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(
        recipe: _recipe(isPremium: false),
        hasPremiumAccess: true,
      ));
      await tester.pump();

      final heroSize = tester
          .getSize(find.byKey(const ValueKey('desktop-recipe-hero-pane')));
      expect(heroSize.aspectRatio, closeTo(4 / 3, .01));
      expect(heroSize.width, greaterThan(500));
      expect(find.byKey(const ValueKey('recipe-sections-two-column')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('desktop-recipe-actions')), findsOneWidget);
      expect(find.byTooltip('Поділитися'), findsOneWidget);
      expect(find.text('Почати готувати'), findsOneWidget);
    });

    testWidgets('the page column tracks the window instead of a fixed cap',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;

      final heroWidths = <double, double>{};
      for (final width in [1280.0, 1920.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(_app(
          recipe: _recipe(isPremium: false),
          hasPremiumAccess: true,
        ));
        await tester.pump();
        heroWidths[width] = tester
            .getSize(find.byKey(const ValueKey('desktop-recipe-hero-pane')))
            .width;
      }

      expect(heroWidths[1920], greaterThan(heroWidths[1280]!));
    });

    testWidgets('the steps column stays inside a readable line length',
        (tester) async {
      tester.view.physicalSize = const Size(2560, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(
        recipe: _recipe(isPremium: false),
        hasPremiumAccess: true,
      ));
      await tester.pump();

      final steps = tester.getSize(find.text('Приготування'));
      expect(steps.width, lessThanOrEqualTo(AppLayout.narrowMax));
    });
  });
}

Widget _app({required Recipe recipe, bool hasPremiumAccess = false}) =>
    ProviderScope(
      overrides: [
        recipeDetailProvider(recipe.id).overrideWith((_) async => recipe),
        isPremiumProvider.overrideWithValue(hasPremiumAccess),
        authProvider.overrideWith(
          (ref) => AuthNotifier.testing(),
        ),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brand),
        home: RecipeDetailPage(recipeId: recipe.id),
      ),
    );

Recipe _recipe({required bool isPremium}) => Recipe(
      id: 'recipe-1',
      title: 'Тестовий рецепт',
      description: 'Опис рецепта',
      chefId: 'chef',
      cuisine: 'Українська',
      category: 'Вечеря',
      difficulty: 2,
      prepTimeMinutes: 5,
      cookTimeMinutes: 10,
      totalTimeMinutes: 15,
      servings: 2,
      ingredients: const [
        Ingredient(
          id: 'ingredient',
          recipeId: 'recipe-1',
          name: 'Секретний інгредієнт',
          amount: 1,
          unit: 'шт.',
          order: 0,
        ),
      ],
      instructions: const ['Не показувати цей крок'],
      images: const [],
      tags: const [],
      isFeatured: false,
      isPremium: isPremium,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

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
      loginTitle: 'Готуйте',
      paywallTitle: 'Колекції',
    ),
    derived: DerivedBrandColors(
      accentPressed: '#4B5E70',
      accentOnDark: '#6B8092',
      onAccent: '#FFFFFF',
      lightCtaMode: 'accentFill',
    ),
    heroPhotos: [],
  ),
);
