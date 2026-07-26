import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/images/remote_image.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/presentation/widgets/recipe_photo.dart';

void main() {
  test('role-aware presentation falls back to primary and preserves focal', () {
    final recipe = Recipe.fromJson(const {
      'id': 'recipe',
      'chef_id': 'chef',
      'title': 'Борщ',
      'description': 'Опис',
      'cuisine': 'Українська',
      'category': 'Перші страви',
      'difficulty': 2,
      'prep_time_minutes': 10,
      'cook_time_minutes': 30,
      'total_time_minutes': 40,
      'servings': 4,
      'ingredients': [],
      'instructions': ['Крок'],
      'images': ['https://example.test/legacy.webp'],
      'image_presentation': {
        'primary': {
          'url': 'https://example.test/primary.webp',
          'alt_text': 'Тарілка борщу',
          'focal': {'x': .8, 'y': .35},
        },
        'featured': {
          'url': 'https://example.test/featured.webp',
          'alt_text': 'Борщ на столі',
          'focal': {'x': .2, 'y': .5},
        },
        'detail': null,
      },
      'tags': [],
      'is_featured': true,
      'is_premium': false,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(recipe.imageFor(RecipeImageRole.list)!.url,
        'https://example.test/primary.webp');
    expect(recipe.imageFor(RecipeImageRole.detail)!.focal.x, .8);
    expect(recipe.imageFor(RecipeImageRole.featured)!.url,
        'https://example.test/featured.webp');
    expect(recipe.imageFor(RecipeImageRole.featured)!.focal.x, .2);
  });

  test('legacy images receive a centered primary presentation', () {
    final recipe = Recipe.fromJson(const {
      'id': 'recipe',
      'chef_id': 'chef',
      'title': 'Страва',
      'description': 'Опис',
      'cuisine': 'Інше',
      'category': 'Інше',
      'difficulty': 1,
      'prep_time_minutes': 0,
      'cook_time_minutes': 0,
      'total_time_minutes': 0,
      'servings': 1,
      'ingredients': [],
      'instructions': [],
      'images': ['https://example.test/legacy.webp'],
      'tags': [],
      'is_featured': false,
      'is_premium': false,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(recipe.imageFor(RecipeImageRole.detail)!.focal,
        const RecipeFocalPoint());
  });

  testWidgets('focal coordinates become Flutter alignment', (tester) async {
    final recipe = Recipe.fromJson(const {
      'id': 'recipe',
      'chef_id': 'chef',
      'title': 'Страва праворуч',
      'description': 'Опис',
      'cuisine': 'Українська',
      'category': 'Інше',
      'difficulty': 1,
      'prep_time_minutes': 0,
      'cook_time_minutes': 0,
      'total_time_minutes': 0,
      'servings': 1,
      'ingredients': [],
      'instructions': [],
      'images': [],
      'image_presentation': {
        'primary': {
          'url': 'https://example.test/dish.webp',
          'focal': {'x': .8, 'y': .35},
        },
      },
      'tags': [],
      'is_featured': false,
      'is_premium': false,
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RecipePhoto(
          recipe: recipe,
          role: RecipeImageRole.detail,
          width: 400,
          height: 300,
        ),
      ),
    );

    final alignment =
        tester.widget<RemoteImage>(find.byType(RemoteImage)).alignment;
    expect(alignment.x, closeTo(.6, .0001));
    expect(alignment.y, closeTo(-.3, .0001));
  });
}
