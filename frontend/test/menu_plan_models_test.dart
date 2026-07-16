import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/menu_plan/models/menu_plan.dart';

void main() {
  test('weekly slot preserves servings and premium teaser state', () {
    final slot = MenuPlanSlot.fromJson({
      'id': 'slot-1',
      'planned_for': '2026-07-20',
      'recipe_id': 'recipe-1',
      'title': 'Борщ',
      'servings': 4,
      'position': 1,
      'is_premium': true,
    });
    expect(slot.copyWith(servings: 6).input()['servings'], 6);
    expect(slot.isPremium, isTrue);
  });
}
