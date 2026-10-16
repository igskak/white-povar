import 'package:flutter/material.dart';

import '../../../../app/theme/brand_theme.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/branding/brand_assets.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/images/remote_image.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/premium.dart';
import '../../../collections/models/collection.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/presentation/widgets/recipe_card.dart';
import '../../../recipes/presentation/widgets/recipe_photo.dart';
import '../../../recipes/services/cooking_progress_store.dart';
import '../../../search/providers/search_provider.dart';

/// The Home entry points, shared with the Creator Studio live preview (13m).
///
/// The preview renders the app's own widgets rather than a mock, so a change
/// here cannot make the editor and the consumer app disagree.
class ScanBanner extends StatelessWidget {
  const ScanBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onPrimary;
    final background = theme.colorScheme.primary;
    final accent = foreground;

    return Semantics(
      button: true,
      label: 'Сканувати інгредієнти',
      child: Material(
        color: background,
        elevation: AppElevation.level0,
        borderRadius: AppRadius.sm,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 66),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withOpacity(.16),
                      borderRadius: AppRadius.md,
                      border: Border.all(color: accent.withOpacity(.42)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Icon(Icons.photo_camera_outlined,
                          size: 22, color: accent),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Сканувати інгредієнти',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Фото продуктів → рецепти за 10 секунд',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: foreground.withOpacity(.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(Icons.arrow_forward_rounded, color: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The compact Home introduction. It keeps the primary job (choose a recipe)
/// ahead of brand decoration, matching the same quiet hierarchy as desktop.
///
/// Lives here rather than inside `HomePage` because the Studio preview renders
/// this very widget. A section added to Home therefore appears in the editor
/// without a second edit.
class HomeIntro extends StatelessWidget {
  const HomeIntro({
    super.key,
    required this.brand,
    required this.userName,
    required this.onProfileTap,
    required this.onScanTap,
    required this.onTypeTap,
    required this.onQuickFilter,
  });

  final BrandDetails brand;
  final String? userName;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;
  final VoidCallback onTypeTap;
  final ValueChanged<SearchFilters> onQuickFilter;

  @override
  Widget build(BuildContext context) => ResponsiveContainer(
        maxWidth: 680,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrandHeader(
                  brand: brand,
                  trailing: InkResponse(
                    onTap: onProfileTap,
                    radius: 28,
                    child: UserAvatar(name: userName),
                  ),
                ),
                Text(
                  'Що приготуємо сьогодні?',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  brand.voice.greeting.isEmpty
                      ? 'Збережіть ідею для сніданку, вечері або затишного вечора.'
                      : brand.voice.greeting,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.semantic.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                Semantics(
                  button: true,
                  label: 'Знайти рецепт',
                  child: InkWell(
                    key: const ValueKey('home-intro-search'),
                    onTap: onTypeTap,
                    borderRadius: AppRadius.md,
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: context.semantic.surface,
                        border:
                            Border.all(color: context.semantic.outlineVariant),
                        borderRadius: AppRadius.md,
                      ),
                      child: Row(children: [
                        Icon(Icons.search_rounded,
                            color: Theme.of(context).colorScheme.secondary),
                        const SizedBox(width: AppSpacing.sm),
                        Text('Шукати рецепт',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _HomeQuickFilter(
                      label: 'До 30 хв',
                      onTap: () =>
                          onQuickFilter(const SearchFilters(maxTime: 30)),
                    ),
                    _HomeQuickFilter(
                      label: 'Без м’яса',
                      onTap: () => onQuickFilter(
                        const SearchFilters(diet: DietFilter.noMeat),
                      ),
                    ),
                    _HomeQuickFilter(
                      label: 'Сніданки',
                      onTap: () => onQuickFilter(
                          const SearchFilters(category: 'Сніданки')),
                    ),
                    _HomeQuickFilter(
                      label: 'Сканувати',
                      icon: Icons.photo_camera_outlined,
                      onTap: onScanTap,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      );
}

/// The catalogue half of the compact Home: the featured recipe, the course
/// card and the author's feed, in one 480-wide column below [HomeIntro].
class HomeFeedSections extends StatelessWidget {
  const HomeFeedSections({
    super.key,
    required this.brand,
    required this.recipes,
    required this.courseLocked,
    this.courseCollection,
    required this.onOpenRecipe,
    required this.onCollectionTap,
    required this.onUnlockCourse,
    this.cookingProgress,
    this.savedRecipes = const [],
    this.onResumeCooking,
    this.heroAnchorKey,
  });

  final BrandDetails brand;
  final List<Recipe> recipes;
  final bool courseLocked;
  final ContentCollection? courseCollection;
  final ValueChanged<Recipe> onOpenRecipe;
  final VoidCallback onCollectionTap;
  final VoidCallback onUnlockCourse;
  final CookingProgress? cookingProgress;
  final List<Recipe> savedRecipes;
  final ValueChanged<Recipe>? onResumeCooking;
  final Key? heroAnchorKey;

  @override
  Widget build(BuildContext context) {
    final showcase = _showcaseRecipes(recipes);
    final showcaseIds = showcase.map((recipe) => recipe.id).toSet();
    final feed =
        recipes.where((recipe) => !showcaseIds.contains(recipe.id)).toList();
    return ResponsiveContainer(
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(
            key: heroAnchorKey,
            child: _EditorialReveal(
              key: const ValueKey('home-editorial-hero-reveal'),
              debugLabel: 'home-editorial-hero',
              delay: const Duration(milliseconds: 40),
              child: _HomeRecipeShowcase(
                recipes: showcase,
                onOpenRecipe: onOpenRecipe,
              ),
            ),
          ),
          if (brand.voice.courseName != null && brand.courseTag != null) ...[
            const SizedBox(height: AppSpacing.md),
            _EditorialReveal(
              key: const ValueKey('premium-collection-reveal'),
              debugLabel: 'premium-collection',
              delay: const Duration(milliseconds: 120),
              child: BrandCourseCard(
                courseName: brand.voice.courseName!,
                locked: courseLocked,
                collection: courseCollection,
                fallbackRecipes: feed,
                onOpen: onCollectionTap,
                onUnlock: onUnlockCourse,
              ),
            ),
          ],
          HomePersonalizedSections(
            recipes: recipes,
            featuredRecipeId: showcase.first.id,
            cookingProgress: cookingProgress,
            savedRecipes: savedRecipes,
            compact: true,
            onOpenRecipe: onOpenRecipe,
            onResumeCooking: onResumeCooking,
          ),
          if (brand.heroFor('home') != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _DesktopAuthorStory(brand: brand),
          ],
          if (feed.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Свіже від автора',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            _RecipeFeed(recipes: feed, onOpen: onOpenRecipe),
          ],
        ],
      ),
    );
  }
}

/// The desktop Home composition: editorial introduction, featured recipe and
/// the chef's catalogue as a three-column grid.
///
/// It deliberately differs from the compact composition — no brand header or
/// capture banner, because the desktop shell already owns both. The Studio
/// preview renders this same widget under its desktop viewport so the editor
/// shows that difference instead of hiding it.
class HomeDesktopSections extends StatelessWidget {
  const HomeDesktopSections({
    super.key,
    required this.brand,
    required this.recipes,
    required this.courseLocked,
    this.courseCollection,
    required this.onOpenRecipe,
    required this.onSeeAll,
    required this.onQuickFilter,
    required this.onCollectionTap,
    required this.onUnlockCourse,
    this.cookingProgress,
    this.savedRecipes = const [],
    this.onResumeCooking,
    this.heroAnchorKey,
  });

  final BrandDetails brand;
  final List<Recipe> recipes;
  final bool courseLocked;
  final ContentCollection? courseCollection;
  final ValueChanged<Recipe> onOpenRecipe;
  final VoidCallback onSeeAll;
  final ValueChanged<SearchFilters> onQuickFilter;
  final VoidCallback onCollectionTap;
  final VoidCallback onUnlockCourse;
  final CookingProgress? cookingProgress;
  final List<Recipe> savedRecipes;
  final ValueChanged<Recipe>? onResumeCooking;
  final Key? heroAnchorKey;

  /// The page's own vertical margins, shared with the Studio desktop preview
  /// so the editor frames the composition the way the app does.
  static const EdgeInsets pagePadding = EdgeInsets.only(top: 32, bottom: 48);

  @override
  Widget build(BuildContext context) {
    final showcase = _showcaseRecipes(recipes);
    final showcaseIds = showcase.map((recipe) => recipe.id).toSet();
    final feed =
        recipes.where((item) => !showcaseIds.contains(item.id)).toList();
    return ResponsiveContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KeyedSubtree(
            key: heroAnchorKey,
            child: _EditorialReveal(
              key: const ValueKey('home-editorial-hero-reveal'),
              debugLabel: 'home-editorial-hero',
              delay: const Duration(milliseconds: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DesktopHomeIntro(
                    brand: brand,
                    onSearch: onSeeAll,
                    onQuickFilter: onQuickFilter,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _HomeRecipeShowcase(
                    recipes: showcase,
                    onOpenRecipe: onOpenRecipe,
                  ),
                ],
              ),
            ),
          ),
          if (brand.voice.courseName != null && brand.courseTag != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _EditorialReveal(
              key: const ValueKey('premium-collection-reveal'),
              debugLabel: 'premium-collection',
              delay: const Duration(milliseconds: 120),
              child: BrandCourseCard(
                courseName: brand.voice.courseName!,
                locked: courseLocked,
                collection: courseCollection,
                fallbackRecipes: feed,
                onOpen: onCollectionTap,
                onUnlock: onUnlockCourse,
              ),
            ),
          ],
          HomePersonalizedSections(
            recipes: recipes,
            featuredRecipeId: showcase.first.id,
            cookingProgress: cookingProgress,
            savedRecipes: savedRecipes,
            onOpenRecipe: onOpenRecipe,
            onResumeCooking: onResumeCooking,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (brand.heroFor('home') != null) ...[
            _DesktopAuthorStory(brand: brand),
            const SizedBox(height: AppSpacing.xl),
          ],
          Divider(color: context.semantic.outlineVariant),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text('Від шефа',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        )),
              ),
              TextButton.icon(
                onPressed: onSeeAll,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Усі рецепти'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: constraints.maxWidth >= 1180 ? 4 : 3,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                mainAxisExtent: RecipeCard.gridMainAxisExtent(
                  availableWidth: constraints.maxWidth,
                  columns: constraints.maxWidth >= 1180 ? 4 : 3,
                ),
              ),
              itemCount: feed.length,
              itemBuilder: (context, index) => RecipeCard(
                recipe: feed[index],
                onTap: () => onOpenRecipe(feed[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<Recipe> _showcaseRecipes(List<Recipe> recipes) {
  final featured = recipes.firstWhere(
    (recipe) => recipe.isFeatured,
    orElse: () => recipes.first,
  );
  return [
    featured,
    ...recipes.where((recipe) => recipe.id != featured.id),
  ].take(3).toList();
}

class _HomeQuickFilter extends StatelessWidget {
  const _HomeQuickFilter({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: icon == null ? null : Icon(icon, size: 17),
        label: Text(label),
        onPressed: onTap,
      );
}

class _DesktopHomeIntro extends StatelessWidget {
  const _DesktopHomeIntro({
    required this.brand,
    required this.onSearch,
    required this.onQuickFilter,
  });

  final BrandDetails brand;
  final VoidCallback onSearch;
  final ValueChanged<SearchFilters> onQuickFilter;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Що приготуємо сьогодні?',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontFamily: AppFonts.body,
                        fontWeight: FontWeight.w600,
                        fontSize: 34,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  brand.voice.greeting.isEmpty
                      ? 'Ідеї для вашої кухні — без зайвого шуму.'
                      : brand.voice.greeting,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.semantic.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(spacing: AppSpacing.xs, children: [
                  _HomeQuickFilter(
                    label: 'До 30 хв',
                    onTap: () =>
                        onQuickFilter(const SearchFilters(maxTime: 30)),
                  ),
                  _HomeQuickFilter(
                    label: 'Без м’яса',
                    onTap: () => onQuickFilter(
                      const SearchFilters(diet: DietFilter.noMeat),
                    ),
                  ),
                  _HomeQuickFilter(
                    label: 'Сніданки',
                    onTap: () => onQuickFilter(
                        const SearchFilters(category: 'Сніданки')),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          SizedBox(
            width: 290,
            child: OutlinedButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search_rounded),
              label: const Align(
                alignment: Alignment.centerLeft,
                child: Text('Шукати рецепт'),
              ),
            ),
          ),
        ],
      );
}

/// First-screen recipe trio. The lead card is allowed more width, but all
/// cards remain the existing role-aware [RecipeCard] with real save behavior.
class _HomeRecipeShowcase extends StatelessWidget {
  const _HomeRecipeShowcase(
      {required this.recipes, required this.onOpenRecipe});

  final List<Recipe> recipes;
  final ValueChanged<Recipe> onOpenRecipe;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700 && recipes.length > 1;
          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RecipeCard(
                  key: ValueKey('home-showcase-${recipes.first.id}'),
                  recipe: recipes.first,
                  onTap: () => onOpenRecipe(recipes.first),
                ),
                if (recipes.length > 1) ...[
                  const SizedBox(height: AppSpacing.md),
                  Row(children: [
                    for (var index = 1; index < recipes.length; index++) ...[
                      if (index > 1) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: RecipeCard(
                          key: ValueKey('home-showcase-${recipes[index].id}'),
                          recipe: recipes[index],
                          onTap: () => onOpenRecipe(recipes[index]),
                        ),
                      ),
                    ],
                  ]),
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 145,
                child: RecipeCard(
                  key: ValueKey('home-showcase-${recipes.first.id}'),
                  recipe: recipes.first,
                  onTap: () => onOpenRecipe(recipes.first),
                ),
              ),
              for (var index = 1; index < recipes.length; index++) ...[
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 100,
                  child: RecipeCard(
                    key: ValueKey('home-showcase-${recipes[index].id}'),
                    recipe: recipes[index],
                    onTap: () => onOpenRecipe(recipes[index]),
                  ),
                ),
              ],
            ],
          );
        },
      );
}

/// Home modules assembled only from signals the product already owns: the
/// local cooking snapshot, account favorites and recipe duration metadata.
class HomePersonalizedSections extends StatelessWidget {
  const HomePersonalizedSections({
    super.key,
    required this.recipes,
    required this.onOpenRecipe,
    this.cookingProgress,
    this.savedRecipes = const [],
    this.onResumeCooking,
    this.compact = false,
    this.featuredRecipeId,
  });

  final List<Recipe> recipes;
  final CookingProgress? cookingProgress;
  final List<Recipe> savedRecipes;
  final ValueChanged<Recipe> onOpenRecipe;
  final ValueChanged<Recipe>? onResumeCooking;
  final bool compact;
  final String? featuredRecipeId;

  @override
  Widget build(BuildContext context) {
    final resolvedProgress = _resolvedProgress();
    final activeId = resolvedProgress?.recipe.id;
    final seenSaved = <String>{};
    final visibleSaved = savedRecipes
        .where((recipe) => recipe.id != activeId && seenSaved.add(recipe.id))
        .take(3)
        .toList();
    final savedIds = visibleSaved.map((recipe) => recipe.id).toSet();
    final quickRecipes = recipes
        .where((recipe) =>
            recipe.totalTimeMinutes > 0 &&
            recipe.totalTimeMinutes <= 30 &&
            !recipe.isLocked &&
            !savedIds.contains(recipe.id) &&
            recipe.id != featuredRecipeId &&
            recipe.id != activeId)
        .take(3)
        .toList();
    if (resolvedProgress == null &&
        quickRecipes.isEmpty &&
        visibleSaved.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      key: const ValueKey('home-personalized-sections'),
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ДЛЯ ВАС СЬОГОДНІ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Оберіть, що приготувати далі',
            style: (compact
                    ? Theme.of(context).textTheme.headlineSmall
                    : Theme.of(context).textTheme.headlineMedium)
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (resolvedProgress != null) ...[
            const SizedBox(height: AppSpacing.md),
            _ResumeCookingCard(
              progress: resolvedProgress,
              onTap: onResumeCooking == null
                  ? null
                  : () => onResumeCooking!(resolvedProgress.recipe),
            ),
          ],
          if (quickRecipes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _PersonalizedRecipeShelf(
              key: const ValueKey('home-quick-recipe-shelf'),
              title: 'Встигнете за 30 хвилин',
              subtitle: 'Короткий сценарій для буднього вечора',
              recipes: quickRecipes,
              onOpen: onOpenRecipe,
            ),
          ],
          if (visibleSaved.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _PersonalizedRecipeShelf(
              key: const ValueKey('home-saved-recipe-shelf'),
              title: 'Зі збереженого',
              subtitle: 'Рецепти, до яких ви хотіли повернутися',
              recipes: visibleSaved,
              onOpen: onOpenRecipe,
            ),
          ],
        ],
      ),
    );
  }

  CookingProgress? _resolvedProgress() {
    final stored = cookingProgress;
    if (stored == null) return null;
    for (final recipe in recipes) {
      if (recipe.id == stored.recipe.id) {
        return CookingProgress(
          recipe: recipe,
          step: stored.step,
          updatedAt: stored.updatedAt,
          timerEndsAt: stored.timerEndsAt,
        );
      }
    }
    return stored;
  }
}

class _ResumeCookingCard extends StatelessWidget {
  const _ResumeCookingCard({required this.progress, this.onTap});

  final CookingProgress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final recipe = progress.recipe;
    final totalSteps =
        recipe.instructions.isEmpty ? 1 : recipe.instructions.length;
    final currentStep = (progress.step + 1).clamp(1, totalSteps);
    final value = currentStep / totalSteps;
    return ContentCard(
      key: const ValueKey('home-resume-cooking'),
      onTap: onTap,
      semanticLabel: 'Продовжити готувати ${recipe.title}, '
          'крок $currentStep з $totalSteps',
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          SizedBox(
            width: 104,
            height: 88,
            child: ClipRRect(
              borderRadius: AppRadius.md,
              child: RecipePhoto(
                recipe: recipe,
                role: RecipeImageRole.list,
                targetWidth: 160,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Продовжити готувати',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  recipe.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: value,
                    minHeight: 5,
                    backgroundColor: context.semantic.surfaceStrong,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Крок $currentStep з $totalSteps',
                  style: context.semantic.dataLabel,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.arrow_forward_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

class _PersonalizedRecipeShelf extends StatelessWidget {
  const _PersonalizedRecipeShelf({
    super.key,
    required this.title,
    required this.subtitle,
    required this.recipes,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final List<Recipe> recipes;
  final ValueChanged<Recipe> onOpen;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: context.semantic.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 700) {
                return Row(
                  children: [
                    for (var index = 0; index < recipes.length; index++) ...[
                      if (index > 0) const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _ShelfRecipeCard(
                          recipe: recipes[index],
                          onTap: () => onOpen(recipes[index]),
                        ),
                      ),
                    ],
                  ],
                );
              }
              return SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recipes.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) => SizedBox(
                    width: 284,
                    child: _ShelfRecipeCard(
                      recipe: recipes[index],
                      onTap: () => onOpen(recipes[index]),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      );
}

class _ShelfRecipeCard extends StatelessWidget {
  const _ShelfRecipeCard({required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 104,
        child: ContentCard(
          onTap: onTap,
          semanticLabel: 'Відкрити рецепт ${recipe.title}',
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: ClipRRect(
                  borderRadius: AppRadius.md,
                  child: RecipePhoto(
                    recipe: recipe,
                    role: RecipeImageRole.list,
                    targetWidth: 140,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${recipe.totalTimeMinutes} хв  ·  ${recipe.category}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.semantic.dataLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.arrow_outward_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
        ),
      );
}

/// A one-shot editorial entrance that starts only when its section approaches
/// the viewport. It never changes layout or scroll position, and becomes a
/// plain child when the platform requests reduced motion.
class _EditorialReveal extends StatefulWidget {
  const _EditorialReveal({
    super.key,
    required this.debugLabel,
    required this.child,
    this.delay = Duration.zero,
  });

  final String debugLabel;
  final Widget child;
  final Duration delay;

  @override
  State<_EditorialReveal> createState() => _EditorialRevealState();
}

class _EditorialRevealState extends State<_EditorialReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  ScrollPosition? _scrollPosition;
  bool _played = false;
  bool _checkScheduled = false;

  @override
  void initState() {
    super.initState();
    final totalDuration = const Duration(milliseconds: 520) + widget.delay;
    final revealStart =
        widget.delay.inMicroseconds / totalDuration.inMicroseconds;
    _controller = AnimationController(
      vsync: this,
      duration: totalDuration,
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(revealStart, 1, curve: Curves.easeOutCubic),
    );
    _opacity = curve;
    _offset = Tween<Offset>(
      begin: const Offset(0, .035),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (_scrollPosition != nextPosition) {
      _scrollPosition?.removeListener(_scheduleVisibilityCheck);
      _scrollPosition = nextPosition;
      _scrollPosition?.addListener(_scheduleVisibilityCheck);
    }

    if (MediaQuery.disableAnimationsOf(context)) {
      _played = true;
      _controller.value = 1;
    } else {
      _scheduleVisibilityCheck();
    }
  }

  void _scheduleVisibilityCheck() {
    if (_played || _checkScheduled || !mounted) return;
    _checkScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScheduled = false;
      if (mounted) _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (_played || MediaQuery.disableAnimationsOf(context)) return;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;

    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    final viewportHeight = MediaQuery.sizeOf(context).height;
    const approachDistance = 72.0;
    if (top <= viewportHeight + approachDistance &&
        bottom >= -approachDistance) {
      _played = true;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_scheduleVisibilityCheck);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return RepaintBoundary(
      child: FadeTransition(
        key: ValueKey('${widget.debugLabel}-fade'),
        opacity: _opacity,
        child: SlideTransition(
          position: _offset,
          child: widget.child,
        ),
      ),
    );
  }
}

class _DesktopAuthorStory extends StatelessWidget {
  const _DesktopAuthorStory({required this.brand});

  final BrandDetails brand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semantic;
    return Semantics(
      label: 'Про автора ${brand.name}',
      child: Container(
        key: const ValueKey('desktop-author-story'),
        decoration: BoxDecoration(
          color: semantic.surface,
          border: Border.all(color: semantic.outlineVariant),
          borderRadius: AppRadius.md,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 520;
            final photo = SizedBox(
              width: stacked ? double.infinity : 200,
              height: stacked
                  ? constraints.maxWidth / BrandMediaAspectRatio.homeAuthor
                  : 100,
              child: ClipRRect(
                borderRadius: stacked
                    ? const BorderRadius.vertical(top: Radius.circular(12))
                    : const BorderRadius.horizontal(left: Radius.circular(12)),
                child: BrandHero(
                  key: const ValueKey('desktop-author-photo'),
                  brand: brand,
                  role: 'home',
                  targetWidth: stacked ? constraints.maxWidth : 200,
                ),
              ),
            );
            final copy = Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ПРО АВТОРА',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      )),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(brand.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontFamily: context.brandTheme.displayFontFamily,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: AppSpacing.xxs),
                  Text('Особиста добірка страв, перевірених на власній кухні.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: semantic.textSecondary,
                      )),
                ],
              ),
            );
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [photo, copy])
                : Row(children: [photo, Expanded(child: copy)]);
          },
        ),
      ),
    );
  }
}

class _RecipeFeed extends StatelessWidget {
  const _RecipeFeed({required this.recipes, required this.onOpen});
  final List<Recipe> recipes;
  final ValueChanged<Recipe> onOpen;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final recipe in recipes) ...[
            RecipeCard.list(recipe: recipe, onTap: () => onOpen(recipe)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
}

/// Editorial storefront for the brand's featured collection. It previews the
/// real collection whenever its detail has loaded, then falls back to the
/// published recipe feed so Home never collapses into a generic paywall box.
class BrandCourseCard extends StatefulWidget {
  const BrandCourseCard({
    super.key,
    required this.courseName,
    required this.locked,
    required this.onOpen,
    required this.onUnlock,
    this.collection,
    this.fallbackRecipes = const [],
  });

  final String courseName;
  final bool locked;
  final VoidCallback onOpen;
  final VoidCallback onUnlock;
  final ContentCollection? collection;
  final List<Recipe> fallbackRecipes;

  @override
  State<BrandCourseCard> createState() => _BrandCourseCardState();
}

class _BrandCourseCardState extends State<BrandCourseCard> {
  bool _activating = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.collection?.title.trim().isNotEmpty == true
        ? widget.collection!.title
        : widget.courseName;
    final description = widget.collection?.description.trim().isNotEmpty == true
        ? widget.collection!.description
        : 'Авторські рецепти й практичні матеріали, зібрані в одну програму.';
    final isLocked = widget.collection?.isLocked ?? widget.locked;
    final previews = _previewRecipes();

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 760;
        final content = _CourseShowcaseCopy(
          title: title,
          description: description,
          itemCount: widget.collection?.itemCount,
          locked: isLocked,
          compact: !desktop,
          activating: _activating,
        );
        final media = _CoursePreviewMosaic(
          title: title,
          coverUrl: widget.collection?.coverUrl,
          recipes: previews,
        );

        return ContentCard(
          key: const ValueKey('premium-collection-showcase'),
          onTap: _activating ? null : () => _activate(isLocked),
          variant: ContentCardVariant.raised,
          semanticLabel: isLocked
              ? 'Відкрити Premium для колекції $title'
              : 'Відкрити колекцію $title',
          padding: EdgeInsets.zero,
          child: desktop
              ? SizedBox(
                  height: 252,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 6, child: content),
                      Expanded(flex: 5, child: media),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: 176, child: media),
                    content,
                  ],
                ),
        );
      },
    );
  }

  List<Recipe> _previewRecipes() {
    final candidates = [
      ...?widget.collection?.items.map((item) => item.content),
      ...widget.fallbackRecipes,
    ];
    final seen = <String>{};
    return candidates.where((recipe) => seen.add(recipe.id)).take(3).toList();
  }

  Future<void> _activate(bool isLocked) async {
    if (_activating) return;
    setState(() => _activating = true);
    if (!MediaQuery.disableAnimationsOf(context)) {
      await Future<void>.delayed(const Duration(milliseconds: 160));
    }
    if (!mounted) return;
    (isLocked ? widget.onUnlock : widget.onOpen)();
    if (mounted) setState(() => _activating = false);
  }
}

class _CourseShowcaseCopy extends StatelessWidget {
  const _CourseShowcaseCopy({
    required this.title,
    required this.description,
    required this.itemCount,
    required this.locked,
    required this.compact,
    required this.activating,
  });

  final String title;
  final String description;
  final int? itemCount;
  final bool locked;
  final bool compact;
  final bool activating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final onAccent = theme.colorScheme.onPrimary;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PremiumBadge(size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'ПРЕМІАЛЬНА КОЛЕКЦІЯ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: context.brandTheme.displayFontFamily,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.semantic.textSecondary,
            ),
          ),
          if (compact)
            const SizedBox(height: AppSpacing.lg)
          else
            const Spacer(),
          if (itemCount != null && itemCount! > 0) ...[
            Text(
              '$itemCount матеріалів у колекції',
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.semantic.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          AnimatedContainer(
            key: const ValueKey('premium-collection-cta'),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : AppMotion.fast,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: AppRadius.sm,
            ),
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppMotion.fast,
              child: Row(
                key: ValueKey(activating),
                children: [
                  Icon(
                    activating
                        ? Icons.hourglass_top_rounded
                        : locked
                            ? Icons.workspace_premium_outlined
                            : Icons.collections_bookmark_outlined,
                    size: 19,
                    color: onAccent,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      activating
                          ? 'Відкриваємо…'
                          : locked
                              ? 'Відкрити Premium'
                              : 'Відкрити майстерню',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: onAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    activating
                        ? Icons.more_horiz_rounded
                        : Icons.arrow_forward_rounded,
                    size: 20,
                    color: onAccent,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursePreviewMosaic extends StatelessWidget {
  const _CoursePreviewMosaic({
    required this.title,
    required this.coverUrl,
    required this.recipes,
  });

  final String title;
  final String? coverUrl;
  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (coverUrl != null && coverUrl!.isNotEmpty)
        Semantics(
          image: true,
          label: 'Обкладинка колекції $title',
          child: RemoteImage(
            url: coverUrl!,
            targetWidth: 720,
            errorWidget: _CoursePreviewFallback(title: title),
          ),
        ),
      for (final recipe in recipes) RecipeImageFallback.wrap(recipe),
    ].take(3).toList();

    if (tiles.isEmpty) return _CoursePreviewFallback(title: title);
    if (tiles.length == 1) return tiles.first;

    return RepaintBoundary(
      key: const ValueKey('premium-collection-preview'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 6, child: tiles.first),
          const SizedBox(width: 4),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[1]),
                if (tiles.length > 2) ...[
                  const SizedBox(height: 4),
                  Expanded(child: tiles[2]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoursePreviewFallback extends StatelessWidget {
  const _CoursePreviewFallback({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'Колекція $title',
        child: ColoredBox(
          color: context.semantic.surfaceStrong,
          child: Center(
            child: Icon(
              Icons.collections_bookmark_outlined,
              size: 52,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      );
}
