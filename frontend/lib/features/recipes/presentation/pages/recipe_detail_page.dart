import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/recipe_provider.dart';
import '../../../ai/widgets/ai_assistant_button.dart';

class RecipeDetailPage extends ConsumerWidget {
  final String recipeId;

  const RecipeDetailPage({
    super.key,
    required this.recipeId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(recipeDetailProvider(recipeId));

    return Scaffold(
      body: recipeAsync.when(
        data: (recipe) => CustomScrollView(
          slivers: [
            // App Bar with Image
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: recipe.images.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: recipe.images.first,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.restaurant_menu,
                            size: 64,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.restaurant_menu,
                          size: 64,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),

            // Recipe Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and Basic Info
                    Text(
                      recipe.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recipe.description,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Recipe Stats
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.schedule,
                          label: 'Total Time',
                          value: '${recipe.totalTimeMinutes} min',
                        ),
                        const SizedBox(width: 16),
                        _StatCard(
                          icon: Icons.people,
                          label: 'Servings',
                          value: '${recipe.servings}',
                        ),
                        const SizedBox(width: 16),
                        _StatCard(
                          icon: Icons.star,
                          label: 'Difficulty',
                          value: 'Level ${recipe.difficulty}',
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Ingredients Section
                    Text(
                      'Ingredients',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    ...recipe.ingredients.map((ingredient) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).primaryColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${ingredient.amount} ${ingredient.unit} ${ingredient.name}',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        )),

                    const SizedBox(height: 24),

                    // Instructions Section
                    Text(
                      'Instructions',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    ...recipe.instructions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final instruction = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                instruction,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stackTrace) => Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error loading recipe',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(error.toString()),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: recipeAsync.when(
        data: (recipe) => AIAssistantButton(
          recipeTitle: recipe.title,
          ingredients: recipe.ingredients.map((ing) => ing.name).toList(),
          instructions: recipe.instructions,
          context: 'Recipe: ${recipe.title}',
        ),
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).primaryColor),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
