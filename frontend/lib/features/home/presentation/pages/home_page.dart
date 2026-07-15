import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_models.dart';
import '../../../../app/theme/brand_theme.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/branding/brand_providers.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/providers/recipe_provider.dart';
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
  Recipe? _selectedRecipe;

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
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(recipeListProvider.notifier).loadRecipes(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeIntro(
                brand: brand,
                userName: user?.email,
                onProfileTap: () => context.go('/profile'),
                onScanTap: () => context.go('/camera'),
                onCollectionTap: () => _openCollection(
                  context,
                  authenticated: user != null,
                  isPremium: isPremium,
                  courseTag: brand.courseTag,
                ),
              ),
            ),
            ..._recipeSlivers(recipes),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  List<Widget> _recipeSlivers(AsyncValue<List<Recipe>> state) => state.when(
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
          _selectedRecipe ??= recipes.first;
          return [
            SliverToBoxAdapter(
              child: ResponsiveContainer(
                maxWidth: 1180,
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      constraints.maxWidth >= 1024
                          ? _DesktopRecipes(
                              recipes: recipes,
                              selected: _selectedRecipe!,
                              onSelect: (recipe) =>
                                  setState(() => _selectedRecipe = recipe),
                              onOpen: _openRecipe,
                            )
                          : ResponsiveContainer(
                              maxWidth: 480,
                              padding: EdgeInsets.zero,
                              child: _RecipeFeed(
                                  recipes: recipes, onOpen: _openRecipe),
                            ),
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
              onRetry: () =>
                  ref.read(recipeListProvider.notifier).loadRecipes(),
            ),
          ),
        ],
      );

  void _openRecipe(Recipe recipe) => context.push('/recipes/${recipe.id}');

  void _openCollection(
    BuildContext context, {
    required bool authenticated,
    required bool isPremium,
    required String? courseTag,
  }) {
    if (courseTag == null) return;
    final returnTo = SearchRouteLocation(tag: courseTag).toUri().toString();
    if (!authenticated) {
      context.go('/login?returnTo=${Uri.encodeComponent(returnTo)}');
    } else if (!isPremium) {
      context
          .push(OfferRouteLocation.subscription(returnTo: returnTo).location);
    } else {
      context.go(returnTo);
    }
  }
}

class _HomeIntro extends StatelessWidget {
  const _HomeIntro({
    required this.brand,
    required this.userName,
    required this.onProfileTap,
    required this.onScanTap,
    required this.onCollectionTap,
  });

  final BrandDetails brand;
  final String? userName;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;
  final VoidCallback onCollectionTap;

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
                if (brand.voice.courseName != null &&
                    brand.courseTag != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _CollectionPromo(
                    courseName: brand.voice.courseName!,
                    onTap: onCollectionTap,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Свіже від автора',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
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

class _DesktopRecipes extends StatelessWidget {
  const _DesktopRecipes({
    required this.recipes,
    required this.selected,
    required this.onSelect,
    required this.onOpen,
  });
  final List<Recipe> recipes;
  final Recipe selected;
  final ValueChanged<Recipe> onSelect;
  final ValueChanged<Recipe> onOpen;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 420,
            child: Column(
              children: [
                for (final recipe in recipes) ...[
                  _RecipeTile(
                      recipe: recipe,
                      selected: recipe == selected,
                      onTap: () => onSelect(recipe)),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
              child: _RecipePreview(
                  recipe: selected, onTap: () => onOpen(selected))),
        ],
      );
}

class _RecipeTile extends StatelessWidget {
  const _RecipeTile(
      {required this.recipe, required this.onTap, this.selected = false});
  final Recipe recipe;
  final VoidCallback onTap;
  final bool selected;

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
            const Tooltip(
              message: 'Збереження стане доступним незабаром',
              child: IconButton(
                onPressed: null,
                icon: Icon(Icons.bookmark_border_rounded),
              ),
            ),
          ],
        ),
      );
}

class _RecipePreview extends StatelessWidget {
  const _RecipePreview({required this.recipe, required this.onTap});
  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ContentCard(
        onTap: onTap,
        semanticLabel: 'Відкрити рецепт ${recipe.title}',
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RecipeImage(recipe: recipe, width: double.infinity, height: 300),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(recipe.description,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                        label: 'Відкрити рецепт',
                        onPressed: onTap,
                        icon: Icons.arrow_forward_rounded),
                  ]),
            ),
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
                  height: 72,
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
