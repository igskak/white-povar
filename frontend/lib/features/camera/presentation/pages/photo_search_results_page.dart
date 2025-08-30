import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../recipes/models/recipe.dart';
import '../../../recipes/presentation/widgets/recipe_card.dart';
import '../../models/detected_ingredient.dart';
import '../../providers/photo_search_provider.dart';

class PhotoSearchResultsPage extends ConsumerWidget {
  const PhotoSearchResultsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoSearchState = ref.watch(photoSearchProvider);
    final ingredients = ref.watch(ingredientEditProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Suggestions'),
        actions: [
          IconButton(
            onPressed: () => _showIngredientSummary(context, ingredients),
            icon: const Icon(Icons.info_outline),
            tooltip: 'View ingredients used',
          ),
        ],
      ),
      body: _buildBody(context, photoSearchState, ingredients),
    );
  }

  Widget _buildBody(BuildContext context, PhotoSearchState state, ingredients) {
    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding recipes with your ingredients...'),
          ],
        ),
      );
    }

    if (state.error != null) {
      return _buildErrorView(context, state.error!);
    }

    if (state.suggestedRecipes.isEmpty) {
      return _buildEmptyState(context, ingredients);
    }

    return _buildRecipeResults(context, state.suggestedRecipes, ingredients);
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Search Failed',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ingredients) {
    final confirmedIngredients =
        ingredients.where((i) => i.isConfirmed).map((i) => i.name).toList();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Recipes Found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'We couldn\'t find recipes matching your ingredients:',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: confirmedIngredients.map((ingredient) {
                return Chip(
                  label: Text(ingredient),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Edit Ingredients'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go('/search'),
                  child: const Text('Browse All Recipes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeResults(
    BuildContext context,
    List<Map<String, dynamic>> recipesData,
    ingredients,
  ) {
    final confirmedIngredients = ingredients
        .where((i) => i.isConfirmed)
        .map((i) => i.name.toLowerCase())
        .toSet();

    return Column(
      children: [
        _buildResultsHeader(context, recipesData.length, confirmedIngredients),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: recipesData.length,
            itemBuilder: (context, index) {
              try {
                final recipe = Recipe.fromJson(recipesData[index]);
                return RecipeCard(
                  recipe: recipe,
                  onTap: () => context.push('/recipes/${recipe.id}'),
                  showMatchIndicator: true,
                  matchedIngredients: _calculateMatchedIngredients(
                    recipe,
                    confirmedIngredients,
                  ),
                );
              } catch (e) {
                // Handle invalid recipe data
                return Card(
                  child: Center(
                    child: Text(
                      'Invalid recipe data',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsHeader(
    BuildContext context,
    int recipeCount,
    Set<String> ingredients,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                '$recipeCount Recipe${recipeCount != 1 ? 's' : ''} Found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Based on ${ingredients.length} ingredient${ingredients.length != 1 ? 's' : ''}:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: ingredients.map((ingredient) {
              return Chip(
                label: Text(
                  ingredient,
                  style: const TextStyle(fontSize: 12),
                ),
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.1),
                side: BorderSide(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  int _calculateMatchedIngredients(Recipe recipe, Set<String> userIngredients) {
    final recipeIngredients =
        recipe.ingredients.map((ing) => ing.name.toLowerCase()).toSet();

    return userIngredients.intersection(recipeIngredients).length;
  }

  void _showIngredientSummary(BuildContext context, ingredients) {
    final confirmedIngredients =
        ingredients.where((i) => i.isConfirmed).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingredients Used'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${confirmedIngredients.length} ingredient${confirmedIngredients.length != 1 ? 's' : ''} used for search:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            ...confirmedIngredients.map((ingredient) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.check, size: 16, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(ingredient.name)),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
