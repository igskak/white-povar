import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/presentation/pages/cooking_mode_page.dart';
import 'package:frontend/features/recipes/providers/recipe_provider.dart';
import 'package:frontend/features/subscription/providers/subscription_provider.dart';

void main() {
  testWidgets('desktop cooking supports arrow-key step navigation',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        recipeDetailProvider(_recipe.id).overrideWith((_) async => _recipe),
        authProvider.overrideWith((_) => AuthNotifier.testing()),
        isPremiumProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        theme: AppThemeV2.dark(_brand),
        home: const CookingModePage(recipeId: 'cook-1'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('КРОК 1'), findsOneWidget);
    expect(find.text('← / → для навігації'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('desktop-cooking-layout')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-cooking-step-list')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-cooking-active-step')),
        findsOneWidget);
    expect(FocusManager.instance.primaryFocus, isNotNull);
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('cooking-step-1')))
          .enabled,
      isFalse,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(find.text('КРОК 2'), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('cooking-step-0')))
          .enabled,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('unfinished cooking asks for confirmation from the first step',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        recipeDetailProvider(_recipe.id).overrideWith((_) async => _recipe),
        authProvider.overrideWith((_) => AuthNotifier.testing()),
        isPremiumProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        theme: AppThemeV2.dark(_brand),
        home: const CookingModePage(recipeId: 'cook-1'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Вийти з режиму готування'));
    await tester.pumpAndSettle();

    expect(find.text('Завершити приготування?'), findsOneWidget);
    expect(find.text('Залишитись'), findsOneWidget);
  });
}

final _recipe = Recipe(
  id: 'cook-1',
  title: 'Тестове приготування',
  description: 'Опис',
  chefId: 'chef',
  cuisine: 'Українська',
  category: 'Вечеря',
  difficulty: 1,
  prepTimeMinutes: 5,
  cookTimeMinutes: 10,
  totalTimeMinutes: 15,
  servings: 2,
  ingredients: const [],
  instructions: const ['Перший крок', 'Другий крок'],
  images: const [],
  tags: const [],
  isFeatured: false,
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
      greeting: 'Вітаю',
      loginTitle: 'Вхід',
      paywallTitle: 'Premium',
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
