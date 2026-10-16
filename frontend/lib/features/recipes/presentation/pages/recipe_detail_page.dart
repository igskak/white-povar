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
  const RecipeDetailPage({
    super.key,
    required this.recipeId,
    this.collectionId,
    this.initialRecipe,
  });
  final String recipeId;

  /// Set when this material was opened from a collection that marked it a free
  /// preview. The server re-checks the grant before it unlocks anything.
  final String? collectionId;

  /// The list projection selected on the previous screen. Its image and public
  /// summary remain visible while the server verifies access to the body.
  final Recipe? initialRecipe;

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  bool _viewRecorded = false;
  bool _actionInFlight = false;
  String? _servingsRecipeId;
  int? _selectedServings;
  final Set<String> _checkedIngredientIds = <String>{};

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
        loading: () => _RecipeDetailSkeleton(recipe: widget.initialRecipe),
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
          final selectedServings = _servingsRecipeId == recipe.id
              ? _selectedServings ?? recipe.servings
              : recipe.servings;
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
            selectedServings: selectedServings,
            checkedIngredientIds: _servingsRecipeId == recipe.id
                ? _checkedIngredientIds
                : const <String>{},
            onDecreaseServings: selectedServings > 1
                ? () => _setServings(recipe.id, selectedServings - 1)
                : null,
            onIncreaseServings: () =>
                _setServings(recipe.id, selectedServings + 1),
            onIngredientToggled: (ingredientId) =>
                _toggleIngredient(recipe.id, ingredientId),
            onAddToShopping: locked || !auth.isAuthenticated || _actionInFlight
                ? null
                : () async {
                    await _runAction(
                      success: 'Відсутні інгредієнти додано до покупок',
                      failure: 'Не вдалося додати до покупок. Спробуйте ще раз',
                      action: () async {
                        await ref
                            .read(pantryServiceProvider)
                            .addRecipe(recipe.id, selectedServings);
                        ref.invalidate(shoppingProvider);
                      },
                    );
                  },
            onAddToPlan: locked || !auth.isAuthenticated || _actionInFlight
                ? null
                : () async {
                    await _runAction(
                      success: 'Рецепт заплановано на сьогодні',
                      failure: 'Не вдалося запланувати рецепт. Спробуйте ще раз',
                      action: () => ref.read(menuPlanServiceProvider).add(
                            day: DateTime.now(),
                            recipeId: recipe.id,
                            servings: selectedServings,
                          ),
                    );
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

  void _setServings(String recipeId, int value) => setState(() {
        if (_servingsRecipeId != recipeId) _checkedIngredientIds.clear();
        _servingsRecipeId = recipeId;
        _selectedServings = value < 1 ? 1 : value;
      });

  void _toggleIngredient(String recipeId, String ingredientId) => setState(() {
        if (_servingsRecipeId != recipeId) {
          _servingsRecipeId = recipeId;
          _selectedServings = null;
          _checkedIngredientIds.clear();
        }
        if (!_checkedIngredientIds.add(ingredientId)) {
          _checkedIngredientIds.remove(ingredientId);
        }
      });

  Future<void> _runAction({
    required Future<void> Function() action,
    required String success,
    required String failure,
  }) async {
    if (_actionInFlight) return;
    setState(() => _actionInFlight = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure)));
      }
    } finally {
      if (mounted) setState(() => _actionInFlight = false);
    }
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
      required this.selectedServings,
      required this.checkedIngredientIds,
      this.onDecreaseServings,
      this.onIncreaseServings,
      this.onIngredientToggled,
      this.onAddToShopping,
      this.onAddToPlan});
  final Recipe recipe;
  final bool locked;
  final VoidCallback onUnlock;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final int selectedServings;
  final Set<String> checkedIngredientIds;
  final VoidCallback? onDecreaseServings;
  final VoidCallback? onIncreaseServings;
  final ValueChanged<String>? onIngredientToggled;
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
              selectedServings: selectedServings,
              checkedIngredientIds: checkedIngredientIds,
              onDecreaseServings: onDecreaseServings,
              onIncreaseServings: onIncreaseServings,
              onIngredientToggled: onIngredientToggled,
              onAddToShopping: onAddToShopping,
              onAddToPlan: onAddToPlan,
            );
          }
          return SingleChildScrollView(
            child: _RecipeBody(
              recipe: recipe,
              locked: locked,
              onUnlock: onUnlock,
              selectedServings: selectedServings,
              checkedIngredientIds: checkedIngredientIds,
              onDecreaseServings: onDecreaseServings,
              onIncreaseServings: onIncreaseServings,
              onIngredientToggled: onIngredientToggled,
              onAddToShopping: onAddToShopping,
              onAddToPlan: onAddToPlan,
            ),
          );
        },
      );
}

class _RecipeHero extends StatelessWidget {
  const _RecipeHero({
    required this.recipe,
    this.transitionBorderRadius = BorderRadius.zero,
  });
  final Recipe recipe;
  final BorderRadius transitionBorderRadius;
  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 4 / 3,
        child: Stack(fit: StackFit.expand, children: [
          RecipeImageHero(
            key: ValueKey('recipe-detail-image-${recipe.id}'),
            recipeId: recipe.id,
            borderRadius: transitionBorderRadius,
            child: RecipePhoto(
              recipe: recipe,
              role: RecipeImageRole.detail,
              targetWidth: MediaQuery.sizeOf(context).width,
            ),
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
    required this.selectedServings,
    required this.checkedIngredientIds,
    this.onDecreaseServings,
    this.onIncreaseServings,
    this.onIngredientToggled,
    this.onAddToShopping,
    this.onAddToPlan,
  });

  final Recipe recipe;
  final bool locked;
  final VoidCallback onUnlock;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final int selectedServings;
  final Set<String> checkedIngredientIds;
  final VoidCallback? onDecreaseServings;
  final VoidCallback? onIncreaseServings;
  final ValueChanged<String>? onIngredientToggled;
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
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('До рецептів'),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(recipe.category.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                )),
            const SizedBox(height: AppSpacing.xs),
            Text(recipe.title,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontFamily: AppFonts.body,
                  fontWeight: FontWeight.w600,
                  fontSize: 32,
                )),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                  child: _StatsRow(recipe: recipe, servings: selectedServings)),
              const SizedBox(width: AppSpacing.lg),
              if (!locked)
                _DesktopRecipeActions(
                  recipeId: recipe.id,
                  primaryActionLabel: primaryActionLabel,
                  primaryActionIcon: primaryActionIcon,
                  onPrimaryAction: onPrimaryAction,
                  showAddToShopping: recipe.contentKind.hasIngredients,
                  onAddToShopping: onAddToShopping,
                  onAddToPlan: onAddToPlan,
                ),
            ]),
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
              Row(
                key: const ValueKey('recipe-sections-two-column'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            key: const ValueKey('desktop-recipe-hero-pane'),
                            borderRadius: AppRadius.lg,
                            child: AspectRatio(
                              aspectRatio: 4 / 3,
                              child: _RecipeHero(recipe: recipe),
                            ),
                          ),
                          if (recipe.description.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.lg),
                            Text(recipe.description,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: context.semantic.textSecondary,
                                )),
                          ],
                          if (_hasVideo(recipe)) ...[
                            const SizedBox(height: AppSpacing.xl),
                            _RecipeVideoSection(recipe: recipe),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppLayout.narrowMax,
                            ),
                            child:
                                RecipeStepsSection(steps: recipe.instructions),
                          ),
                        ]),
                  ),
                  if (recipe.contentKind.hasIngredients) ...[
                    const SizedBox(width: AppSpacing.xxl),
                    SizedBox(
                      width: AppLayout.sideColumn,
                      child: RecipeIngredientsSection(
                        ingredients: recipe.ingredients,
                        selectedServings: selectedServings,
                        baseServings: recipe.servings,
                        onDecreaseServings: onDecreaseServings,
                        onIncreaseServings: onIncreaseServings,
                        checkedIngredientIds: checkedIngredientIds,
                        onIngredientToggled: onIngredientToggled,
                      ),
                    ),
                  ],
                ],
              ),
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
      required this.selectedServings,
      required this.checkedIngredientIds,
      this.onDecreaseServings,
      this.onIncreaseServings,
      this.onIngredientToggled,
      this.onAddToShopping,
      this.onAddToPlan});
  final Recipe recipe;
  final bool locked;
  final VoidCallback onUnlock;
  final int selectedServings;
  final Set<String> checkedIngredientIds;
  final VoidCallback? onDecreaseServings;
  final VoidCallback? onIncreaseServings;
  final ValueChanged<String>? onIngredientToggled;
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
              Text(
                'ВІД ШЕФА',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                recipe.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(recipe.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: context.semantic.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              _StatsRow(recipe: recipe, servings: selectedServings),
              if (!locked) ...[
                const SizedBox(height: AppSpacing.sm),
                _SecondaryRecipeActions(
                  showAddToShopping: recipe.contentKind.hasIngredients,
                  onAddToShopping: onAddToShopping,
                  onAddToPlan: onAddToPlan,
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              ClipRRect(
                borderRadius: AppRadius.lg,
                child: AspectRatio(
                  aspectRatio: 1.4,
                  child: _RecipeHero(
                    recipe: recipe,
                    transitionBorderRadius: AppRadius.lg,
                  ),
                ),
              ),
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
                  selectedServings: selectedServings,
                  baseServings: recipe.servings,
                  onDecreaseServings: onDecreaseServings,
                  onIncreaseServings: onIncreaseServings,
                  checkedIngredientIds: checkedIngredientIds,
                  onIngredientToggled: onIngredientToggled,
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
  const _StatsRow({required this.recipe, this.servings});
  final Recipe recipe;
  final int? servings;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: context.semantic.outlineVariant),
        ),
      ),
      child: Row(
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
            value: '${servings ?? recipe.servings}',
            label: 'Порції'),
      ]
              .map((item) => Expanded(
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: item)))
              .toList()));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
        const SizedBox(height: AppSpacing.xxs),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge),
        Text(label, style: Theme.of(context).textTheme.labelSmall)
      ]));
}

class _RecipeDetailSkeleton extends StatelessWidget {
  const _RecipeDetailSkeleton({this.recipe});

  final Recipe? recipe;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final detail = Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recipe == null)
                  const AppSkeleton(width: 260, height: 28)
                else
                  Text(recipe!.title,
                      style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppSpacing.lg),
                if (recipe == null)
                  const AppSkeleton(height: 92)
                else if (recipe!.description.isNotEmpty)
                  Text(recipe!.description,
                      style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: AppSpacing.xl),
                // Never render ingredients or instructions from route extras:
                // only the detail response can establish current access.
                const AppSkeleton(height: 260),
              ],
            ),
          );
          if (constraints.maxWidth >= AppLayout.desktopBreakpoint) {
            // Mirrors the loaded composition — hero pane on the left, recipe
            // summary on the right — so the page does not reflow once the
            // payload lands.
            return SingleChildScrollView(
                child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: ResponsiveContainer(
                child: Row(
                  key: const ValueKey('desktop-recipe-skeleton'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: ClipRRect(
                        borderRadius: AppRadius.xl,
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: recipe == null
                              ? const AppSkeleton(
                                  height: double.infinity,
                                  borderRadius: AppRadius.xl,
                                )
                              : _RecipeHero(
                                  recipe: recipe!,
                                  transitionBorderRadius: AppRadius.xl,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxl),
                    Expanded(flex: 4, child: detail),
                  ],
                ),
              ),
            ));
          }
          return SingleChildScrollView(
            child: Column(
              key: const ValueKey('mobile-recipe-skeleton'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: recipe == null
                      ? const AppSkeleton(
                          height: double.infinity,
                          borderRadius: BorderRadius.zero,
                        )
                      : _RecipeHero(recipe: recipe!),
                ),
                detail,
              ],
            ),
          );
        },
      );
}
