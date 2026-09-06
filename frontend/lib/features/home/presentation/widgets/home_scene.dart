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
    this.courseCollection,
    required this.onOpenRecipe,
    required this.onCollectionTap,
    required this.onUnlockCourse,
  });

  final BrandDetails brand;
  final List<Recipe> recipes;
  final bool courseLocked;
  final ContentCollection? courseCollection;
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
          _EditorialReveal(
            key: const ValueKey('home-editorial-hero-reveal'),
            debugLabel: 'home-editorial-hero',
            delay: const Duration(milliseconds: 40),
            child: RecipeCard.featured(
              key: const ValueKey('mobile-featured-recipe-hero'),
              recipe: featured,
              compact: true,
              onTap: () => onOpenRecipe(featured),
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
    required this.onCollectionTap,
    required this.onUnlockCourse,
  });

  final BrandDetails brand;
  final List<Recipe> recipes;
  final bool courseLocked;
  final ContentCollection? courseCollection;
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
          _EditorialReveal(
            key: const ValueKey('home-editorial-hero-reveal'),
            debugLabel: 'home-editorial-hero',
            delay: const Duration(milliseconds: 40),
            child: _BordeauxDesktopHero(
              brand: brand,
              recipe: featured,
              onTap: () => onOpenRecipe(featured),
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
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.md,
                mainAxisSpacing: AppSpacing.md,
                mainAxisExtent: RecipeCard.gridMainAxisExtent(
                  availableWidth: constraints.maxWidth,
                  columns: 3,
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
                child: _DesktopFeaturedRecipeMedia(
                  recipe: recipe,
                  targetWidth: constraints.maxWidth * .6,
                  labelWidth: constraints.maxWidth * .42,
                  onTap: onTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopFeaturedRecipeMedia extends StatefulWidget {
  const _DesktopFeaturedRecipeMedia({
    required this.recipe,
    required this.targetWidth,
    required this.labelWidth,
    required this.onTap,
  });

  final Recipe recipe;
  final double targetWidth;
  final double labelWidth;
  final VoidCallback onTap;

  @override
  State<_DesktopFeaturedRecipeMedia> createState() =>
      _DesktopFeaturedRecipeMediaState();
}

class _DesktopFeaturedRecipeMediaState
    extends State<_DesktopFeaturedRecipeMedia> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semantic;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final duration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 320);

    return Semantics(
      button: true,
      label: 'Відкрити рецепт ${widget.recipe.title}',
      child: Material(
        color: semantic.surfaceStrong,
        child: InkWell(
          onTap: widget.onTap,
          onHover: (value) => setState(() => _hovered = value),
          mouseCursor: SystemMouseCursors.click,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: AnimatedScale(
                    scale: _hovered ? 1.025 : 1,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: RecipeImageHero(
                      recipeId: widget.recipe.id,
                      child: RecipePhoto(
                        key: const ValueKey('featured-recipe-hero'),
                        recipe: widget.recipe,
                        role: RecipeImageRole.featured,
                        targetWidth: widget.targetWidth,
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _hovered ? 1 : 0,
                    duration: duration,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            theme.colorScheme.primary.withOpacity(.10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    width: widget.labelWidth,
                    constraints: const BoxConstraints(minWidth: 260),
                    color: _hovered
                        ? context.brandTheme.accentPressed
                        : theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.recipe.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                '${widget.recipe.totalTimeMinutes} хв',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        AnimatedSlide(
                          offset: _hovered ? const Offset(.18, 0) : Offset.zero,
                          duration: duration,
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: theme.colorScheme.onPrimary,
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

/// Editorial storefront for the brand's featured collection. It previews the
/// real collection whenever its detail has loaded, then falls back to the
/// published recipe feed so Home never collapses into a generic paywall box.
class BrandCourseCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final title = collection?.title.trim().isNotEmpty == true
        ? collection!.title
        : courseName;
    final description = collection?.description.trim().isNotEmpty == true
        ? collection!.description
        : 'Авторські рецепти й практичні матеріали, зібрані в одну програму.';
    final isLocked = collection?.isLocked ?? locked;
    final action = isLocked ? onUnlock : onOpen;
    final previews = _previewRecipes();

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 760;
        final content = _CourseShowcaseCopy(
          title: title,
          description: description,
          itemCount: collection?.itemCount,
          locked: isLocked,
          compact: !desktop,
        );
        final media = _CoursePreviewMosaic(
          title: title,
          coverUrl: collection?.coverUrl,
          recipes: previews,
        );

        return ContentCard(
          key: const ValueKey('premium-collection-showcase'),
          onTap: action,
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
      ...?collection?.items.map((item) => item.content),
      ...fallbackRecipes,
    ];
    final seen = <String>{};
    return candidates.where((recipe) => seen.add(recipe.id)).take(3).toList();
  }
}

class _CourseShowcaseCopy extends StatelessWidget {
  const _CourseShowcaseCopy({
    required this.title,
    required this.description,
    required this.itemCount,
    required this.locked,
    required this.compact,
  });

  final String title;
  final String description;
  final int? itemCount;
  final bool locked;
  final bool compact;

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
          Container(
            key: const ValueKey('premium-collection-cta'),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: AppRadius.sm,
            ),
            child: Row(
              children: [
                Icon(
                  locked
                      ? Icons.workspace_premium_outlined
                      : Icons.collections_bookmark_outlined,
                  size: 19,
                  color: onAccent,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    locked ? 'Відкрити Premium' : 'Відкрити майстерню',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: onAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, size: 20, color: onAccent),
              ],
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
