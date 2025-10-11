import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ai_assistant_dialog.dart';
import '../../subscription/providers/subscription_provider.dart';
import '../../subscription/widgets/upgrade_prompt_dialog.dart';

class AIAssistantButton extends ConsumerWidget {
  final String? recipeTitle;
  final List<String>? ingredients;
  final List<String>? instructions;
  final String? context;

  const AIAssistantButton({
    super.key,
    this.recipeTitle,
    this.ingredients,
    this.instructions,
    this.context,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.extended(
      onPressed: () => _showAIAssistant(context, ref),
      icon: const Icon(Icons.psychology),
      label: const Text('AI Assistant'),
      backgroundColor: Theme.of(context).colorScheme.secondary,
      foregroundColor: Theme.of(context).colorScheme.onSecondary,
    );
  }

  void _showAIAssistant(BuildContext context, WidgetRef ref) async {
    // Check premium access
    final features = ref.read(subscriptionFeaturesProvider);
    if (!features.aiRecipeGeneration) {
      await UpgradePromptDialog.showAIFeaturePrompt(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AIAssistantDialog(
        recipeTitle: recipeTitle,
        ingredients: ingredients,
        instructions: instructions,
        context: this.context,
      ),
    );
  }
}

class AIAssistantIconButton extends ConsumerWidget {
  final String? recipeTitle;
  final List<String>? ingredients;
  final List<String>? instructions;
  final String? context;

  const AIAssistantIconButton({
    super.key,
    this.recipeTitle,
    this.ingredients,
    this.instructions,
    this.context,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => _showAIAssistant(context, ref),
      icon: const Icon(Icons.psychology),
      tooltip: 'AI Assistant',
    );
  }

  void _showAIAssistant(BuildContext context, WidgetRef ref) async {
    // Check premium access
    final features = ref.read(subscriptionFeaturesProvider);
    if (!features.aiRecipeGeneration) {
      await UpgradePromptDialog.showAIFeaturePrompt(context);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AIAssistantDialog(
        recipeTitle: recipeTitle,
        ingredients: ingredients,
        instructions: instructions,
        context: this.context,
      ),
    );
  }
}
