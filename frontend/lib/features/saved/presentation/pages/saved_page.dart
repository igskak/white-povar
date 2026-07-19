import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../recipes/presentation/widgets/recipe_card.dart';
import '../../../recipes/providers/recipe_provider.dart';

class SavedPage extends ConsumerWidget {
  const SavedPage({super.key, this.embeddedInDesktopShell = false});

  final bool embeddedInDesktopShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(currentUserProvider) != null;
    return LayoutBuilder(builder: (context, constraints) {
      final usesGlobalDesktopHeader =
          embeddedInDesktopShell && MediaQuery.sizeOf(context).width >= 1024;
      return Scaffold(
        appBar: usesGlobalDesktopHeader
            ? null
            : AppBar(title: const Text('Збережене')),
        body: SafeArea(
          child: isSignedIn ? const _SavedRecipesBody() : const _GuestState(),
        ),
      );
    });
  }
}

class _SavedRecipesBody extends ConsumerWidget {
  const _SavedRecipesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteRecipesProvider);
    return favorites.when(
      loading: () => const _SavedSkeleton(),
      error: (error, _) => StateView.error(
        title: 'Не вдалося завантажити збережене',
        subtitle: error.toString(),
        onRetry: () => ref.invalidate(favoriteRecipesProvider),
      ),
      data: (recipes) {
        if (recipes.isEmpty) {
          return StateView.empty(
            title: 'Ваша колекція починається тут',
            subtitle:
                'Збережіть рецепт зі сторінки рецепта, і він зʼявиться в цій добірці.',
            icon: Icons.bookmark_add_outlined,
            actionLabel: 'Знайти рецепт',
            onRetry: () => context.go('/search'),
          );
        }
        return ResponsiveContainer(
          maxWidth: 1180,
          child: RefreshIndicator(
            onRefresh: () async => ref.refresh(favoriteRecipesProvider.future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                      AppSpacing.md, AppSpacing.md, AppSpacing.sm),
                  sliver: SliverToBoxAdapter(
                    child: LayoutBuilder(
                        builder: (context, constraints) => Row(
                              children: [
                                Expanded(
                                  child: Text('Ваша колекція',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium),
                                ),
                                if (constraints.maxWidth >= 600)
                                  Text('${recipes.length} рецептів',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge),
                              ],
                            )),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.crossAxisExtent >= 1080
                          ? 3
                          : constraints.crossAxisExtent >= 600
                              ? 2
                              : 1;
                      return SliverGrid(
                        key: const ValueKey('saved-recipes-grid'),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          childAspectRatio: columns == 3 ? .72 : .68,
                          crossAxisSpacing: AppSpacing.md,
                          mainAxisSpacing: AppSpacing.md,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => RecipeCard(
                            recipe: recipes[index],
                            onTap: () =>
                                context.push('/recipes/${recipes[index].id}'),
                          ),
                          childCount: recipes.length,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SavedSkeleton extends StatelessWidget {
  const _SavedSkeleton();

  @override
  Widget build(BuildContext context) => ResponsiveContainer(
        maxWidth: 1180,
        child: CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: AppSkeleton(width: 210, height: 32),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.crossAxisExtent >= 1080
                      ? 3
                      : constraints.crossAxisExtent >= 600
                          ? 2
                          : 1;
                  return SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: columns == 3 ? .72 : .68,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, __) => const Card(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AppSkeleton(height: double.infinity),
                              ),
                              SizedBox(height: AppSpacing.md),
                              AppSkeleton(width: 180, height: 22),
                              SizedBox(height: AppSpacing.xs),
                              AppSkeleton(width: 120),
                            ],
                          ),
                        ),
                      ),
                      childCount: 6,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class _GuestState extends StatelessWidget {
  const _GuestState();

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const UserAvatar(radius: 36),
                const SizedBox(height: AppSpacing.lg),
                Text('Тримайте улюблені рецепти поруч',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                    'Каталог і пошук доступні без входу. Увійдіть, коли захочете зберігати рецепти та синхронізувати їх між пристроями.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Увійти, щоб зберігати',
                  icon: Icons.login,
                  expand: true,
                  onPressed: () => context
                      .go('/login?returnTo=${Uri.encodeComponent('/saved')}'),
                ),
              ],
            ),
          ),
        ),
      );
}
