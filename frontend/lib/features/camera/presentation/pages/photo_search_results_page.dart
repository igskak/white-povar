import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/state_views.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/presentation/widgets/recipe_card.dart';
import '../../models/detected_ingredient.dart';
import '../../providers/photo_search_provider.dart';
import '../widgets/camera_flow_scaffold.dart';

class PhotoSearchResultsPage extends ConsumerWidget {
  const PhotoSearchResultsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoSearchState = ref.watch(photoSearchProvider);
    final ingredients = ref.watch(ingredientEditProvider);
    final confirmedIngredients = ingredients
        .where((item) => item.isConfirmed)
        .map((item) => item.name.toLowerCase())
        .toSet();

    return CameraFlowScaffold(
      title: 'Підібрані рецепти',
      step: CameraFlowStep.results,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Назад'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/camera'),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Нове фото'),
              ),
            ),
          ],
        ),
      ),
      child: _buildBody(
        context: context,
        state: photoSearchState,
        confirmedIngredients: confirmedIngredients,
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required PhotoSearchState state,
    required Set<String> confirmedIngredients,
  }) {
    if (state.isLoading) {
      return const CameraFlowStatusView.loading(
        title: 'Завантажуємо рецепти',
        subtitle: 'Підбираємо найкращі збіги.',
      );
    }

    if (state.error != null) {
      return CameraFlowStatusView.error(
        title: 'Не вдалося завантажити рецепти',
        subtitle: state.error,
        onRetry: () => context.pop(),
      );
    }

    if (state.suggestedRecipes.isEmpty) {
      return StateView.empty(
        title: 'Рецепти не знайдено',
        subtitle: 'Спробуйте змінити список продуктів або зробити інше фото.',
        icon: Icons.search_off,
        onRetry: () => context.pop(),
        actionLabel: 'Назад до списку',
      );
    }

    return Column(
      children: [
        Builder(
          builder: (themedContext) => Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              'Знайдено рецептів: ${state.suggestedRecipes.length}. Продуктів у пошуку: ${confirmedIngredients.length}.',
              style: Theme.of(themedContext).textTheme.titleMedium,
            ),
          ),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final viewportWidth = MediaQuery.sizeOf(context).width;
            final columns = viewportWidth >= 1024
                ? 3
                : viewportWidth >= 600
                    ? 2
                    : 1;
            return GridView.builder(
              key: ValueKey('camera-results-grid-$columns'),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                childAspectRatio: columns == 3 ? .60 : .72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: state.suggestedRecipes.length,
              itemBuilder: (context, index) {
                final recipeJson = state.suggestedRecipes[index];

                try {
                  final recipe = Recipe.fromJson(recipeJson);
                  return RecipeCard(
                    recipe: recipe,
                    onTap: () => context.push('/recipes/${recipe.id}'),
                    showMatchIndicator: true,
                    matchedIngredients: _calculateMatchedIngredients(
                        recipe, confirmedIngredients),
                  );
                } catch (_) {
                  return const Card(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('Рецепт недоступний'),
                      ),
                    ),
                  );
                }
              },
            );
          }),
        ),
      ],
    );
  }

  int _calculateMatchedIngredients(Recipe recipe, Set<String> userIngredients) {
    final recipeIngredients =
        recipe.ingredients.map((item) => item.name.toLowerCase()).toSet();

    return userIngredients.intersection(recipeIngredients).length;
  }
}
