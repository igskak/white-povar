import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_provider.dart';
import '../models/recipe_suggestion.dart';

class RecipeSuggestionsWidget extends ConsumerWidget {
  const RecipeSuggestionsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recipeSuggestionsProvider);

    if (state.isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('AI is analyzing your ingredients...'),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error: ${state.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(recipeSuggestionsProvider.notifier).clearSuggestions();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (state.suggestions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lightbulb_outline, size: 48),
            SizedBox(height: 16),
            Text(
              'Enter ingredients above to get AI-powered recipe suggestions',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: state.suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = state.suggestions[index];
        return _SuggestionCard(suggestion: suggestion);
      },
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final RecipeSuggestion suggestion;

  const _SuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and Difficulty
            Row(
              children: [
                Expanded(
                  child: Text(
                    suggestion.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _DifficultyChip(difficulty: suggestion.difficulty),
              ],
            ),
            const SizedBox(height: 8),
            
            // Description
            Text(
              suggestion.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            
            // Time and Techniques
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  suggestion.timeDisplay,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(width: 16),
                Icon(Icons.restaurant, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    suggestion.keyTechniques.join(', '),
                    style: TextStyle(color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            // Missing Ingredients
            if (suggestion.missingIngredients.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_cart, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Missing ingredients:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      suggestion.missingIngredients.join(', '),
                      style: TextStyle(color: Colors.orange[700]),
                    ),
                  ],
                ),
              ),
            ],
            
            // Action Buttons
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    // TODO: Create recipe from suggestion
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Recipe'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    // TODO: Save suggestion
                  },
                  icon: const Icon(Icons.bookmark_border),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  final String difficulty;

  const _DifficultyChip({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (difficulty.toLowerCase()) {
      case 'easy':
        color = Colors.green;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      case 'hard':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
