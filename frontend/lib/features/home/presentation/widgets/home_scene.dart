import 'package:flutter/material.dart';

import '../../../../app/theme/brand_theme.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/branding/brand_assets.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/premium.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/presentation/widgets/recipe_card.dart';

/// The Home entry points, shared with the Creator Studio live preview (13m).
///
/// The preview renders the app's own widgets rather than a mock, so a change
/// here cannot make the editor and the consumer app disagree.
class ScanBanner extends StatelessWidget {
  const ScanBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ContentCard(
        onTap: onTap,
        semanticLabel: 'Сканувати інгредієнти',
        child: Row(
          children: [
            const Icon(Icons.photo_camera_outlined),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Сканувати інгредієнти',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text('Фото продуктів → рецепти за 10 секунд',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      );
}

/// The intro block of the compact Home: brand header, the photo the tenant
/// published for Home, the greeting and the two capture entry points.
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
                // The brand's own photo, when it published one for Home.
                if (brand.heroFor('home') != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  BrandHeroBanner(
                    key: const ValueKey('home-brand-hero'),
                    brand: brand,
                    role: 'home',
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  brand.voice.greeting,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontFamily: context.brandTheme.displayFontFamily,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                ),
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

/// The desktop Home composition: the published photo, the featured recipe and
/// the chef's catalogue as a four-column grid.
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
    return ResponsiveContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (brand.heroFor('home') != null) ...[
            BrandHeroBanner(
              key: const ValueKey('home-brand-hero'),
              brand: brand,
              role: 'home',
            ),
            const SizedBox(height: 28),
          ],
          RecipeCard.featured(
            recipe: featured,
            onTap: () => onOpenRecipe(featured),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: Text('Від шефа',
                    style: Theme.of(context).textTheme.headlineSmall),
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
              crossAxisCount: 4,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              childAspectRatio: .60,
            ),
            itemCount: recipes.length,
            itemBuilder: (context, index) => RecipeCard(
              recipe: recipes[index],
              onTap: () => onOpenRecipe(recipes[index]),
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
                Text('Преміум-колекція',
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
