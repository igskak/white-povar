import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/brand_theme.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/branding/brand_providers.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../collections/providers/collection_provider.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/providers/recipe_provider.dart';
import '../../../recipes/presentation/widgets/recipe_card.dart';
import '../../../recipes/presentation/widgets/favorite_button.dart';

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
    final featuredCollectionId = collections.valueOrNull
        ?.where((collection) => collection.slug == brand.courseTag)
        .map((collection) => collection.id)
        .firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 1024
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
              onCollectionTap: () => _openCollection(
                context,
                courseTag: brand.courseTag,
                collectionId: featuredCollectionId,
              ),
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
    required this.onCollectionTap,
  });

  final BrandDetails brand;
  final AsyncValue<List<Recipe>> recipes;
  final String? userName;
  final Future<void> Function() onRefresh;
  final ValueChanged<Recipe> onOpenRecipe;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;
  final VoidCallback onCollectionTap;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _HomeIntro(
                  brand: brand,
                  userName: userName,
                  onProfileTap: onProfileTap,
                  onScanTap: onScanTap,
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
                      'Свіжі рецепти зʼявляться тут після оновлення каталогу.',
                  icon: Icons.menu_book_outlined,
                ),
              ),
            ];
          }
          final featured = recipes.firstWhere(
            (recipe) => recipe.isFeatured,
            orElse: () => recipes.first,
          );
          final feed =
              recipes.where((recipe) => recipe.id != featured.id).toList();
          return [
            SliverToBoxAdapter(
              child: ResponsiveContainer(
                maxWidth: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FeaturedRecipeHero(
                      key: const ValueKey('mobile-featured-recipe-hero'),
                      recipe: featured,
                      compact: true,
                      onOpen: () => onOpenRecipe(featured),
                    ),
                    if (brand.voice.courseName != null &&
                        brand.courseTag != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _CollectionPromo(
                        courseName: brand.voice.courseName!,
                        onTap: onCollectionTap,
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
              subtitle: 'Перевірте зʼєднання та спробуйте ще раз.',
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
  });

  final BrandDetails brand;
  final AsyncValue<List<Recipe>> recipes;
  final Future<void> Function() onRefresh;
  final ValueChanged<Recipe> onOpenRecipe;
  final VoidCallback onCollectionTap;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: RefreshIndicator(
          onRefresh: onRefresh,
          child: recipes.when(
            loading: () => const _DesktopHomeSkeleton(),
            error: (_, __) => StateView.error(
              title: 'Не вдалося завантажити рецепти',
              subtitle: 'Перевірте зʼєднання та спробуйте ще раз.',
              onRetry: onRefresh,
            ),
            data: (items) {
              if (items.isEmpty) {
                return const StateView.empty(
                  title: 'На кухні поки тихо',
                  subtitle:
                      'Свіжі рецепти зʼявляться тут після оновлення каталогу.',
                  icon: Icons.menu_book_outlined,
                );
              }
              return _DesktopHomeContent(
                brand: brand,
                recipes: items,
                onOpenRecipe: onOpenRecipe,
                onCollectionTap: onCollectionTap,
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
  });

  final BrandDetails brand;
  final List<Recipe> recipes;
  final ValueChanged<Recipe> onOpenRecipe;
  final VoidCallback onCollectionTap;

  @override
  Widget build(BuildContext context) {
    final featured = recipes.firstWhere(
      (recipe) => recipe.isFeatured,
      orElse: () => recipes.first,
    );
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(40, 32, 40, 48),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _FeaturedRecipeHero(
                      recipe: featured,
                      onOpen: () => onOpenRecipe(featured),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Від шефа',
                              style: Theme.of(context).textTheme.headlineSmall),
                        ),
                        TextButton.icon(
                          onPressed: () => context.go('/search'),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Усі рецепти'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: AppSpacing.md,
                        mainAxisSpacing: AppSpacing.md,
                        childAspectRatio: .68,
                      ),
                      itemCount: recipes.length,
                      itemBuilder: (context, index) => RecipeCard(
                        recipe: recipes[index],
                        onTap: () => onOpenRecipe(recipes[index]),
                      ),
                    ),
                    if (brand.voice.courseName != null &&
                        brand.courseTag != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _DesktopCollectionPromo(
                        courseName: brand.voice.courseName!,
                        onTap: onCollectionTap,
                      ),
                    ],
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

class _FeaturedRecipeHero extends StatelessWidget {
  const _FeaturedRecipeHero({
    super.key,
    required this.recipe,
    required this.onOpen,
    this.compact = false,
  });

  final Recipe recipe;
  final VoidCallback onOpen;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.restaurant_menu_rounded, size: 56)),
    );
    return Semantics(
      button: true,
      label: 'Відкрити рекомендований рецепт ${recipe.title}',
      child: SizedBox(
        height: compact ? 280 : 300,
        child: ClipRRect(
          borderRadius: AppRadius.xl,
          child: Stack(
            fit: StackFit.expand,
            children: [
              recipe.images.isEmpty
                  ? fallback
                  : CachedNetworkImage(
                      imageUrl: recipe.images.first,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => fallback,
                      errorWidget: (_, __, ___) => fallback,
                    ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xE616130F),
                      Color(0x5C16130F),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? AppSpacing.lg : 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppBadge(
                      label: 'Рекомендоване',
                      icon: Icons.local_fire_department_outlined,
                      color: AppColorsV2.premiumGold,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Text(
                        recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                              color: AppColorsV2.onInk,
                              fontFamily: context.brandTheme.displayFontFamily,
                              fontWeight: FontWeight.w700,
                              height: 1.05,
                              fontSize: compact ? 30 : null,
                            ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${recipe.totalTimeMinutes} хв  ·  ${recipe.cuisine}  ·  Рівень ${recipe.difficulty}',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColorsV2.onInk),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.restaurant_menu_rounded),
                      label: const Text('Почати готувати'),
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
}

class _DesktopCollectionPromo extends StatelessWidget {
  const _DesktopCollectionPromo(
      {required this.courseName, required this.onTap});

  final String courseName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ContentCard(
        onTap: onTap,
        semanticLabel: 'Відкрити колекцію $courseName',
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_rounded,
                color: AppColorsV2.premiumGold, size: 32),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Преміум-колекція',
                      style: Theme.of(context).textTheme.labelLarge),
                  Text(courseName,
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      );
}

class _DesktopHomeSkeleton extends StatelessWidget {
  const _DesktopHomeSkeleton();

  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox(
          width: 1180,
          child: Padding(
            padding: EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: AppSkeleton(height: 300, borderRadius: AppRadius.xl),
                ),
                SizedBox(height: 28),
                AppSkeleton(width: 180, height: 32, borderRadius: AppRadius.md),
              ],
            ),
          ),
        ),
      );
}

class _HomeIntro extends StatelessWidget {
  const _HomeIntro({
    required this.brand,
    required this.userName,
    required this.onProfileTap,
    required this.onScanTap,
  });

  final BrandDetails brand;
  final String? userName;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;

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
                _ScanBanner(onTap: onScanTap),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      );
}

class _ScanBanner extends StatelessWidget {
  const _ScanBanner({required this.onTap});
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

class _CollectionPromo extends StatelessWidget {
  const _CollectionPromo({required this.courseName, required this.onTap});
  final String courseName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ContentCard(
        onTap: onTap,
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

class _RecipeFeed extends StatelessWidget {
  const _RecipeFeed({required this.recipes, required this.onOpen});
  final List<Recipe> recipes;
  final ValueChanged<Recipe> onOpen;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final recipe in recipes) ...[
            _RecipeTile(recipe: recipe, onTap: () => onOpen(recipe)),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile({required this.recipe, required this.onTap});
  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ContentCard(
        onTap: onTap,
        semanticLabel: 'Відкрити рецепт ${recipe.title}',
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            _RecipeImage(recipe: recipe, width: 84, height: 84),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text('${recipe.totalTimeMinutes} хв · ${recipe.cuisine}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (recipe.isPremium)
              const Icon(Icons.workspace_premium_rounded,
                  color: AppColorsV2.premiumGold),
            FavoriteButton(recipeId: recipe.id),
          ],
        ),
      );
}

class _RecipeImage extends StatelessWidget {
  const _RecipeImage(
      {required this.recipe, required this.width, required this.height});
  final Recipe recipe;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.restaurant_menu_rounded),
    );
    return ClipRRect(
      borderRadius: AppRadius.md,
      child: SizedBox(
        width: width,
        height: height,
        child: recipe.images.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: recipe.images.first,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
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
                  height: 240,
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
