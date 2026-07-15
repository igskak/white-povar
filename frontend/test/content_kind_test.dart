import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/recipes/models/recipe.dart';

void main() {
  test('defaults legacy payloads to recipe content', () {
    final recipe = Recipe.fromJson(_payload());
    expect(recipe.contentKind, ContentKind.recipe);
  });

  test(
      'parses supported content kinds and safely falls back for unknown values',
      () {
    expect(
      Recipe.fromJson(_payload(contentKind: 'technique')).contentKind,
      ContentKind.technique,
    );
    expect(
      Recipe.fromJson(_payload(contentKind: 'unexpected')).contentKind,
      ContentKind.recipe,
    );
  });
}

Map<String, dynamic> _payload({String? contentKind}) => {
      'id': 'recipe-1',
      'title': 'Тестовий матеріал',
      'description': 'Опис',
      'chef_id': 'chef-1',
      'cuisine': 'Українська',
      'category': 'Інше',
      'difficulty': 1,
      'prep_time_minutes': 0,
      'cook_time_minutes': 0,
      'total_time_minutes': 0,
      'servings': 1,
      'ingredients': const [],
      'instructions': const [],
      'images': const [],
      'tags': const [],
      'is_featured': false,
      'created_at': '2026-07-15T00:00:00Z',
      'updated_at': '2026-07-15T00:00:00Z',
      if (contentKind != null) 'content_kind': contentKind,
    };
