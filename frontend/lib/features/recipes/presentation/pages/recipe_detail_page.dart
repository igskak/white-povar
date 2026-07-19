import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_models.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../pantry/providers/pantry_provider.dart';
import '../../../menu_plan/providers/menu_plan_provider.dart';
import '../../../subscription/providers/subscription_provider.dart';
import '../../../subscription/widgets/premium_badge.dart';
import '../../models/recipe.dart';
import '../../providers/recipe_provider.dart';
import '../widgets/content_detail_sections.dart';
import '../widgets/favorite_button.dart';
import '../widgets/recipe_video_widget.dart';

class RecipeDetailPage extends ConsumerStatefulWidget {
  const RecipeDetailPage({super.key, required this.recipeId});
  final String recipeId;

  @override
  ConsumerState<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends ConsumerState<RecipeDetailPage> {
  bool _viewRecorded = false;

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));
    final auth = ref.watch(authProvider);
    final hasPremiumAccess = ref.watch(isPremiumProvider);

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
          onRetry: () => ref.invalidate(recipeDetailProvider(widget.recipeId)),
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
          final locked =
              recipe.isLocked || (recipe.isPremium && !hasPremiumAccess);
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
                    ? () => context.push('/recipes/${widget.recipeId}/cook')
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
          if (MediaQuery.sizeOf(context).width >= 1024) return null;
          final locked =
              recipe.isLocked || (recipe.isPremium && !hasPremiumAccess);
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
                : context.push('/recipes/${widget.recipeId}/cook'),
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
          final desktop = constraints.maxWidth >= 1024;
          final hero = _RecipeHero(recipe: recipe, expand: desktop);
          final body = _RecipeBody(
              recipe: recipe,
              locked: locked,
              onUnlock: onUnlock,
              desktop: desktop,
              primaryActionLabel: primaryActionLabel,
              primaryActionIcon: primaryActionIcon,
              onPrimaryAction: onPrimaryAction,
              onAddToShopping: onAddToShopping,
              onAddToPlan: onAddToPlan);
          if (desktop) {
            return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 520, child: hero),
                  Expanded(child: body)
                ]);
          }
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(child: hero),
            SliverFillRemaining(hasScrollBody: false, child: body)
          ]);
        },
      );
}

class _RecipeHero extends StatelessWidget {
  const _RecipeHero({required this.recipe, this.expand = false});
  final Recipe recipe;
  final bool expand;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: expand ? null : 320,
        child: Stack(fit: StackFit.expand, children: [
          _RecipeHeroImage(recipe: recipe),
          const DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x66000000), Color(0xE616130F)]))),
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
          Positioned(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Text(recipe.title,
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(color: AppColorsV2.onInk))),
        ]),
      );
}

class _RecipeBody extends StatelessWidget {
  const _RecipeBody(
      {required this.recipe,
      required this.locked,
      required this.onUnlock,
      required this.desktop,
      required this.primaryActionLabel,
      required this.primaryActionIcon,
      this.onPrimaryAction,
      this.onAddToShopping,
      this.onAddToPlan});
  final Recipe recipe;
  final bool locked;
  final VoidCallback onUnlock;
  final bool desktop;
  final String primaryActionLabel;
  final IconData primaryActionIcon;
  final VoidCallback? onPrimaryAction;
  final Future<void> Function()? onAddToShopping;
  final Future<void> Function()? onAddToPlan;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            desktop ? AppSpacing.xxl : AppSpacing.md,
            desktop ? AppSpacing.xl : AppSpacing.lg,
            desktop ? AppSpacing.xxl : AppSpacing.md,
            desktop ? AppSpacing.xl : 108),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(recipe.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppColorsV2.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              _StatsRow(recipe: recipe),
              if (desktop && onPrimaryAction != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    onPressed: onPrimaryAction,
                    icon: Icon(primaryActionIcon),
                    label: Text(primaryActionLabel),
                  ),
                ),
              ],
              if (!locked) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                    label: 'Додати відсутнє до покупок',
                    icon: Icons.add_shopping_cart_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: onAddToShopping),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                    label: 'Запланувати на тиждень',
                    icon: Icons.calendar_month_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: onAddToPlan),
              ],
              const SizedBox(height: AppSpacing.xl),
              if (locked)
                _PremiumGate(onUnlock: onUnlock)
              else
                ContentDetailSections(
                  ingredients: recipe.ingredients,
                  steps: recipe.instructions,
                  leading: recipe.videoUrl != null ||
                          recipe.videoFilePath != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text('Відео рецепта',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: AppSpacing.sm),
                              RecipeVideoWidget(
                                  videoUrl: recipe.videoUrl,
                                  videoFilePath: recipe.videoFilePath,
                                  height: 220,
                                  borderRadius: AppRadius.lg),
                            ])
                      : null,
                ),
            ]),
          ),
        ),
      );
}

class _PremiumGate extends StatelessWidget {
  const _PremiumGate({required this.onUnlock});
  final VoidCallback onUnlock;
  @override
  Widget build(BuildContext context) => ContentCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(children: [
          const PremiumBadge(size: 30),
          const SizedBox(height: AppSpacing.sm),
          Text('Рецепт від шефа — у Premium',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('Повний рецепт, відео й режим приготування доступні з Premium.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColorsV2.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          AppButton(
              label: 'Відкрити Premium',
              icon: Icons.workspace_premium,
              onPressed: onUnlock,
              expand: true),
        ]),
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

class _RecipeHeroImage extends StatelessWidget {
  const _RecipeHeroImage({required this.recipe});
  final Recipe recipe;
  @override
  Widget build(BuildContext context) => recipe.images.isEmpty
      ? const _HeroFallback()
      : CachedNetworkImage(
          imageUrl: recipe.images.first,
          fit: BoxFit.cover,
          placeholder: (_, __) => const _HeroFallback(isLoading: true),
          errorWidget: (_, __, ___) => const _HeroFallback());
}

class _HeroFallback extends StatelessWidget {
  const _HeroFallback({this.isLoading = false});
  final bool isLoading;
  @override
  Widget build(BuildContext context) => Container(
      color: AppColorsV2.ink,
      alignment: Alignment.center,
      child: isLoading
          ? const CircularProgressIndicator()
          : const Icon(Icons.restaurant_menu_rounded,
              size: 72, color: AppColorsV2.onInk));
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
      decoration: const BoxDecoration(
          color: AppColorsV2.surfaceStrong, borderRadius: AppRadius.md),
      child: Padding(
          padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm, horizontal: AppSpacing.xs),
          child: Column(children: [
            Icon(icon, color: AppColorsV2.accent),
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
  Widget build(BuildContext context) => const SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
            height: 320, child: ColoredBox(color: AppColorsV2.surfaceStrong)),
        Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Column(children: [
              SizedBox(
                  height: 20,
                  width: double.infinity,
                  child: ColoredBox(color: AppColorsV2.surfaceStrong)),
              SizedBox(height: AppSpacing.md),
              SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: ColoredBox(color: AppColorsV2.surfaceStrong))
            ]))
      ]));
}
