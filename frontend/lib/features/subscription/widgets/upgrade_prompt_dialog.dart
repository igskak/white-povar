import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/subscription.dart';

/// Dialog to prompt user to upgrade to premium
class UpgradePromptDialog extends StatelessWidget {
  final UpgradePrompt prompt;

  const UpgradePromptDialog({
    super.key,
    required this.prompt,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Premium icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.shade700,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                size: 48,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              prompt.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Message
            Text(
              prompt.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Features list
            if (prompt.features.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium Features:',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...prompt.features.map((feature) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 20,
                                color: Colors.amber.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  feature,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Maybe Later'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {
                      context.pop();
                      _handleUpgradeAction(context, prompt.ctaAction);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(prompt.ctaText),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleUpgradeAction(BuildContext context, String action) {
    switch (action) {
      case 'navigate_to_subscription':
        context.push('/subscription');
        break;
      default:
        // Default action: navigate to subscription page
        context.push('/subscription');
    }
  }

  /// Show upgrade prompt dialog
  static Future<void> show(BuildContext context, UpgradePrompt prompt) {
    return showDialog(
      context: context,
      builder: (context) => UpgradePromptDialog(prompt: prompt),
    );
  }

  /// Show upgrade prompt for AI features
  static Future<void> showAIFeaturePrompt(BuildContext context) {
    final prompt = const UpgradePrompt(
      title: 'Unlock AI Features',
      message: 'Get access to AI-powered recipe generation, cooking tips, and more with Premium!',
      features: [
        'AI Recipe Generation',
        'Smart Ingredient Substitutions',
        'Personalized Cooking Tips',
        'Nutrition Analysis',
      ],
      ctaText: 'Upgrade to Premium',
      ctaAction: 'navigate_to_subscription',
    );
    return show(context, prompt);
  }

  /// Show upgrade prompt for premium recipes
  static Future<void> showPremiumRecipePrompt(BuildContext context) {
    final prompt = const UpgradePrompt(
      title: 'Premium Recipe',
      message: 'This recipe is exclusive to Premium members. Upgrade to access premium author recipes!',
      features: [
        'Access to Premium Recipes',
        'Exclusive Chef Content',
        'Advanced Search & Filters',
        'All AI Features',
      ],
      ctaText: 'Upgrade to Premium',
      ctaAction: 'navigate_to_subscription',
    );
    return show(context, prompt);
  }

  /// Show upgrade prompt for advanced search
  static Future<void> showAdvancedSearchPrompt(BuildContext context) {
    final prompt = const UpgradePrompt(
      title: 'Advanced Search',
      message: 'Unlock advanced search features to find exactly what you\'re looking for!',
      features: [
        'Search Premium Recipes',
        'Advanced Filters',
        'Save Search Preferences',
        'All AI Features',
      ],
      ctaText: 'Upgrade to Premium',
      ctaAction: 'navigate_to_subscription',
    );
    return show(context, prompt);
  }
}

