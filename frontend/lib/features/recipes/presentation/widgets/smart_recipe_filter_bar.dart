import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/recipe_provider.dart';
import '../../providers/filter_options_provider.dart';

class SmartRecipeFilterBar extends ConsumerStatefulWidget {
  const SmartRecipeFilterBar({super.key});

  @override
  ConsumerState<SmartRecipeFilterBar> createState() =>
      _SmartRecipeFilterBarState();
}

class _SmartRecipeFilterBarState extends ConsumerState<SmartRecipeFilterBar> {
  bool _showAllFilters = false;

  @override
  Widget build(BuildContext context) {
    final currentFilter = ref.watch(recipeFilterProvider);
    final filterOptionsAsync = ref.watch(filterOptionsProvider);
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
                // Active filters indicator
                if (!currentFilter.isEmpty) ...[
                  _ActiveFiltersIndicator(currentFilter: currentFilter),
                  const SizedBox(width: 8),
                ],
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
            filterOptionsAsync.when(
              data: (filterOptions) => _buildExpandedFilters(
                  context, ref, currentFilter, filterOptions),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => _buildExpandedFilters(
                context,
                ref,
                currentFilter,
                FilterOptions.empty(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandedFilters(
    BuildContext context,
    WidgetRef ref,
    RecipeFilter currentFilter,
    FilterOptions filterOptions,
  ) {
    return Column(
      children: [
        // Difficulty section
        if (filterOptions.difficulties.isNotEmpty)
          _FilterSection(
            title: 'Difficulty',
            children: filterOptions.difficulties
                .map(
                  (difficulty) => _FilterChip(
                    label: _getDifficultyLabel(difficulty),
                    isSelected: currentFilter.difficulty == difficulty,
                    onTap: () =>
                        _applyFilter(ref, RecipeFilter(difficulty: difficulty)),
                  ),
                )
                .toList(),
          ),

        if (filterOptions.difficulties.isNotEmpty) const SizedBox(height: 12),

        // Cuisine section
        if (filterOptions.cuisines.isNotEmpty)
          _FilterSection(
            title: 'Cuisine',
            children: filterOptions.cuisines
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

        if (filterOptions.cuisines.isNotEmpty) const SizedBox(height: 12),

        // Category section
        if (filterOptions.categories.isNotEmpty)
          _FilterSection(
            title: 'Category',
            children: filterOptions.categories
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

class _ActiveFiltersIndicator extends StatelessWidget {
  final RecipeFilter currentFilter;

  const _ActiveFiltersIndicator({required this.currentFilter});

  @override
  Widget build(BuildContext context) {
    final activeFilters = <String>[];

    if (currentFilter.cuisine != null) {
      activeFilters.add(currentFilter.cuisine!);
    }
    if (currentFilter.category != null) {
      activeFilters.add(currentFilter.category!);
    }
    if (currentFilter.difficulty != null) {
      activeFilters.add('Level ${currentFilter.difficulty}');
    }
    if (currentFilter.maxTime != null) {
      activeFilters.add('< ${currentFilter.maxTime}min');
    }

    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '${activeFilters.length} active',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
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
