import 'package:flutter/material.dart';

import '../models/subscription.dart';

class PremiumGateCard extends StatelessWidget {
  const PremiumGateCard({
    super.key,
    required this.title,
    required this.message,
    required this.features,
    this.ctaLabel = 'Upgrade to Premium',
    this.secondaryLabel = 'Maybe later',
    this.onPrimary,
    this.onSecondary,
  });

  factory PremiumGateCard.fromPrompt({
    Key? key,
    required UpgradePrompt prompt,
    VoidCallback? onPrimary,
    VoidCallback? onSecondary,
  }) {
    return PremiumGateCard(
      key: key,
      title: prompt.title,
      message: prompt.message,
      features: prompt.features,
      ctaLabel: prompt.ctaText,
      onPrimary: onPrimary,
      onSecondary: onSecondary,
    );
  }

  final String title;
  final String message;
  final List<String> features;
  final String ctaLabel;
  final String secondaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    size: 22,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: theme.textTheme.bodyMedium,
            ),
            if (features.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
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
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    child: Text(secondaryLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(ctaLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
