import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/brand_theme.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/premium.dart';
import '../../models/recipe.dart';
import 'favorite_button.dart';
import 'recipe_photo.dart';

/// How a recipe is presented. One implementation backs every surface so Home,
/// Discover, Saved and the camera results cannot drift apart.
enum RecipeCardVariant {
  /// Open editorial tile with a 4:3 image and a compact metadata line.
  grid,

  /// Dense row with an 84×84 thumbnail — the Home/Saved feed.
  list,

  /// Editorial hero for the recommended recipe.
  featured,
}

class RecipeCard extends ConsumerWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.showMatchIndicator = false,
    this.matchedIngredients = 0,
    this.variant = RecipeCardVariant.grid,
    this.compact = false,
  });

  const RecipeCard.list({
    super.key,
    required this.recipe,
    this.onTap,
  })  : variant = RecipeCardVariant.list,
        showMatchIndicator = false,
        matchedIngredients = 0,
        compact = false;

  const RecipeCard.featured({
    super.key,
    required this.recipe,
    this.onTap,
    this.compact = false,
  })  : variant = RecipeCardVariant.featured,
        showMatchIndicator = false,
        matchedIngredients = 0;

  final Recipe recipe;
  final VoidCallback? onTap;
  final bool showMatchIndicator;
  final int matchedIngredients;
  final RecipeCardVariant variant;

  /// Tightens the featured hero for constrained columns.
  final bool compact;

  /// Exact grid height for the open editorial tile: a 4:3 photograph plus
  /// enough room for a two-line title and its metadata. Keeping this formula
  /// beside the card prevents individual grids from reserving obsolete empty
  /// space with unrelated aspect ratios.
  static double gridMainAxisExtent({
    required double availableWidth,
    required int columns,
    double spacing = AppSpacing.md,
  }) {
    final imageWidth = (availableWidth - spacing * (columns - 1)) / columns;
    return imageWidth * 3 / 4 + 96;
  }

  /// Placeholder shown while a feed loads (Handoff §3: shimmer 1.4 s).
  static Widget skeleton(
          {RecipeCardVariant variant = RecipeCardVariant.grid}) =>
      switch (variant) {
        RecipeCardVariant.featured =>
          const AppSkeleton(height: 340, borderRadius: AppRadius.xl),
        RecipeCardVariant.list =>
          const AppSkeleton(height: 104, borderRadius: AppRadius.lg),
        RecipeCardVariant.grid =>
          const AppSkeleton(height: 260, borderRadius: AppRadius.lg),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (variant) {
        RecipeCardVariant.grid => _buildGrid(context),
        RecipeCardVariant.list => _buildList(context),
        RecipeCardVariant.featured => _buildFeatured(context),
      };

  Widget _buildGrid(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semantic;
    final label =
        'Відкрити ${_contentKindLabel(recipe.contentKind)} ${recipe.title}';

    return Semantics(
      button: onTap != null,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.sm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 3,
                    child: RecipeImageHero(
                      recipeId: recipe.id,
                      borderRadius: AppRadius.sm,
                      child: RecipeImageFallback.wrap(
                        recipe,
                        role: RecipeImageRole.grid,
                      ),
                    ),
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
                      child: _ScrimBadge(
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
                      child: _ScrimBadge(
                        icon: Icons.check_circle_outline,
                        label: '$matchedIngredients збіг',
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.xs,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${recipe.totalTimeMinutes} хв  ·  ${recipe.cuisine}',
                      style: semantic.dataLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final theme = Theme.of(context);
    return ContentCard(
      onTap: onTap,
      semanticLabel: 'Відкрити рецепт ${recipe.title}',
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          RecipeImageHero(
            recipeId: recipe.id,
            borderRadius: AppRadius.md,
            child: RecipeImageFallback(
              recipe: recipe,
              width: 84,
              height: 84,
              role: RecipeImageRole.list,
              borderRadius: BorderRadius.zero,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                MetaChip(
                  icon: Icons.schedule_rounded,
                  label: '${recipe.totalTimeMinutes} хв · ${recipe.cuisine}',
                ),
              ],
            ),
          ),
          if (recipe.isPremium) const PremiumIndicator(isPremium: true),
          FavoriteButton(recipeId: recipe.id),
        ],
      ),
    );
  }

  Widget _buildFeatured(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Відкрити рекомендований рецепт ${recipe.title}',
      child: LayoutBuilder(
        builder: (context, constraints) =>
            !compact && constraints.maxWidth >= 900
                ? _featuredDesktop(context, constraints.maxWidth)
                : _featuredMobile(context),
      ),
    );
  }

  Widget _featuredDesktop(BuildContext context, double width) {
    final height = (width * .4).clamp(360.0, 472.0);
    return ClipRRect(
      borderRadius: AppRadius.xl,
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColorsV2.ink),
            RecipeImageHero(
              recipeId: recipe.id,
              borderRadius: AppRadius.xl,
              child: RecipePhoto(
                recipe: recipe,
                role: RecipeImageRole.featured,
                targetWidth: width,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColorsV2.ink.withOpacity(.96),
                    AppColorsV2.ink.withOpacity(.74),
                    AppColorsV2.ink.withOpacity(.20),
                    Colors.transparent,
                  ],
                  stops: const [0, .34, .68, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(40),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: width * .44),
                  child: _featuredCopy(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featuredMobile(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.sm,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: AppRadius.sm,
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RecipeImageHero(
                      recipeId: recipe.id,
                      child: RecipePhoto(
                        recipe: recipe,
                        role: RecipeImageRole.featured,
                        targetWidth: 480,
                      ),
                    ),
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        child: AppBadge(
                          label: 'Вибір шефа',
                          icon: Icons.local_fire_department_outlined,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '${recipe.totalTimeMinutes} хв  ·  ${recipe.servings} порції',
                        style: context.semantic.dataBody,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                FavoriteButton(recipeId: recipe.id),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _featuredCopy(BuildContext context, {bool mobile = false}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const AppBadge(
          label: 'Рекомендоване',
          icon: Icons.local_fire_department_outlined,
          color: AppColorsV2.premiumGold,
        ),
        SizedBox(height: mobile ? AppSpacing.sm : AppSpacing.md),
        Text(
          recipe.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineLarge?.copyWith(
            color: AppColorsV2.onInk,
            fontFamily: context.brandTheme.displayFontFamily,
            fontWeight: FontWeight.w700,
            height: 1.05,
            fontSize: mobile ? 26 : null,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${recipe.totalTimeMinutes} хв  ·  ${recipe.cuisine}'
          '${mobile ? '' : '  ·  Рівень ${recipe.difficulty}'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (mobile ? theme.textTheme.bodyMedium : theme.textTheme.bodyLarge)
                  ?.copyWith(color: AppColorsV2.onInk),
        ),
        SizedBox(height: mobile ? AppSpacing.sm : AppSpacing.lg),
        ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.restaurant_menu_rounded),
          label: const Text('Почати готувати'),
        ),
      ],
    );
  }
}

String _contentKindLabel(ContentKind kind) => switch (kind) {
      ContentKind.recipe => 'Рецепт',
      ContentKind.technique => 'Техніка',
      ContentKind.process => 'Процес',
      ContentKind.video => 'Відео',
    };

/// Recipe imagery with the design's fallback: surfaceStrong + restaurant icon.
class RecipeImageFallback extends StatelessWidget {
  const RecipeImageFallback({
    super.key,
    required this.recipe,
    this.width,
    this.height,
    this.role = RecipeImageRole.primary,
    this.borderRadius = AppRadius.md,
  });

  final Recipe recipe;
  final double? width;
  final double? height;
  final RecipeImageRole role;
  final BorderRadius borderRadius;

  /// Fills the parent (used inside an [AspectRatio] or [Stack]).
  static Widget wrap(
    Recipe recipe, {
    RecipeImageRole role = RecipeImageRole.primary,
  }) =>
      RecipePhoto(recipe: recipe, role: role);

  @override
  Widget build(BuildContext context) => RecipePhoto(
        recipe: recipe,
        role: role,
        width: width,
        height: height,
        targetWidth: width,
        borderRadius: borderRadius,
      );
}

/// Badge painted on top of photography, where ink/onInk are correct in both
/// themes because the backdrop is the image, not the surface.
class _ScrimBadge extends StatelessWidget {
  const _ScrimBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
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

class _CircleBadge extends StatelessWidget {
  const _CircleBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
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
