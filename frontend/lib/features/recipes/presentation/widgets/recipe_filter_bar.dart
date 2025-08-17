import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/recipe_provider.dart';

class RecipeFilterBar extends ConsumerWidget {
  const RecipeFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(recipeFilterProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              isSelected: currentFilter.isEmpty,
              onTap: () {
                ref.read(recipeFilterProvider.notifier).state = const RecipeFilter();
                ref.read(recipeListProvider.notifier).loadRecipes(const RecipeFilter());
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Featured',
              isSelected: currentFilter.isFeatured == true,
              onTap: () {
                final newFilter = const RecipeFilter(isFeatured: true);
                ref.read(recipeFilterProvider.notifier).state = newFilter;
                ref.read(recipeListProvider.notifier).loadRecipes(newFilter);
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Quick (< 30 min)',
              isSelected: currentFilter.maxTime == 30,
              onTap: () {
                final newFilter = const RecipeFilter(maxTime: 30);
                ref.read(recipeFilterProvider.notifier).state = newFilter;
                ref.read(recipeListProvider.notifier).loadRecipes(newFilter);
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Mediterranean',
              isSelected: currentFilter.cuisine == 'Mediterranean',
              onTap: () {
                final newFilter = const RecipeFilter(cuisine: 'Mediterranean');
                ref.read(recipeFilterProvider.notifier).state = newFilter;
                ref.read(recipeListProvider.notifier).loadRecipes(newFilter);
              },
            ),
            const SizedBox(width: 8),
            _FilterChip(
              label: 'Mexican',
              isSelected: currentFilter.cuisine == 'Mexican',
              onTap: () {
                final newFilter = const RecipeFilter(cuisine: 'Mexican');
                ref.read(recipeFilterProvider.notifier).state = newFilter;
                ref.read(recipeListProvider.notifier).loadRecipes(newFilter);
              },
            ),
          ],
        ),
      ),
    );
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
          color: isSelected 
              ? Theme.of(context).primaryColor 
              : Colors.grey[200],
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
