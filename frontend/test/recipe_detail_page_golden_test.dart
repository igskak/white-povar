import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/presentation/pages/recipe_detail_page.dart';
import 'package:frontend/features/recipes/providers/recipe_provider.dart';
import 'package:frontend/features/subscription/providers/subscription_provider.dart';

void main() {
  testWidgets('Recipe free and locked goldens at handoff breakpoints',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final state in _RecipeFixtureState.values) {
      for (final width in [390.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(_recipeApp(state));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await expectLater(
          find.byType(RecipeDetailPage),
          matchesGoldenFile(
            'goldens/recipe_${state.name}_${width.toInt()}.png',
          ),
        );
        expect(tester.takeException(), isNull,
            reason: '${state.name} at $width');
      }
    }
  }, tags: 'golden');
}

Widget _recipeApp(_RecipeFixtureState state) {
  final recipe = _recipe(isPremium: state == _RecipeFixtureState.locked);
  return ProviderScope(
    overrides: [
      recipeDetailProvider(recipe.id).overrideWith((_) async => recipe),
      isPremiumProvider.overrideWithValue(false),
      authProvider.overrideWith((_) => AuthNotifier.testing()),
    ],
    child: MaterialApp(
      theme: AppThemeV2.light(_brand),
      home: RecipeDetailPage(recipeId: recipe.id),
    ),
  );
}

enum _RecipeFixtureState { free, locked }

Recipe _recipe({required bool isPremium}) => Recipe(
      id: 'recipe-handoff',
      title: 'Капрезе 2.0 з фаршированим томатом',
      description:
          'Літня авторська страва з виразною текстурою, свіжими травами та простим ресторанним фіналом.',
      chefId: 'chef',
      cuisine: 'Італійська',
      category: 'Вечеря',
      difficulty: 2,
      prepTimeMinutes: 20,
      cookTimeMinutes: 15,
      totalTimeMinutes: 35,
      servings: 4,
      ingredients: const [
        Ingredient(
          id: 'tomatoes',
          recipeId: 'recipe-handoff',
          name: 'Стиглі томати',
          amount: 4,
          unit: 'шт.',
          order: 0,
        ),
        Ingredient(
          id: 'mozzarella',
          recipeId: 'recipe-handoff',
          name: 'Моцарела',
          amount: 200,
          unit: 'г',
          order: 1,
        ),
        Ingredient(
          id: 'basil',
          recipeId: 'recipe-handoff',
          name: 'Свіжий базилік',
          amount: 1,
          unit: 'пучок',
          order: 2,
        ),
        Ingredient(
          id: 'oil',
          recipeId: 'recipe-handoff',
          name: 'Оливкова олія',
          amount: 2,
          unit: 'ст. л.',
          order: 3,
        ),
      ],
      instructions: const [
        'Зріжте верхівки томатів і обережно вийміть серцевину.',
        'Наріжте моцарелу та змішайте її з базиліком і оливковою олією.',
        'Наповніть томати начинкою та запікайте до м’якої текстури.',
        'Дайте страві відпочити дві хвилини й подавайте теплою.',
      ],
      images: const [],
      tags: const ['seasonal', 'maisternia-oleksandra'],
      isFeatured: true,
      isPremium: isPremium,
      createdAt: DateTime(2026, 7, 19),
      updatedAt: DateTime(2026, 7, 19),
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
