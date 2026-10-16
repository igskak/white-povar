import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/recipes/presentation/widgets/content_detail_sections.dart';

void main() {
  group('ingredient serving presentation', () {
    test('scales from the immutable base amount and guards invalid servings',
        () {
      expect(
        scaledIngredientAmount(1.5, selectedServings: 3, baseServings: 2),
        2.25,
      );
      expect(
        scaledIngredientAmount(1.5, selectedServings: 3, baseServings: 0),
        1.5,
      );
    });

    test('formats Ukrainian amounts without decimal artifacts', () {
      expect(formatIngredientAmount(2), '2');
      expect(formatIngredientAmount(2.5), '2,5');
      expect(formatIngredientAmount(.125), '0,125');
      expect(formatIngredientAmount(.00001), '0,00001');
      expect(formatIngredientAmount(double.infinity), '');
    });
  });
}
