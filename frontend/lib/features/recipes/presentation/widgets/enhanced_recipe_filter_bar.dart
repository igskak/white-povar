import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/recipe_provider.dart';

class EnhancedRecipeFilterBar extends ConsumerStatefulWidget {
  const EnhancedRecipeFilterBar({super.key});

  @override
  ConsumerState<EnhancedRecipeFilterBar> createState() =>
      _EnhancedRecipeFilterBarState();
}

class _EnhancedRecipeFilterBarState
    extends ConsumerState<EnhancedRecipeFilterBar> {
  bool _showAllFilters = false;

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
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick filters row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  isSelected: currentFilter.isEmpty,
                  onTap: () => _applyFilter(ref, const RecipeFilter()),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Featured',
                  isSelected: currentFilter.isFeatured == true,
                  onTap: () =>
                      _applyFilter(ref, const RecipeFilter(isFeatured: true)),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Quick (< 30 min)',
                  isSelected: currentFilter.maxTime == 30,
                  onTap: () =>
                      _applyFilter(ref, const RecipeFilter(maxTime: 30)),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Medium (< 60 min)',
                  isSelected: currentFilter.maxTime == 60,
                  onTap: () =>
                      _applyFilter(ref, const RecipeFilter(maxTime: 60)),
                ),
                const SizedBox(width: 8),
                // Show more filters button
                _FilterChip(
                  label: _showAllFilters ? 'Less Filters' : 'More Filters',
                  isSelected: false,
                  onTap: () =>
                      setState(() => _showAllFilters = !_showAllFilters),
                  icon: _showAllFilters ? Icons.expand_less : Icons.expand_more,
                ),
              ],
            ),
          ),

          // Expanded filters
          if (_showAllFilters) ...[
            const SizedBox(height: 16),

            // Difficulty section
            _FilterSection(
              title: 'Difficulty',
              children: availableDifficulties
                  .map(
                    (difficulty) => _FilterChip(
                      label: _getDifficultyLabel(difficulty),
                      isSelected: currentFilter.difficulty == difficulty,
                      onTap: () => _applyFilter(
                          ref, RecipeFilter(difficulty: difficulty)),
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 12),

            // Cuisine section
            _FilterSection(
              title: 'Cuisine',
              children: availableCuisines
                  .map(
                    (cuisine) => _FilterChip(
                      label: cuisine,
                      isSelected: currentFilter.cuisine == cuisine,
                      onTap: () =>
                          _applyFilter(ref, RecipeFilter(cuisine: cuisine)),
                    ),
                  )
                  .toList(),
            ),

            const SizedBox(height: 12),

            // Category section
            _FilterSection(
              title: 'Category',
              children: availableCategories
                  .map(
                    (category) => _FilterChip(
                      label: category,
                      isSelected: currentFilter.category == category,
                      onTap: () =>
                          _applyFilter(ref, RecipeFilter(category: category)),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
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

class _FilterSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FilterSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
              ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: children
                .map((child) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: child,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.3),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface.withOpacity(0.8),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
