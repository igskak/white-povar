import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'recipe_provider.dart';

// Filter options model
class FilterOptions {
  final List<String> cuisines;
  final List<String> categories;
  final List<int> difficulties;

  const FilterOptions({
    required this.cuisines,
    required this.categories,
    required this.difficulties,
  });

  factory FilterOptions.empty() {
    return const FilterOptions(
      cuisines: [],
      categories: [],
      difficulties: [],
    );
  }
}

// Provider for filter options
final filterOptionsProvider = FutureProvider<FilterOptions>((ref) async {
  try {
    final recipeService = ref.watch(recipeServiceProvider);

    final data = await recipeService.getSearchFilterOptions();
    final difficultyRange =
        (data['difficulty_range'] as Map<String, dynamic>?) ?? const {};
    final minDifficulty = difficultyRange['min'] as int? ?? 1;
    final maxDifficulty = difficultyRange['max'] as int? ?? 5;

    return FilterOptions(
      cuisines: List<String>.from(data['cuisines'] as List? ?? const []),
      categories: List<String>.from(data['categories'] as List? ?? const []),
      difficulties: [
        for (var value = minDifficulty; value <= maxDifficulty; value++) value,
      ],
    );
  } catch (e) {
    // Return default options if API fails
    return const FilterOptions(
      cuisines: ['Italian', 'French', 'Mediterranean'],
      categories: [
        'Appetizers',
        'First Courses',
        'Second Courses',
        'Side Dishes',
        'Desserts',
        'Beverages',
        'Bread & Baked Goods',
        'Salads'
      ],
      difficulties: [1, 2, 3, 4, 5],
    );
  }
});
