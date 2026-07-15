import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recipes/models/recipe.dart';
import 'package:frontend/features/recipes/services/cooking_progress_store.dart';

void main() {
  test('offline cooking snapshot preserves recipe, step and timer', () {
    final progress = CookingProgress(
      recipe: _recipe,
      step: 1,
      updatedAt: DateTime.utc(2026, 7, 15, 12),
      timerEndsAt: DateTime.utc(2026, 7, 15, 12, 5),
    );

    final restored = CookingProgress.fromJson(progress.toJson());

    expect(restored.recipe, _recipe);
    expect(restored.step, 1);
    expect(restored.timerEndsAt, DateTime.utc(2026, 7, 15, 12, 5));
  });

  test('saved recipe snapshot is serializable for offline reading', () async {
    final progress = CookingProgress(
        recipe: _recipe, step: 0, updatedAt: DateTime.utc(2026));
    expect(CookingProgress.fromJson(progress.toJson()).recipe.title, 'Борщ');
  });
}

final _recipe = Recipe(
  id: 'recipe-1',
  title: 'Борщ',
  description: '',
  chefId: 'chef',
  cuisine: '',
  category: '',
  difficulty: 1,
  prepTimeMinutes: 0,
  cookTimeMinutes: 10,
  totalTimeMinutes: 10,
  servings: 2,
  ingredients: const [],
  instructions: const ['Крок 1', 'Крок 2'],
  images: const [],
  tags: const [],
  isFeatured: false,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
