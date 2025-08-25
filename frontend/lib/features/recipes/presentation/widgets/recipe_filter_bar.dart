import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/recipe_provider.dart';

class RecipeFilterBar extends ConsumerWidget {
  const RecipeFilterBar({super.key});

  // Available filter options based on our database
  static const List<String> availableCuisines = [
    'Italian',
    'French',
    'Mediterranean',
  ];

  static const List<String> availableCategories = [
    'Appetizers',
    'First Courses',
    'Second Courses',
    'Side Dishes',
    'Desserts',
    'Beverages',
    'Bread & Baked Goods',
    'Salads',
  ];

  static const List<int> availableDifficulties = [1, 2, 3, 4, 5];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(recipeFilterProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // All filter
            _FilterChip(
              label: 'All',
              isSelected: currentFilter.isEmpty,
              onTap: () => _applyFilter(ref, const RecipeFilter()),
            ),
            const SizedBox(width: 8),

            // Featured filter
            _FilterChip(
              label: 'Featured',
              isSelected: currentFilter.isFeatured == true,
              onTap: () =>
                  _applyFilter(ref, const RecipeFilter(isFeatured: true)),
            ),
            const SizedBox(width: 8),

            // Time filters
            _FilterChip(
              label: 'Quick (< 30 min)',
              isSelected: currentFilter.maxTime == 30,
              onTap: () => _applyFilter(ref, const RecipeFilter(maxTime: 30)),
            ),
            const SizedBox(width: 8),

            _FilterChip(
              label: 'Medium (< 60 min)',
              isSelected: currentFilter.maxTime == 60,
              onTap: () => _applyFilter(ref, const RecipeFilter(maxTime: 60)),
            ),
            const SizedBox(width: 8),

            // Difficulty filters
            ...availableDifficulties.map((difficulty) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: _getDifficultyLabel(difficulty),
                    isSelected: currentFilter.difficulty == difficulty,
                    onTap: () =>
                        _applyFilter(ref, RecipeFilter(difficulty: difficulty)),
                  ),
                )),

            // Cuisine filters
            ...availableCuisines.map((cuisine) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: cuisine,
                    isSelected: currentFilter.cuisine == cuisine,
                    onTap: () =>
                        _applyFilter(ref, RecipeFilter(cuisine: cuisine)),
                  ),
                )),

            // Category filters
            ...availableCategories.map((category) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: category,
                    isSelected: currentFilter.category == category,
                    onTap: () =>
                        _applyFilter(ref, RecipeFilter(category: category)),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _applyFilter(WidgetRef ref, RecipeFilter filter) {
    ref.read(recipeFilterProvider.notifier).state = filter;
    ref.read(recipeListProvider.notifier).loadRecipes(filter);
  }

  String _getDifficultyLabel(int difficulty) {
    switch (difficulty) {
      case 1:
        return 'Very Easy ⭐';
      case 2:
        return 'Easy ⭐⭐';
      case 3:
        return 'Medium ⭐⭐⭐';
      case 4:
        return 'Hard ⭐⭐⭐⭐';
      case 5:
        return 'Very Hard ⭐⭐⭐⭐⭐';
      default:
        return 'Level $difficulty';
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
