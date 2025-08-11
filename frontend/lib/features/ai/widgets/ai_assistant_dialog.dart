import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_provider.dart';
import 'recipe_suggestions_widget.dart';
// import 'ingredient_substitutions_widget.dart';
// import 'cooking_tips_widget.dart';
// import 'nutrition_analysis_widget.dart';

class AIAssistantDialog extends ConsumerStatefulWidget {
  final String? recipeTitle;
  final List<String>? ingredients;
  final List<String>? instructions;
  final String? context;

  const AIAssistantDialog({
    super.key,
    this.recipeTitle,
    this.ingredients,
    this.instructions,
    this.context,
  });

  @override
  ConsumerState<AIAssistantDialog> createState() => _AIAssistantDialogState();
}

class _AIAssistantDialogState extends ConsumerState<AIAssistantDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _ingredientsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Pre-fill ingredients if provided
    if (widget.ingredients != null) {
      _ingredientsController.text = widget.ingredients!.join(', ');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.psychology, size: 32),
                const SizedBox(width: 12),
                const Text(
                  'AI Cooking Assistant',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Suggestions', icon: Icon(Icons.lightbulb)),
                Tab(text: 'Substitutions', icon: Icon(Icons.swap_horiz)),
                Tab(text: 'Tips', icon: Icon(Icons.tips_and_updates)),
                Tab(text: 'Nutrition', icon: Icon(Icons.health_and_safety)),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Recipe Suggestions Tab
                  _buildSuggestionsTab(),

                  // Ingredient Substitutions Tab
                  _buildSubstitutionsTab(),

                  // Cooking Tips Tab
                  _buildTipsTab(),

                  // Nutrition Analysis Tab
                  _buildNutritionTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsTab() {
    return Column(
      children: [
        // Ingredients Input
        TextField(
          controller: _ingredientsController,
          decoration: const InputDecoration(
            labelText: 'Available Ingredients',
            hintText: 'Enter ingredients separated by commas',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),

        // Get Suggestions Button
        ElevatedButton.icon(
          onPressed: _getSuggestions,
          icon: const Icon(Icons.search),
          label: const Text('Get Recipe Suggestions'),
        ),
        const SizedBox(height: 16),

        // Suggestions List
        const Expanded(
          child: RecipeSuggestionsWidget(),
        ),
      ],
    );
  }

  Widget _buildSubstitutionsTab() {
    return Column(
      children: [
        if (widget.recipeTitle != null) ...[
          Text(
            'Substitutions for: ${widget.recipeTitle}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
        ],
        const Expanded(
          child: Center(child: Text('Ingredient substitutions coming soon!')),
        ),
      ],
    );
  }

  Widget _buildTipsTab() {
    if (widget.recipeTitle == null) {
      return const Center(
        child: Text('Select a recipe to get cooking tips'),
      );
    }

    return const Center(
      child: Text('Cooking tips coming soon!'),
    );
  }

  Widget _buildNutritionTab() {
    if (widget.ingredients == null) {
      return const Center(
        child: Text('Recipe ingredients needed for nutrition analysis'),
      );
    }

    return const Center(
      child: Text('Nutrition analysis coming soon!'),
    );
  }

  void _getSuggestions() {
    final ingredients = _ingredientsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some ingredients'),
        ),
      );
      return;
    }

    ref.read(recipeSuggestionsProvider.notifier).getRecipeSuggestions(
          ingredients: ingredients,
        );
  }
}
