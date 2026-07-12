import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/subscription.dart';
import 'premium_gate_card.dart';

/// Dialog to prompt user to upgrade to premium.
class UpgradePromptDialog extends StatelessWidget {
  const UpgradePromptDialog({
    super.key,
    required this.prompt,
  });

  final UpgradePrompt prompt;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: PremiumGateCard.fromPrompt(
          prompt: prompt,
          onSecondary: () => context.pop(),
          onPrimary: () {
            context.pop();
            _handleUpgradeAction(context, prompt.ctaAction);
          },
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
        context.push('/subscription');
    }
  }

  static Future<void> show(BuildContext context, UpgradePrompt prompt) {
    return showDialog(
      context: context,
      builder: (context) => UpgradePromptDialog(prompt: prompt),
    );
  }

  static Future<void> showAIFeaturePrompt(BuildContext context) {
    const prompt = UpgradePrompt(
      title: 'Unlock AI Features',
      message:
          'Get access to AI-powered recipe generation, cooking tips, and more with Premium.',
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

  static Future<void> showPremiumRecipePrompt(BuildContext context) {
    const prompt = UpgradePrompt(
      title: 'Premium Recipe',
      message:
          'This recipe is available only for Premium members. Upgrade to unlock full access.',
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

  static Future<void> showAdvancedSearchPrompt(BuildContext context) {
    const prompt = UpgradePrompt(
      title: 'Advanced Search',
      message:
          'Unlock advanced filters and premium-only recipe discovery with Premium.',
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
