import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
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
    Future.microtask(
      () => ref.read(subscriptionProvider.notifier).loadSubscriptionStatus(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Підписка'),
      ),
      body: SafeArea(
        child: state.isLoading
            ? const StateView.loading(
                title: 'Завантажуємо підписку',
                subtitle: 'Перевіряємо поточний рівень доступу.',
              )
            : state.hasError
                ? StateView.error(
                    title: 'Не вдалося завантажити підписку',
                    subtitle: state.error,
                    onRetry: () =>
                        ref.read(subscriptionProvider.notifier).refresh(),
                  )
                : state.hasStatus
                    ? _SubscriptionContent(status: state.status!)
                    : StateView.empty(
                        title: 'Немає даних підписки',
                        subtitle: 'Повторіть завантаження статусу акаунта.',
                        icon: Icons.credit_card_off_outlined,
                        onRetry: () =>
                            ref.read(subscriptionProvider.notifier).refresh(),
                        actionLabel: 'Оновити',
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
                  'Що дає Premium',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                const _ValueItem(
                  icon: Icons.auto_awesome_outlined,
                  title: 'AI-помічник на кухні',
                  subtitle:
                      'Підказки, заміни інгредієнтів і поради під час приготування.',
                ),
                const _ValueItem(
                  icon: Icons.workspace_premium_outlined,
                  title: 'Premium-каталог',
                  subtitle: 'Доступ до складніших рецептів і шеф-рівня.',
                ),
                const _ValueItem(
                  icon: Icons.filter_alt_outlined,
                  title: 'Розширений пошук',
                  subtitle:
                      'Більше фільтрів, щоб швидше знаходити потрібні рецепти.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FeaturesSummary(features: status.features),
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
                    'Поточний план',
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
                  Text('Статус: ${subscription.status.displayName}'),
                  if (subscription.endDate != null)
                    Text(
                      'Діє до: ${_formatDate(subscription.endDate!)}',
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
      (name: 'Базові рецепти', enabled: features.basicRecipes),
      (name: 'Базовий пошук', enabled: features.basicSearch),
      (name: 'Збережене', enabled: features.favorites),
      (name: 'Premium-рецепти', enabled: features.premiumRecipes),
      (name: 'Розширений пошук', enabled: features.advancedSearch),
      (name: 'AI-генерація рецептів', enabled: features.aiRecipeGeneration),
      (name: 'AI-поради під час готування', enabled: features.aiCookingTips),
      (name: 'AI-заміни інгредієнтів', enabled: features.aiSubstitutions),
      (name: 'Аналіз поживності', enabled: features.aiNutritionAnalysis),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Поточний доступ',
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
