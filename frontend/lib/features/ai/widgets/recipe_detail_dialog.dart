import 'package:flutter/material.dart';
import '../models/recipe_suggestion.dart';
import '../widgets/shopping_list_widget.dart';

class RecipeDetailDialog extends StatelessWidget {
  final RecipeSuggestion suggestion;

  const RecipeDetailDialog({
    super.key,
    required this.suggestion,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    suggestion.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Text(
                      suggestion.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),

                    // Recipe Details
                    _buildDetailSection(
                      'Recipe Information',
                      [
                        _buildDetailRow('Difficulty', suggestion.difficulty),
                        _buildDetailRow(
                            'Prep Time', '${suggestion.prepTime} minutes'),
                        _buildDetailRow(
                            'Cook Time', '${suggestion.cookTime} minutes'),
                        _buildDetailRow('Total Time', suggestion.timeDisplay),
                      ],
                    ),

                    // Cooking Techniques
                    if (suggestion.keyTechniques.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildDetailSection(
                        'Cooking Techniques',
                        suggestion.keyTechniques
                            .map((technique) => _buildTechniqueChip(technique))
                            .toList(),
                      ),
                    ],

                    // Missing Ingredients
                    if (suggestion.missingIngredients.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildDetailSection(
                        'Missing Ingredients',
                        suggestion.missingIngredients
                            .map((ingredient) =>
                                _buildIngredientItem(ingredient))
                            .toList(),
                      ),
                    ],

                    // Basic Instructions
                    const SizedBox(height: 24),
                    _buildDetailSection(
                      'Basic Instructions',
                      [
                        _buildInstructionStep(1,
                            'Gather all ingredients and prepare your workspace.'),
                        _buildInstructionStep(2,
                            'Follow the cooking techniques suggested for this ${suggestion.difficulty.toLowerCase()} recipe.'),
                        _buildInstructionStep(3,
                            'Cook according to the estimated prep time of ${suggestion.prepTime} minutes and cook time of ${suggestion.cookTime} minutes.'),
                        _buildInstructionStep(
                            4, 'Adjust seasoning to taste and serve hot.'),
                        _buildInstructionStep(
                            5, 'Enjoy your AI-generated ${suggestion.title}!'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Action Buttons
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navigate to shopping list
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            ShoppingListWidget(suggestion: suggestion),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shopping_cart),
                  label: const Text('Shopping List'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop('save');
                  },
                  icon: const Icon(Icons.bookmark),
                  label: const Text('Save Recipe'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildTechniqueChip(String technique) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Text(
        technique,
        style: TextStyle(
          color: Colors.blue[700],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildIngredientItem(String ingredient) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.shopping_cart, size: 16, color: Colors.orange[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ingredient,
              style: TextStyle(color: Colors.orange[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionStep(int step, String instruction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
