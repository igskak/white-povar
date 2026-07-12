import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/state_views.dart';
import '../models/subscription.dart';
import '../providers/subscription_provider.dart';
import '../widgets/premium_gate_card.dart';
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
    Future.microtask(
      () => ref.read(subscriptionProvider.notifier).loadSubscriptionStatus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
      ),
      body: SafeArea(
        child: state.isLoading
            ? const StateView.loading(
                title: 'Loading subscription',
                subtitle: 'Checking your current tier and feature access.',
              )
            : state.hasError
                ? StateView.error(
                    title: 'Failed to load subscription',
                    subtitle: state.error,
                    onRetry: () =>
                        ref.read(subscriptionProvider.notifier).refresh(),
                  )
                : state.hasStatus
                    ? _SubscriptionContent(status: state.status!)
                    : StateView.empty(
                        title: 'No subscription data',
                        subtitle: 'Retry loading your account status.',
                        icon: Icons.credit_card_off_outlined,
                        onRetry: () =>
                            ref.read(subscriptionProvider.notifier).refresh(),
                        actionLabel: 'Refresh',
                      ),
      ),
    );
  }
}

class _SubscriptionContent extends ConsumerWidget {
  const _SubscriptionContent({required this.status});

  final SubscriptionStatusResponse status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = status.hasPremiumAccess;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CurrentTierCard(status: status),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why Premium',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const _ValueItem(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI cooking assistant',
                  subtitle:
                      'Generate variations, substitutions, and step-by-step tips.',
                ),
                const _ValueItem(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Premium recipe catalog',
                  subtitle:
                      'Access advanced and chef-level recipes unavailable on Free.',
                ),
                const _ValueItem(
                  icon: Icons.filter_alt_outlined,
                  title: 'Advanced discovery',
                  subtitle:
                      'Use richer filters to find recipes faster with fewer misses.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        PremiumGateCard(
          title: isPremium ? 'Premium is active' : 'Upgrade to Premium',
          message: isPremium
              ? 'You already have access to premium features. Manage billing support from your account channel.'
              : 'Unlock AI tools, premium recipes, and advanced search to reduce cooking time and find better matches.',
          features: const [
            'AI recipe generation and cooking guidance',
            'Premium recipe catalog',
            'Advanced search filters',
            'Nutrition analysis',
          ],
          ctaLabel: isPremium ? 'Manage subscription' : 'Upgrade to Premium',
          secondaryLabel: isPremium ? 'Open settings' : 'Compare plans',
          onPrimary: () {
            if (isPremium) {
              context.push('/settings');
              return;
            }

            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Upgrade flow is coming soon.'),
            ));
          },
          onSecondary: () => context.push('/profile'),
        ),
        const SizedBox(height: 16),
        _FeaturesSummary(features: status.features),
        if (!kReleaseMode) ...[
          const SizedBox(height: 20),
          _DebugControls(isPremium: isPremium),
        ],
      ],
    );
  }
}

class _CurrentTierCard extends StatelessWidget {
  const _CurrentTierCard({required this.status});

  final SubscriptionStatusResponse status;

  @override
  Widget build(BuildContext context) {
    final isPremium = status.hasPremiumAccess;
    final subscription = status.subscription;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isPremium)
              const PremiumBadge(size: 28)
            else
              const Icon(Icons.workspace_premium_outlined, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current plan',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subscription.tier.displayName,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('Status: ${subscription.status.displayName}'),
                  if (subscription.endDate != null)
                    Text(
                      'Valid until: ${_formatDate(subscription.endDate!)}',
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

class _ValueItem extends StatelessWidget {
  const _ValueItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturesSummary extends StatelessWidget {
  const _FeaturesSummary({required this.features});

  final SubscriptionFeatures features;

  @override
  Widget build(BuildContext context) {
    final items = <({String name, bool enabled})>[
      (name: 'Basic recipes', enabled: features.basicRecipes),
      (name: 'Basic search', enabled: features.basicSearch),
      (name: 'Favorites', enabled: features.favorites),
      (name: 'Premium recipes', enabled: features.premiumRecipes),
      (name: 'Advanced search', enabled: features.advancedSearch),
      (name: 'AI recipe generation', enabled: features.aiRecipeGeneration),
      (name: 'AI cooking tips', enabled: features.aiCookingTips),
      (name: 'AI substitutions', enabled: features.aiSubstitutions),
      (name: 'Nutrition analysis', enabled: features.aiNutritionAnalysis),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current access',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      item.enabled ? Icons.check_circle : Icons.lock_outline,
                      size: 18,
                      color: item.enabled
                          ? Colors.green
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.name)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugControls extends ConsumerWidget {
  const _DebugControls({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Debug controls',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            if (!isPremium)
              ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(subscriptionProvider.notifier)
                      .grantPremiumAccess(durationDays: 30);
                },
                child: const Text('Grant Premium (30 days)'),
              ),
            if (isPremium)
              ElevatedButton(
                onPressed: () async {
                  await ref
                      .read(subscriptionProvider.notifier)
                      .revokePremiumAccess();
                },
                child: const Text('Revoke Premium'),
              ),
          ],
        ),
      ),
    );
  }
}
