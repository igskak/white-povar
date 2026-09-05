import 'package:flutter/material.dart';

import '../../../../app/theme/brand_theme.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/branding/brand_assets.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/premium.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/presentation/widgets/recipe_card.dart';
import '../../../recipes/presentation/widgets/recipe_photo.dart';

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

/// The intro block of the compact Home: brand header, editorial greeting and
/// the two capture entry points.
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
  });

  final BrandDetails brand;
  final String? userName;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;
  final VoidCallback onTypeTap;

  @override
  Widget build(BuildContext context) => ResponsiveContainer(
        maxWidth: 480,
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
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'АВТОРСЬКА КУХНЯ',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  brand.voice.greeting,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontFamily: context.brandTheme.displayFontFamily,
                        fontWeight: FontWeight.w600,
                        height: 1.02,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Улюблені рецепти. З увагою до деталей.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: context.semantic.textSecondary,
                      ),
                ),
                if (brand.heroFor('home') != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  BrandHeroBanner(
                    key: const ValueKey('home-brand-hero'),
                    brand: brand,
                    role: 'home',
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                ScanBanner(onTap: onScanTap),
                const SizedBox(height: AppSpacing.xs),
                // Secondary path for anyone who would rather type than shoot.
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: 'Ввести вручну',
                    icon: Icons.keyboard_alt_outlined,
                    variant: AppButtonVariant.text,
                    onPressed: onTypeTap,
                  ),
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
    required this.onOpenRecipe,
    required this.onCollectionTap,
    required this.onUnlockCourse,
  });

  final BrandDetails brand;
  final List<Recipe> recipes;
  final bool courseLocked;
  final ValueChanged<Recipe> onOpenRecipe;
  final VoidCallback onCollectionTap;
  final VoidCallback onUnlockCourse;

  @override
  Widget build(BuildContext context) {
    final featured = recipes.firstWhere(
      (recipe) => recipe.isFeatured,
      orElse: () => recipes.first,
    );
    final feed = recipes.where((recipe) => recipe.id != featured.id).toList();
    return ResponsiveContainer(
      maxWidth: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecipeCard.featured(
            key: const ValueKey('mobile-featured-recipe-hero'),
            recipe: featured,
            compact: true,
            onTap: () => onOpenRecipe(featured),
          ),
          if (brand.voice.courseName != null && brand.courseTag != null) ...[
            const SizedBox(height: AppSpacing.md),
            BrandCourseCard(
              courseName: brand.voice.courseName!,
              locked: courseLocked,
              onOpen: onCollectionTap,
              onUnlock: onUnlockCourse,
            ),
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
    required this.onOpenRecipe,
    required this.onSeeAll,
    required this.onCollectionTap,
    required this.onUnlockCourse,
  });

  final BrandDetails brand;
  final List<Recipe> recipes;
  final bool courseLocked;
  final ValueChanged<Recipe> onOpenRecipe;
  final VoidCallback onSeeAll;
  final VoidCallback onCollectionTap;
  final VoidCallback onUnlockCourse;

  /// The page's own vertical margins, shared with the Studio desktop preview
  /// so the editor frames the composition the way the app does.
  static const EdgeInsets pagePadding = EdgeInsets.only(top: 32, bottom: 48);

  @override
  Widget build(BuildContext context) {
    final featured = recipes.firstWhere(
      (recipe) => recipe.isFeatured,
      orElse: () => recipes.first,
    );
    final feed = recipes.where((item) => item.id != featured.id).toList();
    return ResponsiveContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BordeauxDesktopHero(
            brand: brand,
            recipe: featured,
            onTap: () => onOpenRecipe(featured),
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
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: .82,
            ),
            itemCount: feed.length,
            itemBuilder: (context, index) => RecipeCard(
              recipe: feed[index],
              onTap: () => onOpenRecipe(feed[index]),
            ),
          ),
          if (brand.voice.courseName != null && brand.courseTag != null) ...[
            const SizedBox(height: AppSpacing.xl),
            BrandCourseCard(
              courseName: brand.voice.courseName!,
              locked: courseLocked,
              onOpen: onCollectionTap,
              onUnlock: onUnlockCourse,
            ),
          ],
        ],
      ),
    );
  }
}

class _BordeauxDesktopHero extends StatelessWidget {
  const _BordeauxDesktopHero({
    required this.brand,
    required this.recipe,
    required this.onTap,
  });

  final BrandDetails brand;
  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semantic;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: semantic.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: (constraints.maxWidth * .36).clamp(390.0, 520.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _DesktopAuthorSignature(brand: brand),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'АВТОРСЬКА КУХНЯ',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _EditorialGreeting(text: brand.voice.greeting),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Улюблені рецепти. З увагою до деталей.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: semantic.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ElevatedButton.icon(
                        onPressed: onTap,
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Обрати рецепт'),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Semantics(
                  button: true,
                  label: 'Відкрити рецепт ${recipe.title}',
                  child: Material(
                    color: semantic.surfaceStrong,
                    child: InkWell(
                      onTap: onTap,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RecipePhoto(
                            key: const ValueKey('featured-recipe-hero'),
                            recipe: recipe,
                            role: RecipeImageRole.featured,
                            targetWidth: constraints.maxWidth * .6,
                          ),
                          Align(
                            alignment: Alignment.bottomLeft,
                            child: Container(
                              width: constraints.maxWidth * .42,
                              constraints: const BoxConstraints(minWidth: 260),
                              color: theme.colorScheme.primary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg,
                                vertical: AppSpacing.md,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          recipe.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.xxs),
                                        Text(
                                          '${recipe.totalTimeMinutes} хв',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme.onPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Icon(Icons.arrow_forward_rounded,
                                      color: theme.colorScheme.onPrimary),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopAuthorSignature extends StatelessWidget {
  const _DesktopAuthorSignature({required this.brand});

  final BrandDetails brand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      key: const ValueKey('desktop-author-signature'),
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandAvatar(
          key: const ValueKey('desktop-author-avatar'),
          brand: brand,
          radius: 22,
        ),
        const SizedBox(width: AppSpacing.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              brand.creatorName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontFamily: context.brandTheme.displayFontFamily,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Автор рецептів',
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.semantic.textSecondary,
              ),
            ),
          ],
        ),
      ],
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
        height: 280,
        decoration: BoxDecoration(
          color: semantic.surface,
          border: Border.all(color: semantic.outlineVariant),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) => Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: BrandHero(
                  key: const ValueKey('desktop-author-photo'),
                  brand: brand,
                  role: 'home',
                  targetWidth: constraints.maxWidth * 5 / 12,
                ),
              ),
              Expanded(
                flex: 7,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ЗНАЙОМТЕСЯ З АВТОРОМ',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        brand.name,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontFamily: context.brandTheme.displayFontFamily,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Особиста добірка страв, перевірених на власній кухні.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: semantic.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorialGreeting extends StatelessWidget {
  const _EditorialGreeting({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final split = text.split('—');
    final base = theme.textTheme.headlineLarge?.copyWith(
      fontFamily: context.brandTheme.displayFontFamily,
      fontSize: 52,
      fontWeight: FontWeight.w600,
      height: .98,
    );
    if (split.length != 2) return Text(text, maxLines: 3, style: base);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${split.first.trim()} —\n', style: base),
          TextSpan(
            text: split.last.trim(),
            style: base?.copyWith(
              color: theme.colorScheme.secondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
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

/// Brand course card (13g). Hidden when the brand publishes no course;
/// locked for guests and free users; active for premium.
class BrandCourseCard extends StatelessWidget {
  const BrandCourseCard({
    super.key,
    required this.courseName,
    required this.locked,
    required this.onOpen,
    required this.onUnlock,
  });

  final String courseName;
  final bool locked;
  final VoidCallback onOpen;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return PremiumGateCard(
        title: courseName,
        message: 'Авторський курс від шефа доступний у Premium.',
        ctaLabel: 'Відкрити Premium',
        onUnlock: onUnlock,
      );
    }
    return ContentCard(
      onTap: onOpen,
      semanticLabel: 'Відкрити колекцію $courseName',
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: AppColorsV2.premiumGold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Premium-колекція',
                    style: Theme.of(context).textTheme.labelLarge),
                Text(courseName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    );
  }
}
