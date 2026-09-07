import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/branding/brand_providers.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../collections/models/collection.dart';
import '../../../collections/providers/collection_provider.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/providers/recipe_provider.dart';
import '../../../recipes/services/cooking_progress_store.dart';
import '../widgets/home_scene.dart';
import '../../../subscription/providers/subscription_provider.dart';

/// The public, tenant-branded recipe feed.
///
/// Saving is deliberately presented as unavailable here. CORE-01 owns the
/// mutation, optimistic state and guest migration contract.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final GlobalKey _heroAnchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recipeListProvider.notifier).loadRecipes();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(tenantBootstrapProvider);
    final brand = bootstrap.brandConfig.brand;
    final recipes = ref.watch(recipeListProvider);
    final user = ref.watch(currentUserProvider);
    final cookingProgress =
        ref.watch(activeCookingProgressProvider).valueOrNull;
    final savedRecipes =
        ref.watch(favoriteRecipesProvider).valueOrNull ?? const <Recipe>[];
    // 13g: the course card is locked for guests and free users, active for
    // premium, and hidden entirely when the brand publishes no course.
    final courseLocked = !ref.watch(isPremiumProvider);
    final featuredCollectionId = ref.watch(courseCollectionIdProvider);
    final featuredCollection = featuredCollectionId == null
        ? null
        : ref.watch(collectionDetailProvider(featuredCollectionId)).valueOrNull;

    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= AppLayout.contentDesktopBreakpoint
              ? _DesktopHome(
                  brand: brand,
                  recipes: recipes,
                  onRefresh: _refreshHome,
                  onOpenRecipe: _openRecipe,
                  onResumeCooking: _resumeCooking,
                  onCollectionTap: () => _openCollection(
                    context,
                    courseTag: brand.courseTag,
                    collectionId: featuredCollectionId,
                  ),
                  onUnlockCourse: () => context.push('/subscription'),
                  courseLocked: courseLocked,
                  courseCollection: featuredCollection,
                  cookingProgress: cookingProgress,
                  savedRecipes: savedRecipes,
                  heroAnchorKey: _heroAnchorKey,
                  onSearch: () => context.go('/search'),
                  onFilters: () => context.go('/search?filters=1'),
                  onScan: () => context.go('/camera'),
                  onPremium: () => context.push('/subscription'),
                )
              : _MobileHome(
                  brand: brand,
                  recipes: recipes,
                  userName: user?.email,
                  onRefresh: _refreshHome,
                  onOpenRecipe: _openRecipe,
                  onResumeCooking: _resumeCooking,
                  onProfileTap: () => context.go('/profile'),
                  onScanTap: () => context.go('/camera'),
                  onTypeTap: () => context.go('/search'),
                  onCollectionTap: () => _openCollection(
                    context,
                    courseTag: brand.courseTag,
                    collectionId: featuredCollectionId,
                  ),
                  onUnlockCourse: () => context.push('/subscription'),
                  courseLocked: courseLocked,
                  courseCollection: featuredCollection,
                  cookingProgress: cookingProgress,
                  savedRecipes: savedRecipes,
                  heroAnchorKey: _heroAnchorKey,
                  onSearch: () => context.go('/search'),
                  onFilters: () => context.go('/search?filters=1'),
                  onPremium: () => context.push('/subscription'),
                ),
    );
  }

  void _openRecipe(Recipe recipe) =>
      context.push('/recipes/${recipe.id}', extra: recipe);

  void _resumeCooking(Recipe recipe) =>
      context.push('/recipes/${recipe.id}/cook');

  Future<void> _refreshHome() async {
    ref.invalidate(activeCookingProgressProvider);
    ref.invalidate(favoriteRecipesProvider);
    await ref.read(recipeListProvider.notifier).loadRecipes();
  }

  void _openCollection(
    BuildContext context, {
    required String? courseTag,
    required String? collectionId,
  }) {
    if (courseTag == null) return;
    // Until a published collection is returned, the collection index is the
    // truthful fallback rather than a fabricated purchase or success state.
    context.push(
        collectionId == null ? '/collections' : '/collections/$collectionId');
  }
}

class _MobileHome extends StatelessWidget {
  const _MobileHome({
    required this.brand,
    required this.recipes,
    required this.userName,
    required this.onRefresh,
    required this.onOpenRecipe,
    required this.onResumeCooking,
    required this.onProfileTap,
    required this.onScanTap,
    required this.onTypeTap,
    required this.onCollectionTap,
    required this.onUnlockCourse,
    required this.courseLocked,
    required this.courseCollection,
    required this.cookingProgress,
    required this.savedRecipes,
    required this.heroAnchorKey,
    required this.onSearch,
    required this.onFilters,
    required this.onPremium,
  });

  final BrandDetails brand;
  final AsyncValue<List<Recipe>> recipes;
  final String? userName;
  final Future<void> Function() onRefresh;
  final ValueChanged<Recipe> onOpenRecipe;
  final ValueChanged<Recipe> onResumeCooking;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;
  final VoidCallback onTypeTap;
  final VoidCallback onCollectionTap;
  final VoidCallback onUnlockCourse;
  final bool courseLocked;
  final ContentCollection? courseCollection;
  final CookingProgress? cookingProgress;
  final List<Recipe> savedRecipes;
  final GlobalKey heroAnchorKey;
  final VoidCallback onSearch;
  final VoidCallback onFilters;
  final VoidCallback onPremium;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _HomeDiscoveryOverlay(
          heroAnchorKey: heroAnchorKey,
          onSearch: onSearch,
          onFilters: onFilters,
          onScan: onScanTap,
          onPremium: onPremium,
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: HomeIntro(
                    brand: brand,
                    userName: userName,
                    onProfileTap: onProfileTap,
                    onScanTap: onScanTap,
                    onTypeTap: onTypeTap,
                  ),
                ),
                ..._recipeSlivers(recipes, onOpenRecipe, context),
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxl),
                ),
              ],
            ),
          ),
        ),
      );

  List<Widget> _recipeSlivers(
    AsyncValue<List<Recipe>> state,
    ValueChanged<Recipe> onOpenRecipe,
    BuildContext context,
  ) =>
      state.when(
        data: (recipes) {
          if (recipes.isEmpty) {
            return const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: StateView.empty(
                  title: 'На кухні поки тихо',
                  subtitle:
                      'Свіжі рецепти з’являться тут після оновлення каталогу.',
                  icon: Icons.menu_book_outlined,
                ),
              ),
            ];
          }
          return [
            SliverToBoxAdapter(
              child: HomeFeedSections(
                brand: brand,
                recipes: recipes,
                courseLocked: courseLocked,
                courseCollection: courseCollection,
                onOpenRecipe: onOpenRecipe,
                onResumeCooking: onResumeCooking,
                onCollectionTap: onCollectionTap,
                onUnlockCourse: onUnlockCourse,
                cookingProgress: cookingProgress,
                savedRecipes: savedRecipes,
                heroAnchorKey: heroAnchorKey,
              ),
            ),
          ];
        },
        loading: () => const [SliverToBoxAdapter(child: _HomeSkeleton())],
        error: (error, _) => [
          SliverFillRemaining(
            hasScrollBody: false,
            child: StateView.error(
              title: 'Не вдалося завантажити рецепти',
              subtitle: 'Перевірте з’єднання та спробуйте ще раз.',
              onRetry: onRefresh,
            ),
          ),
        ],
      );
}

class _DesktopHome extends StatelessWidget {
  const _DesktopHome({
    required this.brand,
    required this.recipes,
    required this.onRefresh,
    required this.onOpenRecipe,
    required this.onResumeCooking,
    required this.onCollectionTap,
    required this.onUnlockCourse,
    required this.courseLocked,
    required this.courseCollection,
    required this.cookingProgress,
    required this.savedRecipes,
    required this.heroAnchorKey,
    required this.onSearch,
    required this.onFilters,
    required this.onScan,
    required this.onPremium,
  });

  final BrandDetails brand;
  final AsyncValue<List<Recipe>> recipes;
  final Future<void> Function() onRefresh;
  final ValueChanged<Recipe> onOpenRecipe;
  final ValueChanged<Recipe> onResumeCooking;
  final VoidCallback onCollectionTap;
  final VoidCallback onUnlockCourse;
  final bool courseLocked;
  final ContentCollection? courseCollection;
  final CookingProgress? cookingProgress;
  final List<Recipe> savedRecipes;
  final GlobalKey heroAnchorKey;
  final VoidCallback onSearch;
  final VoidCallback onFilters;
  final VoidCallback onScan;
  final VoidCallback onPremium;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: _HomeDiscoveryOverlay(
          heroAnchorKey: heroAnchorKey,
          onSearch: onSearch,
          onFilters: onFilters,
          onScan: onScan,
          onPremium: onPremium,
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: recipes.when(
              loading: () => const _DesktopHomeSkeleton(),
              error: (_, __) => StateView.error(
                title: 'Не вдалося завантажити рецепти',
                subtitle: 'Перевірте з’єднання та спробуйте ще раз.',
                onRetry: onRefresh,
              ),
              data: (items) {
                if (items.isEmpty) {
                  return const StateView.empty(
                    title: 'На кухні поки тихо',
                    subtitle:
                        'Свіжі рецепти з’являться тут після оновлення каталогу.',
                    icon: Icons.menu_book_outlined,
                  );
                }
                return _DesktopHomeContent(
                  brand: brand,
                  recipes: items,
                  onOpenRecipe: onOpenRecipe,
                  onResumeCooking: onResumeCooking,
                  onCollectionTap: onCollectionTap,
                  onUnlockCourse: onUnlockCourse,
                  courseLocked: courseLocked,
                  courseCollection: courseCollection,
                  cookingProgress: cookingProgress,
                  savedRecipes: savedRecipes,
                  heroAnchorKey: heroAnchorKey,
                );
              },
            ),
          ),
        ),
      );
}

class _DesktopHomeContent extends StatelessWidget {
  const _DesktopHomeContent({
    required this.brand,
    required this.recipes,
    required this.onOpenRecipe,
    required this.onResumeCooking,
    required this.onCollectionTap,
    required this.onUnlockCourse,
    required this.courseLocked,
    required this.courseCollection,
    required this.cookingProgress,
    required this.savedRecipes,
    required this.heroAnchorKey,
  });

  final BrandDetails brand;
  final List<Recipe> recipes;
  final ValueChanged<Recipe> onOpenRecipe;
  final ValueChanged<Recipe> onResumeCooking;
  final VoidCallback onCollectionTap;
  final VoidCallback onUnlockCourse;
  final bool courseLocked;
  final ContentCollection? courseCollection;
  final CookingProgress? cookingProgress;
  final List<Recipe> savedRecipes;
  final GlobalKey heroAnchorKey;

  @override
  Widget build(BuildContext context) => CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: HomeDesktopSections.pagePadding,
            sliver: SliverToBoxAdapter(
              child: HomeDesktopSections(
                brand: brand,
                recipes: recipes,
                courseLocked: courseLocked,
                courseCollection: courseCollection,
                onOpenRecipe: onOpenRecipe,
                onResumeCooking: onResumeCooking,
                onSeeAll: () => context.go('/search'),
                onCollectionTap: onCollectionTap,
                onUnlockCourse: onUnlockCourse,
                cookingProgress: cookingProgress,
                savedRecipes: savedRecipes,
                heroAnchorKey: heroAnchorKey,
              ),
            ),
          ),
        ],
      );
}

class _HomeDiscoveryOverlay extends StatefulWidget {
  const _HomeDiscoveryOverlay({
    required this.child,
    required this.heroAnchorKey,
    required this.onSearch,
    required this.onFilters,
    required this.onScan,
    required this.onPremium,
  });

  final Widget child;
  final GlobalKey heroAnchorKey;
  final VoidCallback onSearch;
  final VoidCallback onFilters;
  final VoidCallback onScan;
  final VoidCallback onPremium;

  @override
  State<_HomeDiscoveryOverlay> createState() => _HomeDiscoveryOverlayState();
}

class _HomeDiscoveryOverlayState extends State<_HomeDiscoveryOverlay> {
  bool _visible = false;

  bool _handleScroll(ScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncVisibility();
      });
    }
    return false;
  }

  void _syncVisibility() {
    final heroBox = widget.heroAnchorKey.currentContext?.findRenderObject();
    final overlayBox = context.findRenderObject();
    if (heroBox is! RenderBox || overlayBox is! RenderBox) return;
    final heroBottom = heroBox.localToGlobal(Offset(0, heroBox.size.height)).dy;
    final overlayTop = overlayBox.localToGlobal(Offset.zero).dy +
        MediaQuery.paddingOf(context).top +
        AppSpacing.xs;
    final nextVisible = heroBottom <= overlayTop;
    if (nextVisible != _visible && mounted) {
      setState(() => _visible = nextVisible);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion ? Duration.zero : AppMotion.medium;
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = AppLayout.gutter(width);

    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handleScroll,
          child: widget.child,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                AppSpacing.xs,
                horizontal,
                0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: IgnorePointer(
                    ignoring: !_visible,
                    child: AnimatedSlide(
                      offset: _visible ? Offset.zero : const Offset(0, -.35),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        key: const ValueKey('home-discovery-opacity'),
                        opacity: _visible ? 1 : 0,
                        duration: duration,
                        curve: Curves.easeOutCubic,
                        child: _HomeDiscoveryBar(
                          onSearch: widget.onSearch,
                          onFilters: widget.onFilters,
                          onScan: widget.onScan,
                          onPremium: widget.onPremium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeDiscoveryBar extends StatelessWidget {
  const _HomeDiscoveryBar({
    required this.onSearch,
    required this.onFilters,
    required this.onScan,
    required this.onPremium,
  });

  final VoidCallback onSearch;
  final VoidCallback onFilters;
  final VoidCallback onScan;
  final VoidCallback onPremium;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      key: const ValueKey('home-sticky-discovery-bar'),
      color: scheme.surfaceContainerLowest.withOpacity(.96),
      elevation: AppElevation.level3,
      shadowColor: scheme.shadow.withOpacity(.16),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.xl,
        side:
            BorderSide(color: context.semantic.outlineVariant.withOpacity(.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final expanded = constraints.maxWidth >= 620;
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xxs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: InkWell(
                    key: const ValueKey('home-discovery-search'),
                    onTap: onSearch,
                    borderRadius: AppRadius.lg,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded,
                              size: 21, color: scheme.primary),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              expanded ? 'Знайти рецепт' : 'Пошук',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _DiscoveryAction(
                  actionKey: const ValueKey('home-discovery-filters'),
                  icon: Icons.tune_rounded,
                  label: 'Фільтри',
                  showLabel: expanded,
                  onTap: onFilters,
                ),
                _DiscoveryAction(
                  actionKey: const ValueKey('home-discovery-scan'),
                  icon: Icons.center_focus_strong_rounded,
                  label: 'Сканувати',
                  showLabel: expanded,
                  onTap: onScan,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Semantics(
                  button: true,
                  label: 'Відкрити Premium',
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('home-discovery-premium'),
                    onPressed: onPremium,
                    icon:
                        const Icon(Icons.workspace_premium_outlined, size: 19),
                    label: Text(expanded ? 'Premium' : 'PRO'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DiscoveryAction extends StatelessWidget {
  const _DiscoveryAction({
    required this.actionKey,
    required this.icon,
    required this.label,
    required this.showLabel,
    required this.onTap,
  });

  final Key actionKey;
  final IconData icon;
  final String label;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: label,
        child: InkWell(
          key: actionKey,
          onTap: onTap,
          borderRadius: AppRadius.lg,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: showLabel ? AppSpacing.sm : AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  if (showLabel) ...[
                    const SizedBox(width: AppSpacing.xs),
                    Text(label, style: Theme.of(context).textTheme.labelLarge),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

class _DesktopHomeSkeleton extends StatelessWidget {
  const _DesktopHomeSkeleton();

  @override
  Widget build(BuildContext context) => const ResponsiveContainer(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: AppSkeleton(height: 340, borderRadius: AppRadius.xl),
              ),
              SizedBox(height: 28),
              AppSkeleton(width: 180, height: 32, borderRadius: AppRadius.md),
            ],
          ),
        ),
      );
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => const ResponsiveContainer(
        maxWidth: 480,
        child: Padding(
          padding: EdgeInsets.only(top: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton(width: 220, height: 44, borderRadius: AppRadius.lg),
              SizedBox(height: AppSpacing.lg),
              AppSkeleton(width: 260, height: 70, borderRadius: AppRadius.lg),
              SizedBox(height: AppSpacing.md),
              AppSkeleton(
                  width: double.infinity,
                  height: 320,
                  borderRadius: AppRadius.lg),
              SizedBox(height: AppSpacing.md),
              AppSkeleton(
                  width: double.infinity,
                  height: 96,
                  borderRadius: AppRadius.lg),
              SizedBox(height: AppSpacing.lg),
              AppSkeleton(
                  width: double.infinity,
                  height: 104,
                  borderRadius: AppRadius.lg),
            ],
          ),
        ),
      );
}
