import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subscription.dart';
import '../providers/subscription_provider.dart';
import '../widgets/premium_badge.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // Load subscription status when screen opens
    Future.microtask(() {
      ref.read(subscriptionProvider.notifier).loadSubscriptionStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subscriptionState = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        actions: [
          if (subscriptionState.hasStatus)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                ref.read(subscriptionProvider.notifier).refresh();
              },
            ),
        ],
      ),
      body: subscriptionState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : subscriptionState.hasError
              ? _buildErrorView(context, subscriptionState.error!)
              : subscriptionState.hasStatus
                  ? _buildSubscriptionView(context, subscriptionState.status!)
                  : _buildEmptyView(context),
    );
  }

  Widget _buildErrorView(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading subscription',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(subscriptionProvider.notifier).loadSubscriptionStatus();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          ref.read(subscriptionProvider.notifier).loadSubscriptionStatus();
        },
        child: const Text('Load Subscription Status'),
      ),
    );
  }

  Widget _buildSubscriptionView(
    BuildContext context,
    SubscriptionStatusResponse status,
  ) {
    final theme = Theme.of(context);
    final isPremium = status.hasPremiumAccess;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Current status card
          _buildStatusCard(context, status),
          const SizedBox(height: 24),

          // Features section
          _buildFeaturesSection(context, status.features, isPremium),
          const SizedBox(height: 24),

          // Action button
          if (!isPremium) _buildUpgradeButton(context),
          if (isPremium) _buildManageButton(context),

          // Testing buttons (only in debug mode)
          if (const bool.fromEnvironment('dart.vm.product') == false) ...[
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _buildTestingSection(context, isPremium),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    SubscriptionStatusResponse status,
  ) {
    final theme = Theme.of(context);
    final isPremium = status.hasPremiumAccess;
    final subscription = status.subscription;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isPremium
              ? LinearGradient(
                  colors: [Colors.amber.shade700, Colors.amber.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Column(
          children: [
            if (isPremium)
              const PremiumBadge(size: 48, showLabel: false)
            else
              Icon(
                Icons.account_circle,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            const SizedBox(height: 16),
            Text(
              subscription.tier.displayName,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPremium ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subscription.status.displayName,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isPremium ? Colors.white70 : theme.textTheme.bodySmall?.color,
              ),
            ),
            if (subscription.endDate != null) ...[
              const SizedBox(height: 16),
              Text(
                'Valid until: ${_formatDate(subscription.endDate!)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isPremium ? Colors.white70 : theme.textTheme.bodySmall?.color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesSection(
    BuildContext context,
    SubscriptionFeatures features,
    bool isPremium,
  ) {
    final theme = Theme.of(context);

    final featuresList = [
      _FeatureItem('Basic Recipes', features.basicRecipes, true),
      _FeatureItem('Basic Search', features.basicSearch, true),
      _FeatureItem('Favorites', features.favorites, true),
      _FeatureItem('Premium Recipes', features.premiumRecipes, false),
      _FeatureItem('Advanced Search', features.advancedSearch, false),
      _FeatureItem('AI Recipe Generation', features.aiRecipeGeneration, false),
      _FeatureItem('AI Cooking Tips', features.aiCookingTips, false),
      _FeatureItem('AI Substitutions', features.aiSubstitutions, false),
      _FeatureItem('Nutrition Analysis', features.aiNutritionAnalysis, false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Features',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...featuresList.map((item) => _buildFeatureItem(
              context,
              item.name,
              item.enabled,
              item.isFreeFeature,
            )),
      ],
    );
  }

  Widget _buildFeatureItem(
    BuildContext context,
    String name,
    bool enabled,
    bool isFreeFeature,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.lock,
            color: enabled
                ? Colors.green
                : theme.textTheme.bodySmall?.color?.withOpacity(0.5),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: enabled ? null : theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
          if (!isFreeFeature && !enabled)
            const PremiumBadge(size: 16, showLabel: false),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        // TODO: Navigate to payment/upgrade flow
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment integration coming soon!'),
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.amber.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Upgrade to Premium',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildManageButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        // TODO: Navigate to manage subscription
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Subscription management coming soon!'),
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text(
        'Manage Subscription',
        style: TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildTestingSection(BuildContext context, bool isPremium) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Testing Controls',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        if (!isPremium)
          ElevatedButton(
            onPressed: () async {
              try {
                await ref
                    .read(subscriptionProvider.notifier)
                    .grantPremiumAccess(durationDays: 30);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Premium access granted for 30 days!'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Grant Premium (30 days)'),
          ),
        if (isPremium)
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(subscriptionProvider.notifier).revokePremiumAccess();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Premium access revoked'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Revoke Premium'),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _FeatureItem {
  final String name;
  final bool enabled;
  final bool isFreeFeature;

  _FeatureItem(this.name, this.enabled, this.isFreeFeature);
}

