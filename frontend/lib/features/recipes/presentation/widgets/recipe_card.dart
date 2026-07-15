import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../models/recipe.dart';
import '../../../subscription/widgets/premium_badge.dart';
import 'favorite_button.dart';

class RecipeCard extends ConsumerWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.showMatchIndicator = false,
    this.matchedIngredients = 0,
  });

  final Recipe recipe;
  final VoidCallback? onTap;
  final bool showMatchIndicator;
  final int matchedIngredients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Semantics(
      button: onTap != null,
      label:
          'Відкрити ${_contentKindLabel(recipe.contentKind)} ${recipe.title}',
      child: ContentCard(
        onTap: onTap,
        semanticLabel:
            'Відкрити ${_contentKindLabel(recipe.contentKind)} ${recipe.title}',
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: recipe.images.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: recipe.images.first,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const _ImageFallback(isLoading: true),
                          errorWidget: (context, url, error) =>
                              const _ImageFallback(),
                        )
                      : const _ImageFallback(),
                ),
                if (recipe.isPremium)
                  const Positioned(
                    top: AppSpacing.sm,
                    left: AppSpacing.sm,
                    child: PremiumBadge(size: 24),
                  ),
                if (recipe.isFeatured)
                  const Positioned(
                    left: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: _Badge(
                      icon: Icons.local_fire_department_outlined,
                      label: 'Вибір шефа',
                    ),
                  ),
                if (recipe.videoUrl != null || recipe.videoFilePath != null)
                  const Positioned(
                    top: AppSpacing.sm,
                    right: 52,
                    child: _CircleBadge(icon: Icons.play_arrow_rounded),
                  ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: FavoriteButton(recipeId: recipe.id),
                ),
                if (showMatchIndicator && matchedIngredients > 0)
                  Positioned(
                    right: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    child: _Badge(
                      icon: Icons.check_circle_outline,
                      label: '$matchedIngredients збіг',
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.title,
                    style: theme.textTheme.titleLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    recipe.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColorsV2.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      _InfoChip(
                        icon: _contentKindIcon(recipe.contentKind),
                        label: _contentKindLabel(recipe.contentKind),
                      ),
                      _InfoChip(
                        icon: Icons.schedule_rounded,
                        label: '${recipe.totalTimeMinutes} хв',
                      ),
                      _InfoChip(
                        icon: Icons.people_outline_rounded,
                        label: '${recipe.servings} порц.',
                      ),
                      _InfoChip(
                        icon: Icons.restaurant_menu_rounded,
                        label: recipe.cuisine,
                      ),
                      _InfoChip(
                        icon: Icons.speed_rounded,
                        label: 'Рівень ${recipe.difficulty}',
                      ),
                    ],
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

String _contentKindLabel(ContentKind kind) => switch (kind) {
      ContentKind.recipe => 'Рецепт',
      ContentKind.technique => 'Техніка',
      ContentKind.process => 'Процес',
      ContentKind.video => 'Відео',
    };

IconData _contentKindIcon(ContentKind kind) => switch (kind) {
      ContentKind.recipe => Icons.restaurant_menu_rounded,
      ContentKind.technique => Icons.auto_awesome_outlined,
      ContentKind.process => Icons.format_list_numbered_rounded,
      ContentKind.video => Icons.play_circle_outline_rounded,
    };

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({this.isLoading = false});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColorsV2.surfaceStrong,
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
          : const Icon(
              Icons.restaurant_menu_rounded,
              size: 44,
              color: AppColorsV2.textSecondary,
            ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColorsV2.textSecondary),
        const SizedBox(width: AppSpacing.xxs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColorsV2.ink.withOpacity(.86),
        borderRadius: AppRadius.sm,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: AppColorsV2.onInk),
            const SizedBox(width: AppSpacing.xxs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColorsV2.onInk,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBadge extends StatelessWidget {
  const _CircleBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColorsV2.ink.withOpacity(.82),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Icon(icon, size: 20, color: AppColorsV2.onInk),
      ),
    );
  }
}
