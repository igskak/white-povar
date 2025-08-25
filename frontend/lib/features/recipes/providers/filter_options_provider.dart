import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/recipe_service.dart';

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
    // Create a new instance to avoid circular dependency
    final recipeService = RecipeService();

    // Get all recipes to extract available options
    final recipes = await recipeService.getRecipes();

    // Extract unique cuisines
    final cuisines = recipes
        .map((recipe) => recipe.cuisine)
        .where((cuisine) => cuisine.isNotEmpty && cuisine != 'Unknown')
        .toSet()
        .toList()
      ..sort();

    // Extract unique categories
    final categories = recipes
        .map((recipe) => recipe.category)
        .where((category) => category.isNotEmpty && category != 'Unknown')
        .toSet()
        .toList()
      ..sort();

    // Extract unique difficulties
    final difficulties = recipes
        .map((recipe) => recipe.difficulty)
        .where((difficulty) => difficulty > 0)
        .toSet()
        .toList()
      ..sort();

    return FilterOptions(
      cuisines: cuisines,
      categories: categories,
      difficulties: difficulties,
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
