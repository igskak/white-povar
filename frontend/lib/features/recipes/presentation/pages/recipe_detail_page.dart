import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../subscription/widgets/premium_badge.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../widgets/recipe_video_widget.dart';

class RecipeDetailPage extends ConsumerWidget {
  const RecipeDetailPage({
    super.key,
    required this.recipeId,
  });

  final String recipeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipeAsync = ref.watch(recipeDetailProvider(recipeId));

    return Scaffold(
      body: recipeAsync.when(
        data: (recipe) => _RecipeDetailContent(recipe: recipe),
        loading: () => const StateView.loading(
          title: 'Відкриваємо рецепт',
          subtitle: 'Завантажуємо інгредієнти та кроки приготування.',
        ),
        error: (error, _) => StateView.error(
          title: 'Не вдалося завантажити рецепт',
          subtitle: error.toString(),
          onRetry: () => ref.invalidate(recipeDetailProvider(recipeId)),
        ),
      ),
      bottomNavigationBar: recipeAsync.when(
        data: (recipe) => SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: recipe.instructions.isEmpty
                  ? null
                  : () => context.push('/recipes/$recipeId/cook'),
              icon: const Icon(Icons.soup_kitchen_outlined),
              label: const Text('Готувати'),
            ),
          ),
        ),
        loading: () => null,
        error: (_, __) => null,
      ),
    );
  }
}

class _RecipeDetailContent extends StatelessWidget {
  const _RecipeDetailContent({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 320,
          pinned: true,
          foregroundColor: AppColorsV2.onInk,
          backgroundColor: AppColorsV2.ink,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                _RecipeHeroImage(recipe: recipe),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Color(0x99000000)],
                    ),
                  ),
                ),
                if (recipe.isPremium)
                  const Positioned(
                    top: 60,
                    right: AppSpacing.md,
                    child: PremiumBadge(size: 32, showLabel: true),
                  ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  112,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.title, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      recipe.description,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColorsV2.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _StatsRow(recipe: recipe),
                    if (recipe.videoUrl != null ||
                        recipe.videoFilePath != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      Text('Відео рецепта', style: theme.textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.sm),
                      RecipeVideoWidget(
                        videoUrl: recipe.videoUrl,
                        videoFilePath: recipe.videoFilePath,
                        height: 220,
                        borderRadius: AppRadius.md,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Text('Інгредієнти', style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    ...recipe.ingredients.map(
                      (ingredient) => _IngredientRow(
                        label:
                            '${ingredient.amount} ${ingredient.unit} ${ingredient.name}'
                                .trim(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text('Кроки', style: theme.textTheme.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    ...recipe.instructions.asMap().entries.map(
                          (entry) => _InstructionStep(
                            number: entry.key + 1,
                            text: entry.value,
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecipeHeroImage extends StatelessWidget {
  const _RecipeHeroImage({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    if (recipe.images.isEmpty) {
      return const _HeroFallback();
    }

    return CachedNetworkImage(
      imageUrl: recipe.images.first,
      fit: BoxFit.cover,
      placeholder: (context, url) => const _HeroFallback(isLoading: true),
      errorWidget: (context, url, error) => const _HeroFallback(),
    );
  }
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({this.isLoading = false});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColorsV2.ink,
      alignment: Alignment.center,
      child: isLoading
          ? const CircularProgressIndicator()
          : const Icon(
              Icons.restaurant_menu_rounded,
              size: 72,
              color: AppColorsV2.onInk,
            ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final children = [
          _StatCard(
            icon: Icons.schedule_rounded,
            label: 'Час',
            value: '${recipe.totalTimeMinutes} хв',
          ),
          _StatCard(
            icon: Icons.people_outline_rounded,
            label: 'Порції',
            value: '${recipe.servings}',
          ),
          _StatCard(
            icon: Icons.speed_rounded,
            label: 'Складність',
            value: 'Рівень ${recipe.difficulty}',
          ),
        ];

        if (compact) {
          return Column(
            children: [
              for (final child in children) ...[
                child,
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              Expanded(child: children[i]),
              if (i != children.length - 1)
                const SizedBox(width: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColorsV2.surfaceStrong,
        borderRadius: AppRadius.md,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: AppColorsV2.accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColorsV2.textSecondary,
                    ),
                  ),
                  Text(
                    value,
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColorsV2.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 20,
            color: AppColorsV2.success,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({
    required this.number,
    required this.text,
  });

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColorsV2.ink,
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColorsV2.onInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
