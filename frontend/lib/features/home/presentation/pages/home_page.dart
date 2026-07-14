import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/providers/recipe_provider.dart';

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
    final recipesState = ref.watch(recipeListProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(recipeListProvider.notifier).loadRecipes(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _HomeHeader()),
            const SliverToBoxAdapter(child: _PantryHero()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: _SectionHeader(
                  title: 'Стрічка шефа',
                  action: 'Усі рецепти',
                  onTap: () => context.go('/search'),
                ),
              ),
            ),
            ..._recipeSlivers(recipesState),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
          ],
        ),
      ),
    );
  }

  List<Widget> _recipeSlivers(AsyncValue<List<Recipe>> state) {
    return state.when(
      data: (recipes) {
        if (recipes.isEmpty) {
          return const [
            SliverToBoxAdapter(
              child: StateView.empty(
                title: 'На кухні поки тихо',
                subtitle:
                    'Свіжі рецепти зʼявляться тут після оновлення каталогу.',
                icon: Icons.menu_book_outlined,
              ),
            ),
          ];
        }

        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final columns = width >= 960
                    ? 3
                    : width >= 620
                        ? 2
                        : 1;
                return SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: columns == 1 ? 1.18 : 0.92,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final recipe = recipes[index];
                      return _EditorialRecipeCard(
                        recipe: recipe,
                        onTap: () => context.push('/recipes/${recipe.id}'),
                      );
                    },
                    childCount: recipes.length,
                  ),
                );
              },
            ),
          ),
        ];
      },
      loading: () => const [
        SliverToBoxAdapter(
          child: StateView.loading(
            title: 'Накриваємо стіл',
            subtitle: 'Підбираємо рецепти, які варто приготувати.',
          ),
        ),
      ],
      error: (error, _) => [
        SliverToBoxAdapter(
          child: StateView.error(
            title: 'Не вдалося відкрити кулінарну книгу',
            subtitle: error.toString(),
            onRetry: () => ref.read(recipeListProvider.notifier).loadRecipes(),
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColorsV2.ink,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                color: AppColorsV2.onInk,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WHITE POVAR',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                  ),
                  Text(
                    'Ваш кулінарний помічник',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => context.go('/profile'),
              tooltip: 'Відкрити профіль',
              icon: const Icon(Icons.account_circle_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _PantryHero extends StatelessWidget {
  const _PantryHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        constraints: const BoxConstraints(minHeight: 300),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColorsV2.ink,
          borderRadius: AppRadius.xl,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 680;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.1),
                    borderRadius: AppRadius.xl,
                  ),
                  child: const Text(
                    'ГОТУЙТЕ З ТОГО, ЩО Є',
                    style: TextStyle(
                      color: AppColorsV2.onInk,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Перетворіть запаси\nна вечерю.',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: AppColorsV2.onInk,
                    fontSize: wide ? 48 : 38,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Сфотографуйте інгредієнти, а ми підберемо рецепти, які використовують їх найкраще.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColorsV2.onInk.withOpacity(.72),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColorsV2.accent,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => context.go('/camera'),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Сканувати інгредієнти'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColorsV2.onInk,
                        side: BorderSide(
                          color: AppColorsV2.onInk.withOpacity(.35),
                        ),
                      ),
                      onPressed: () => context.go('/search'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Ввести вручну'),
                    ),
                  ],
                ),
              ],
            );

            if (!wide) return copy;
            return Row(
              children: [
                Expanded(flex: 3, child: copy),
                const SizedBox(width: AppSpacing.xl),
                const Expanded(flex: 2, child: _HeroIllustration()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColorsV2.surfaceStrong,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 12),
        ),
        child: const Icon(
          Icons.ramen_dining_rounded,
          size: 112,
          color: AppColorsV2.accent,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.action, this.onTap});

  final String title;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    );
  }
}

class _EditorialRecipeCard extends StatelessWidget {
  const _EditorialRecipeCard({required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: 'Відкрити рецепт ${recipe.title}',
      child: Material(
        color: AppColorsV2.surface,
        borderRadius: AppRadius.lg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    recipe.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: recipe.images.first,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const _ImageFallback(),
                          )
                        : const _ImageFallback(),
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Material(
                        color: AppColorsV2.surface.withOpacity(.92),
                        shape: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(AppSpacing.xs),
                          child: Icon(Icons.bookmark_border_rounded, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 16),
                        const SizedBox(width: AppSpacing.xxs),
                        Text('${recipe.totalTimeMinutes} хв'),
                        const SizedBox(width: AppSpacing.md),
                        const Icon(Icons.restaurant_outlined, size: 16),
                        const SizedBox(width: AppSpacing.xxs),
                        Expanded(
                          child: Text(
                            recipe.cuisine,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColorsV2.surfaceStrong,
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_menu_rounded,
        size: 48,
        color: AppColorsV2.textSecondary,
      ),
    );
  }
}
