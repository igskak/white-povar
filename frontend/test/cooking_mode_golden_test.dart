import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/presentation/pages/cooking_mode_page.dart';
import 'package:frontend/features/recipes/providers/recipe_provider.dart';
import 'package:frontend/features/subscription/providers/subscription_provider.dart';

void main() {
  testWidgets('Cooking active and finish goldens at handoff breakpoints',
      (tester) async {
    const wakelockChannel =
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle';
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      wakelockChannel,
      (_) async => const StandardMessageCodec().encodeMessage(<Object?>[null]),
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMessageHandler(wakelockChannel, null));
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final state in _CookingFixtureState.values) {
      for (final width in [390.0, 768.0, 1280.0]) {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(_cookingApp('${state.name}-$width'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        if (state == _CookingFixtureState.finish) {
          for (var index = 0;
              index < _recipe.instructions.length - 1;
              index++) {
            await tester.tap(find.text('Далі'));
            await tester.pump();
          }
          await tester.tap(find.text('Завершити'));
          await tester.pump();
        }

        await expectLater(
          find.byType(CookingModePage),
          matchesGoldenFile(
            'goldens/cooking_${state.name}_${width.toInt()}.png',
          ),
        );
        expect(tester.takeException(), isNull,
            reason: '${state.name} at $width');
      }
    }
  }, tags: 'golden');
}

Widget _cookingApp(String fixtureKey) => ProviderScope(
      overrides: [
        recipeDetailProvider(_recipe.id).overrideWith((_) async => _recipe),
        authProvider.overrideWith((_) => AuthNotifier.testing()),
        isPremiumProvider.overrideWithValue(true),
      ],
      child: MaterialApp(
        theme: AppThemeV2.dark(_brand),
        home: CookingModePage(
          key: ValueKey(fixtureKey),
          recipeId: 'cooking-handoff',
        ),
      ),
    );

enum _CookingFixtureState { active, finish }

final _recipe = Recipe(
  id: 'cooking-handoff',
  title: 'Капрезе 2.0 з фаршированим томатом',
  description: 'Авторська літня страва.',
  chefId: 'chef',
  cuisine: 'Італійська',
  category: 'Вечеря',
  difficulty: 2,
  prepTimeMinutes: 20,
  cookTimeMinutes: 15,
  totalTimeMinutes: 35,
  servings: 4,
  ingredients: const [],
  instructions: const [
    'Зріжте верхівки томатів і обережно вийміть серцевину.',
    'Змішайте моцарелу зі свіжим базиліком та оливковою олією.',
    'Наповніть томати й запікайте до м’якої текстури.',
    'Дайте страві відпочити дві хвилини перед подачею.',
  ],
  images: const [],
  tags: const ['seasonal'],
  isFeatured: true,
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
