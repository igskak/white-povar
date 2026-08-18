import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_models.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../menu_plan/providers/menu_plan_provider.dart';
import '../../../pantry/providers/pantry_provider.dart';
import '../../../subscription/widgets/premium_badge.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../widgets/content_detail_sections.dart';
import '../widgets/favorite_button.dart';
import '../widgets/recipe_photo.dart';
import '../widgets/recipe_video_widget.dart';

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage(
      {super.key, required this.recipeId, this.collectionId});
  final String recipeId;

  /// Set when this material was opened from a collection that marked it a free
  /// preview. The server re-checks the grant before it unlocks anything.
  final String? collectionId;

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  bool _viewRecorded = false;

  String get _cookingLocation => PreviewGrant.appendTo(
      '/recipes/${widget.recipeId}/cook', widget.collectionId);

  RecipeDetailRequest get _request =>
      (recipeId: widget.recipeId, collectionId: widget.collectionId);

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(_request));
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: recipeAsync.when(
        loading: () => const _RecipeDetailSkeleton(),
        error: (error, _) => StateView.error(
          title: _isOffline(error)
              ? 'Немає з’єднання'
              : 'Не вдалося завантажити рецепт',
          subtitle: _isOffline(error)
              ? 'Перевірте інтернет і спробуйте ще раз.'
              : 'Спробуйте відкрити рецепт ще раз.',
          onRetry: () => ref.invalidate(recipeDetailProvider(_request)),
        ),
        data: (recipe) {
          if (auth.isAuthenticated && !_viewRecorded) {
            _viewRecorded = true;
            // Never block rendering or offline access on a private history write.
            ref
                .read(recipeServiceProvider)
                .recordHistory(recipe.id, 'viewed')
                .catchError((_) {});
          }
          // The server's projection is the access decision; guessing again from
          // a local subscription flag re-locks free previews and one-off
          // collection purchases that never granted tenant-wide premium.
          final locked = recipe.isLocked;
          final canCook = (recipe.contentKind == ContentKind.recipe ||
                  recipe.contentKind == ContentKind.process) &&
              recipe.instructions.isNotEmpty;
          return _RecipeDetailContent(
            recipe: recipe,
            locked: locked,
            onUnlock: () => _openGate(context, auth.isAuthenticated),
            primaryActionLabel: locked ? 'Відкрити Premium' : 'Почати готувати',
            primaryActionIcon:
                locked ? Icons.workspace_premium : Icons.soup_kitchen_outlined,
            onPrimaryAction: locked
                ? () => _openGate(context, auth.isAuthenticated)
                : canCook
                    ? () => context.push(_cookingLocation)
                    : null,
            onAddToShopping: locked || !auth.isAuthenticated
                ? null
                : () async {
                    await ref
                        .read(pantryServiceProvider)
                        .addRecipe(recipe.id, recipe.servings);
                    ref.invalidate(shoppingProvider);
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Відсутні інгредієнти додано до покупок')));
                  },
            onAddToPlan: locked || !auth.isAuthenticated
                ? null
                : () async {
                    await ref.read(menuPlanServiceProvider).add(
                        day: DateTime.now(),
                        recipeId: recipe.id,
                        servings: recipe.servings);
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                            content: Text('Рецепт заплановано на сьогодні')));
                  },
          );
        },
      ),
      bottomNavigationBar: recipeAsync.maybeWhen(
        data: (recipe) {
          // Desktop carries these actions in the recipe header instead.
          if (MediaQuery.sizeOf(context).width >= AppLayout.desktopBreakpoint) {
            return null;
          }
          // The server's projection is the access decision; guessing again from
          // a local subscription flag re-locks free previews and one-off
          // collection purchases that never granted tenant-wide premium.
          final locked = recipe.isLocked;
          final canCook = (recipe.contentKind == ContentKind.recipe ||
                  recipe.contentKind == ContentKind.process) &&
              recipe.instructions.isNotEmpty;
          if (!locked && !canCook) return null;
          return _BottomAction(
            enabled: locked || canCook,
            label: locked ? 'Відкрити Premium' : 'Почати готувати',
            icon:
                locked ? Icons.workspace_premium : Icons.soup_kitchen_outlined,
            onPressed: () => locked
                ? _openGate(context, auth.isAuthenticated)
                : context.push(_cookingLocation),
          );
        },
        orElse: () => null,
      ),
    );
  }

  void _openGate(BuildContext context, bool authenticated) {
    final returnTo = '/recipes/${widget.recipeId}';
    if (!authenticated) {
      context.go('/login?returnTo=${Uri.encodeComponent(returnTo)}');
      return;
    }
    context.push(OfferRouteLocation.subscription(returnTo: returnTo).location);
  }
}

bool _hasVideo(Recipe recipe) =>
    (recipe.videoUrl?.isNotEmpty ?? false) ||
    (recipe.videoFilePath?.isNotEmpty ?? false);

bool _isOffline(Object error) =>
    error is SocketException ||
    error.toString().toLowerCase().contains('network') ||
    error.toString().toLowerCase().contains('connection');

class _RecipeDetailContent extends StatelessWidget {
  const _RecipeDetailContent(
      {required this.recipe,
      required this.locked,
      required this.onUnlock,
      required this.primaryActionLabel,
      required this.primaryActionIcon,
      this.onPrimaryAction,
      this.onAddToShopping,
      this.onAddToPlan});
  final Recipe recipe;
  final bool locked;
  final VoidCallback onUnlock;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final Future<void> Function()? onAddToShopping;
  final Future<void> Function()? onAddToPlan;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppLayout.desktopBreakpoint) {
            return _DesktopRecipeContent(
              recipe: recipe,
              locked: locked,
              onUnlock: onUnlock,
              primaryActionLabel: primaryActionLabel,
              primaryActionIcon: primaryActionIcon,
              onPrimaryAction: onPrimaryAction,
              onAddToShopping: onAddToShopping,
              onAddToPlan: onAddToPlan,
            );
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _RecipeHero(recipe: recipe),
                _RecipeBody(
                  recipe: recipe,
                  locked: locked,
                  onUnlock: onUnlock,
                  onAddToShopping: onAddToShopping,
                  onAddToPlan: onAddToPlan,
                ),
              ],
            ),
          );
        },
      );
}

class _RecipeHero extends StatelessWidget {
  const _RecipeHero({required this.recipe});
  final Recipe recipe;
  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(fit: StackFit.expand, children: [
          RecipePhoto(
            recipe: recipe,
            role: RecipeImageRole.detail,
            targetWidth: MediaQuery.sizeOf(context).width,
          ),
          DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [
                0.0,
                0.3,
                1.0
              ],
                      colors: [
                AppColorsV2.ink.withOpacity(.30),
                AppColorsV2.ink.withOpacity(0),
                AppColorsV2.ink.withOpacity(0),
              ]))),
          Positioned(
              top: AppSpacing.md,
              left: AppSpacing.sm,
              child: AppIconButton(
                  icon: Icons.arrow_back,
                  tooltip: 'Назад',
                  onPressed: () => Navigator.of(context).maybePop(),
                  filled: true)),
          if (recipe.isPremium)
            const Positioned(
                top: AppSpacing.md,
                right: 56,
                child: PremiumBadge(size: 24, showLabel: true)),
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child:
                FavoriteButton(recipeId: recipe.id, color: AppColorsV2.onInk),
          ),
        ]),
      );
}

class _DesktopRecipeContent extends StatelessWidget {
  const _DesktopRecipeContent({
    required this.recipe,
    required this.locked,
    required this.onUnlock,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    required this.onPrimaryAction,
    this.onAddToShopping,
    this.onAddToPlan,
  });

  final Recipe recipe;
  final bool locked;
  final VoidCallback onUnlock;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final Future<void> Function()? onAddToShopping;
  final Future<void> Function()? onAddToPlan;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
      child: ResponsiveContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    key: const ValueKey('desktop-recipe-hero-pane'),
                    borderRadius: AppRadius.xl,
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: _RecipeHero(recipe: recipe),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xxl),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.title, style: theme.textTheme.headlineLarge),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        recipe.description,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: context.semantic.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _StatsRow(recipe: recipe),
                      const SizedBox(height: AppSpacing.lg),
                      // The actions live with the recipe rather than in a
                      // full-width bar pinned to the bottom of the window,
                      // which on a wide monitor parked the primary call to
                      // action hundreds of pixels away from the content.
                      if (locked)
                        PremiumGateCard(
                          title: 'Рецепт від шефа — у Premium',
                          message:
                              'Повний рецепт, відео й режим приготування доступні з Premium.',
                          ctaLabel: 'Відкрити Premium',
                          onUnlock: onUnlock,
                        )
                      else
                        _DesktopRecipeActions(
                          recipeId: recipe.id,
                          primaryActionLabel: primaryActionLabel,
                          primaryActionIcon: primaryActionIcon,
                          onPrimaryAction: onPrimaryAction,
                          showAddToShopping: recipe.contentKind.hasIngredients,
                          onAddToShopping: onAddToShopping,
                          onAddToPlan: onAddToPlan,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (!locked) ...[
              const SizedBox(height: AppSpacing.xxxl),
              ContentDetailSections(
                contentKind: recipe.contentKind,
                ingredients: recipe.ingredients,
                steps: recipe.instructions,
                leading: _hasVideo(recipe)
                    ? _RecipeVideoSection(recipe: recipe)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The video, or nothing at all when the recipe has none.
class _RecipeVideoSection extends StatelessWidget {
  const _RecipeVideoSection({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Відео рецепта', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          RecipeVideoWidget(
            videoUrl: recipe.videoUrl,
            videoFilePath: recipe.videoFilePath,
            borderRadius: AppRadius.lg,
          ),
        ],
      );
}

/// Primary call to action plus the per-recipe utilities, laid out as a [Wrap]
/// so a narrow desktop column folds them onto a second line instead of
/// overflowing.
class _DesktopRecipeActions extends StatelessWidget {
  const _DesktopRecipeActions({
    required this.recipeId,
    required this.primaryActionLabel,
    required this.primaryActionIcon,
    required this.onPrimaryAction,
    required this.showAddToShopping,
    this.onAddToShopping,
    this.onAddToPlan,
  });

  final String recipeId;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final bool showAddToShopping;
  final Future<void> Function()? onAddToShopping;
  final Future<void> Function()? onAddToPlan;

  @override
  Widget build(BuildContext context) => Wrap(
        key: const ValueKey('desktop-recipe-actions'),
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          AppButton(
            label: primaryActionLabel,
            icon: primaryActionIcon,
            onPressed: onPrimaryAction,
          ),
          FavoriteButton(recipeId: recipeId),
          IconButton(
            tooltip: 'Поділитися',
            onPressed: () => _copyLink(context),
            icon: const Icon(Icons.share_outlined),
          ),
          _SecondaryRecipeActions(
            showAddToShopping: showAddToShopping,
            onAddToShopping: onAddToShopping,
            onAddToPlan: onAddToPlan,
          ),
        ],
      );

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: '/recipes/$recipeId'));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Посилання на рецепт скопійовано')),
    );
  }
}

/// The narrow layout: hero photo, then everything in one column. Desktop is
/// composed separately by [_DesktopRecipeContent].
class _RecipeBody extends StatelessWidget {
  const _RecipeBody(
      {required this.recipe,
      required this.locked,
      required this.onUnlock,
      this.onAddToShopping,
      this.onAddToPlan});
  final Recipe recipe;
  final bool locked;
  final VoidCallback onUnlock;
  final Future<void> Function()? onAddToShopping;
  final Future<void> Function()? onAddToPlan;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          108,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(recipe.title,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.md),
              Text(recipe.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: context.semantic.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              _StatsRow(recipe: recipe),
              if (!locked) ...[
                const SizedBox(height: AppSpacing.sm),
                _SecondaryRecipeActions(
                  showAddToShopping: recipe.contentKind.hasIngredients,
                  onAddToShopping: onAddToShopping,
                  onAddToPlan: onAddToPlan,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (locked)
                PremiumGateCard(
                  title: 'Рецепт від шефа — у Premium',
                  message:
                      'Повний рецепт, відео й режим приготування доступні з Premium.',
                  ctaLabel: 'Відкрити Premium',
                  onUnlock: onUnlock,
                )
              else
                ContentDetailSections(
                  contentKind: recipe.contentKind,
                  ingredients: recipe.ingredients,
                  steps: recipe.instructions,
                  leading: _hasVideo(recipe)
                      ? _RecipeVideoSection(recipe: recipe)
                      : null,
                ),
            ]),
          ),
        ),
      );
}

enum _RecipeSecondaryAction { shopping, plan }

class _SecondaryRecipeActions extends StatelessWidget {
  const _SecondaryRecipeActions({
    required this.showAddToShopping,
    this.onAddToShopping,
    this.onAddToPlan,
  });

  /// Whether the shopping action applies to this content at all. A disabled
  /// handler means "not right now" — locked, or signed out — and stays visible
  /// as a greyed entry; this instead removes an action the content can never
  /// perform, having no ingredients to add.
  final bool showAddToShopping;
  final Future<void> Function()? onAddToShopping;
  final Future<void> Function()? onAddToPlan;

  @override
  Widget build(BuildContext context) => PopupMenuButton<_RecipeSecondaryAction>(
        tooltip: 'Інші дії',
        enabled: (showAddToShopping && onAddToShopping != null) ||
            onAddToPlan != null,
        onSelected: (action) {
          switch (action) {
            case _RecipeSecondaryAction.shopping:
              onAddToShopping?.call();
              break;
            case _RecipeSecondaryAction.plan:
              onAddToPlan?.call();
              break;
          }
        },
        itemBuilder: (_) => [
          if (showAddToShopping)
            PopupMenuItem(
              value: _RecipeSecondaryAction.shopping,
              enabled: onAddToShopping != null,
              child: const ListTile(
                leading: Icon(Icons.add_shopping_cart_outlined),
                title: Text('Додати до покупок'),
              ),
            ),
          PopupMenuItem(
            value: _RecipeSecondaryAction.plan,
            enabled: onAddToPlan != null,
            child: const ListTile(
              leading: Icon(Icons.calendar_month_outlined),
              title: Text('Запланувати'),
            ),
          ),
        ],
        child: const Chip(
          avatar: Icon(Icons.more_horiz, size: 18),
          label: Text('Покупки та план'),
        ),
      );
}

class _BottomAction extends StatelessWidget {
  const _BottomAction(
      {required this.enabled,
      required this.label,
      required this.icon,
      required this.onPressed});
  final bool enabled;
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SafeArea(
      child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppButton(
              label: label,
              icon: icon,
              onPressed: enabled ? onPressed : null,
              expand: true)));
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.recipe});
  final Recipe recipe;
  @override
  Widget build(BuildContext context) => Row(
          children: [
        _Stat(
            icon: Icons.schedule_rounded,
            value: '${recipe.totalTimeMinutes} хв',
            label: 'Час'),
        _Stat(
            icon: Icons.speed_rounded,
            value: '${recipe.difficulty}/5',
            label: 'Складність'),
        _Stat(
            icon: Icons.people_outline_rounded,
            value: '${recipe.servings}',
            label: 'Порції'),
      ]
              .map((item) => Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: item)))
              .toList());
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => DecoratedBox(
      decoration: BoxDecoration(
          color: context.semantic.surfaceStrong, borderRadius: AppRadius.md),
      child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
          child: Column(children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge),
            Text(label, style: Theme.of(context).textTheme.labelSmall)
          ])));
}

class _RecipeDetailSkeleton extends StatelessWidget {
  const _RecipeDetailSkeleton();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          const detail = Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(width: 260, height: 28),
                SizedBox(height: AppSpacing.lg),
                AppSkeleton(height: 92),
                SizedBox(height: AppSpacing.xl),
                AppSkeleton(height: 260),
              ],
            ),
          );
          if (constraints.maxWidth >= AppLayout.desktopBreakpoint) {
            // Mirrors the loaded composition — hero pane on the left, recipe
            // summary on the right — so the page does not reflow once the
            // payload lands.
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: ResponsiveContainer(
                child: Row(
                  key: ValueKey('desktop-recipe-skeleton'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: AppSkeleton(
                          height: double.infinity,
                          borderRadius: AppRadius.xl,
                        ),
                      ),
                    ),
                    SizedBox(width: AppSpacing.xxl),
                    Expanded(flex: 4, child: detail),
                  ],
                ),
              ),
            );
          }
          return const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSkeleton(
                  height: 320,
                  borderRadius: BorderRadius.zero,
                ),
                detail,
              ],
            ),
          );
        },
      );
}
