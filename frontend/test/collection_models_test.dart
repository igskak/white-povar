import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/collections/models/collection.dart';
import 'package:frontend/features/recipes/models/recipe.dart';

void main() {
  test('collection parses ordered mixed content and server lock state', () {
    final collection = ContentCollection.fromJson({
      'id': 'collection-1',
      'slug': 'maisternia-oleksandra',
      'title': 'Майстерня',
      'description': 'Техніки автора',
      'item_count': 2,
      'is_premium': true,
      'is_locked': true,
      'items': [
        _item(position: 1, kind: 'video', locked: true),
        _item(position: 0, kind: 'technique', preview: true),
      ],
    });

    expect(collection.isLocked, isTrue);
    expect(collection.items.map((item) => item.position), [1, 0]);
    expect(collection.items.first.content.contentKind, ContentKind.video);
    expect(collection.items.first.isLocked, isTrue);
    expect(collection.items.last.isPreview, isTrue);
  });

  test('legacy recipe payload remains unlocked when is_locked is absent', () {
    final recipe = Recipe.fromJson(
        _item(position: 0, kind: 'recipe')['content'] as Map<String, dynamic>);
    expect(recipe.isLocked, isFalse);
  });
}

Map<String, dynamic> _item({
  required int position,
  required String kind,
  bool locked = false,
  bool preview = false,
}) =>
    {
      'id': 'item-$position',
      'position': position,
      'is_preview': preview,
      'content': {
        'id': 'recipe-$position',
        'chef_id': 'chef-1',
        'title': 'Матеріал',
        'description': 'Опис',
        'content_kind': kind,
        'difficulty': 1,
        'prep_time_minutes': 0,
        'cook_time_minutes': 0,
        'total_time_minutes': 0,
        'servings': 1,
        'is_locked': locked,
        'created_at': '2026-07-15T00:00:00Z',
        'updated_at': '2026-07-15T00:00:00Z',
      },
    };
