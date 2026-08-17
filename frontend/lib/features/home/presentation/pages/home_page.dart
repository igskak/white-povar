import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/branding/brand_providers.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../collections/providers/collection_provider.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/providers/recipe_provider.dart';
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
    final collections = ref.watch(collectionListProvider);
    // 13g: the course card is locked for guests and free users, active for
    // premium, and hidden entirely when the brand publishes no course.
    final courseLocked = !ref.watch(isPremiumProvider);
    final featuredCollectionId = collections.valueOrNull
        ?.where((collection) => collection.slug == brand.courseTag)
        .map((collection) => collection.id)
        .firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= AppLayout.contentDesktopBreakpoint
              ? _DesktopHome(
                  brand: brand,
                  recipes: recipes,
                  onRefresh: () =>
                      ref.read(recipeListProvider.notifier).loadRecipes(),
                  onOpenRecipe: _openRecipe,
                  onCollectionTap: () => _openCollection(
                    context,
                    courseTag: brand.courseTag,
                    collectionId: featuredCollectionId,
                  ),
                  onUnlockCourse: () => context.push('/subscription'),
                  courseLocked: courseLocked,
                )
              : _MobileHome(
                  brand: brand,
                  recipes: recipes,
                  userName: user?.email,
                  onRefresh: () =>
                      ref.read(recipeListProvider.notifier).loadRecipes(),
                  onOpenRecipe: _openRecipe,
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
                ),
    );
  }

  void _openRecipe(Recipe recipe) => context.push('/recipes/${recipe.id}');

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
    required this.onProfileTap,
    required this.onScanTap,
    required this.onTypeTap,
    required this.onCollectionTap,
    required this.onUnlockCourse,
    required this.courseLocked,
  });

  final BrandDetails brand;
  final AsyncValue<List<Recipe>> recipes;
  final String? userName;
  final Future<void> Function() onRefresh;
  final ValueChanged<Recipe> onOpenRecipe;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;
  final VoidCallback onTypeTap;
  final VoidCallback onCollectionTap;
  final VoidCallback onUnlockCourse;
  final bool courseLocked;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: RefreshIndicator(
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
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
            ],
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
                onOpenRecipe: onOpenRecipe,
                onCollectionTap: onCollectionTap,
                onUnlockCourse: onUnlockCourse,
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
    required this.onCollectionTap,
    required this.onUnlockCourse,
    required this.courseLocked,
  });

  final BrandDetails brand;
  final AsyncValue<List<Recipe>> recipes;
  final Future<void> Function() onRefresh;
  final ValueChanged<Recipe> onOpenRecipe;
  final VoidCallback onCollectionTap;
  final VoidCallback onUnlockCourse;
  final bool courseLocked;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: RefreshIndicator(
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
                onCollectionTap: onCollectionTap,
                onUnlockCourse: onUnlockCourse,
                courseLocked: courseLocked,
              );
            },
          ),
        ),
      );
}

class _DesktopHomeContent extends StatelessWidget {
  const _DesktopHomeContent({
    required this.brand,
    required this.recipes,
    required this.onOpenRecipe,
    required this.onCollectionTap,
    required this.onUnlockCourse,
    required this.courseLocked,
  });

  final BrandDetails brand;
  final List<Recipe> recipes;
  final ValueChanged<Recipe> onOpenRecipe;
  final VoidCallback onCollectionTap;
  final VoidCallback onUnlockCourse;
  final bool courseLocked;

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
                onOpenRecipe: onOpenRecipe,
                onSeeAll: () => context.go('/search'),
                onCollectionTap: onCollectionTap,
                onUnlockCourse: onUnlockCourse,
              ),
            ),
          ),
        ],
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
