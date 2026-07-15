import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/pantry/models/pantry_models.dart';

void main() {
  test('shopping item keeps its checked state for offline-safe retry payloads',
      () {
    final item = ShoppingItem.fromJson({
      'id': 'one',
      'name': 'Молоко',
      'category': 'Молочне',
      'checked': false
    });
    expect(item.copyWith(checked: true).toJson()['checked'], isTrue);
  });

  test('pantry parses optional quantity and freshness', () {
    final item = PantryItem.fromJson({
      'id': 'one',
      'name': 'Томат',
      'quantity': 2,
      'unit': 'шт',
      'freshness_date': '2026-07-15T00:00:00Z'
    });
    expect(item.quantity, 2);
    expect(item.freshnessDate, isNotNull);
  });
}
