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
  static const _filters = ['Усі', 'Вечеря', 'Супи', 'Десерти', 'Паста'];

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
      backgroundColor: _ChefColors.bg,
      body: RefreshIndicator(
        onRefresh: () => ref.read(recipeListProvider.notifier).loadRecipes(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _ChefHeader(
                filters: _filters,
                onProfileTap: () => context.go('/profile'),
                onScanTap: () => context.go('/camera'),
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

        final featured = recipes.first;
        final rest = recipes.skip(1).toList();

        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: _FeaturedRecipeCard(
                recipe: featured,
                onTap: () => context.push('/recipes/${featured.id}'),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              0,
            ),
            sliver: SliverList.separated(
              itemCount: rest.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final recipe = rest[index];
                return _CompactRecipeTile(
                  recipe: recipe,
                  onTap: () => context.push('/recipes/${recipe.id}'),
                );
              },
            ),
          ),
        ];
      },
      loading: () => const [
        SliverToBoxAdapter(child: _HomeSkeleton()),
      ],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: StateView.error(
            title: 'Не вдалося завантажити рецепти',
            subtitle: error.toString(),
            onRetry: () => ref.read(recipeListProvider.notifier).loadRecipes(),
          ),
        ),
      ],
    );
  }
}

class _ChefHeader extends StatelessWidget {
  const _ChefHeader({
    required this.filters,
    required this.onProfileTap,
    required this.onScanTap,
  });

  final List<String> filters;
  final VoidCallback onProfileTap;
  final VoidCallback onScanTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: _ChefColors.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x99D9A441),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                const Expanded(
                  child: Text(
                    'WHITE POVAR',
                    style: TextStyle(
                      color: _ChefColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.5,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: onProfileTap,
                  tooltip: 'Профіль',
                  style: IconButton.styleFrom(
                    backgroundColor: _ChefColors.surface,
                    foregroundColor: _ChefColors.text,
                    side: const BorderSide(color: _ChefColors.surfaceStrong),
                  ),
                  icon: const Icon(Icons.person_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            RichText(
              text: const TextSpan(
                style: TextStyle(
                  color: _ChefColors.text,
                  fontSize: 36,
                  height: 1.02,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
                children: [
                  TextSpan(text: 'Що приготуємо\n'),
                  TextSpan(
                    text: 'сьогодні?',
                    style: TextStyle(
                      color: _ChefColors.accent,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _ScanBanner(onTap: onScanTap),
            const SizedBox(height: AppSpacing.md),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < filters.length; i++) ...[
                    _FilterChip(label: filters[i], selected: i == 0),
                    if (i != filters.length - 1)
                      const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanBanner extends StatelessWidget {
  const _ScanBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lg,
        child: Ink(
          height: 62,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFE7BC5A),
                _ChefColors.accent,
                Color(0xFFC7902F)
              ],
            ),
            borderRadius: AppRadius.lg,
            boxShadow: [
              BoxShadow(
                color: Color(0x3DD9A441),
                blurRadius: 20,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _ChefColors.bg.withOpacity(.14),
                    borderRadius: AppRadius.md,
                  ),
                  child: const Icon(
                    Icons.photo_camera_outlined,
                    color: _ChefColors.bg,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Сканувати інгредієнти',
                        style: TextStyle(
                          color: _ChefColors.bg,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Фото продуктів → рецепти за 10 секунд',
                        style: TextStyle(
                          color: Color(0xA316130F),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _ChefColors.bg.withOpacity(.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_rounded,
                    color: _ChefColors.bg,
                    size: 19,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? _ChefColors.accent : _ChefColors.surface,
        borderRadius: BorderRadius.circular(17),
        border: selected ? null : Border.all(color: _ChefColors.surfaceStrong),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: selected ? _ChefColors.bg : _ChefColors.muted,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _FeaturedRecipeCard extends StatelessWidget {
  const _FeaturedRecipeCard({required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Відкрити рецепт ${recipe.title}',
      child: Material(
        color: _ChefColors.surface,
        borderRadius: AppRadius.xl,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 260,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _RecipeImage(recipe: recipe, iconSize: 64),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x1A16130F),
                        Color(0x8C16130F),
                        Color(0xEB0B0906),
                      ],
                    ),
                  ),
                ),
                const Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.md,
                  child: _GoldBadge(),
                ),
                Positioned(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: AppSpacing.md,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              recipe.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ChefColors.text,
                                fontSize: 24,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              '${recipe.totalTimeMinutes} хв · ${recipe.category} · ${recipe.difficulty}/5',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFE0D4BF),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFE7BC5A), Color(0xFFC7902F)],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x73D9A441),
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: _ChefColors.bg,
                        ),
                      ),
                    ],
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

class _CompactRecipeTile extends StatelessWidget {
  const _CompactRecipeTile({required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ChefColors.surface,
      borderRadius: AppRadius.lg,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: AppRadius.md,
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: _RecipeImage(recipe: recipe, iconSize: 34),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            recipe.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ChefColors.text,
                              fontSize: 15,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (recipe.isPremium)
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: _ChefColors.accent,
                            size: 16,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${recipe.totalTimeMinutes} хв · ${recipe.cuisine}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ChefColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(
                Icons.bookmark_border_rounded,
                color: Color(0xFF8D8271),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeImage extends StatelessWidget {
  const _RecipeImage({required this.recipe, required this.iconSize});

  final Recipe recipe;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (recipe.images.isEmpty) {
      return _ImageFallback(iconSize: iconSize);
    }

    return CachedNetworkImage(
      imageUrl: recipe.images.first,
      fit: BoxFit.cover,
      placeholder: (_, __) => _ImageFallback(iconSize: iconSize),
      errorWidget: (_, __, ___) => _ImageFallback(iconSize: iconSize),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.iconSize});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _ChefColors.surfaceStrong,
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_menu_rounded,
        size: iconSize,
        color: _ChefColors.muted,
      ),
    );
  }
}

class _GoldBadge extends StatelessWidget {
  const _GoldBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE7BC5A), Color(0xFFC7902F)],
        ),
        borderRadius: AppRadius.sm,
        boxShadow: [
          BoxShadow(
            color: Color(0x66D9A441),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 13, color: _ChefColors.bg),
          SizedBox(width: 4),
          Text(
            'Рекомендоване',
            style: TextStyle(
              color: _ChefColors.bg,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .6,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SafeArea(
            bottom: false,
            child: Row(
              children: [
                _SkeletonBox(width: 120, height: 12),
                Spacer(),
                _SkeletonBox(width: 44, height: 44, radius: 22),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),
          _SkeletonBox(width: 260, height: 74, radius: 12),
          SizedBox(height: AppSpacing.md),
          _SkeletonBox(width: double.infinity, height: 62, radius: 16),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _SkeletonBox(width: 62, height: 34, radius: 17),
              SizedBox(width: AppSpacing.xs),
              _SkeletonBox(width: 82, height: 34, radius: 17),
              SizedBox(width: AppSpacing.xs),
              _SkeletonBox(width: 74, height: 34, radius: 17),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          _SkeletonBox(width: double.infinity, height: 260, radius: 18),
          SizedBox(height: AppSpacing.sm),
          _SkeletonBox(width: double.infinity, height: 104, radius: 16),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 10,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _ChefColors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _ChefColors {
  static const bg = Color(0xFF16130F);
  static const surface = Color(0xFF221D16);
  static const surfaceStrong = Color(0xFF2E2820);
  static const text = Color(0xFFF3E9DA);
  static const muted = Color(0xFFB9AC98);
  static const accent = Color(0xFFD9A441);
}
