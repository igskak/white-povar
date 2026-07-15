import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_models.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../subscription/providers/subscription_provider.dart';
import '../../providers/recipe_provider.dart';

class CookingModePage extends ConsumerStatefulWidget {
  const CookingModePage({super.key, required this.recipeId});
  final String recipeId;
  @override
  ConsumerState<CookingModePage> createState() => _CookingModePageState();
}

class _CookingModePageState extends ConsumerState<CookingModePage> {
  int _step = 0;
  bool _complete = false;

  @override
  Widget build(BuildContext context) {
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;
    final hasAccess = ref.watch(isPremiumProvider);
    return Scaffold(
      backgroundColor: AppColorsV2.ink,
      body: recipeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _CookingError(onExit: () => context.pop()),
        data: (recipe) {
          if (recipe.isPremium && !hasAccess) {
            return _CookingGate(
              onUnlock: () => _openGate(context, isAuthenticated),
            );
          }
          if (recipe.instructions.isEmpty) return const _CookingEmpty();
          _step = _step.clamp(0, recipe.instructions.length - 1);
          if (_complete) {
            return _CookingComplete(
              title: recipe.title,
              onExit: () => context.pop(),
            );
          }
          return _CookingStep(
            title: recipe.title,
            step: _step,
            steps: recipe.instructions,
            onExit: _confirmExit,
            onPrevious: _step == 0 ? null : () => setState(() => _step--),
            onNext: () {
              if (_step == recipe.instructions.length - 1) {
                setState(() => _complete = true);
              } else {
                setState(() => _step++);
              }
            },
          );
        },
      ),
    );
  }

  void _openGate(BuildContext context, bool authenticated) {
    final returnTo = '/recipes/${widget.recipeId}';
    if (!authenticated) {
      context.go('/login?returnTo=${Uri.encodeComponent(returnTo)}');
    } else {
      context.go(OfferRouteLocation.subscription(returnTo: returnTo).location);
    }
  }

  Future<void> _confirmExit() async {
    if (_step == 0) {
      context.pop();
      return;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершити приготування?'),
        content: const Text('Прогрес кроків буде втрачено.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Залишитись')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Вийти')),
        ],
      ),
    );
    if (exit == true && mounted) context.pop();
  }
}

class _CookingStep extends StatelessWidget {
  const _CookingStep(
      {required this.title,
      required this.step,
      required this.steps,
      required this.onExit,
      required this.onPrevious,
      required this.onNext});
  final String title;
  final int step;
  final List<String> steps;
  final VoidCallback onExit;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) {
    if (step >= steps.length) {
      return _CookingComplete(title: title, onExit: onExit);
    }
    final desktop = MediaQuery.sizeOf(context).width >= 1024;
    final content = _StepContent(
      step: step,
      steps: steps,
      onExit: onExit,
      onPrevious: onPrevious,
      onNext: onNext,
    );
    return SafeArea(
        child: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: desktop
                        ? Row(children: [
                            SizedBox(
                                width: 220,
                                child: _StepList(
                                    active: step, total: steps.length)),
                            const SizedBox(width: AppSpacing.xl),
                            Expanded(child: content)
                          ])
                        : content))));
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent(
      {required this.step,
      required this.steps,
      required this.onExit,
      required this.onPrevious,
      required this.onNext});
  final int step;
  final List<String> steps;
  final VoidCallback onExit;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AppIconButton(
              icon: Icons.close,
              tooltip: 'Вийти з режиму готування',
              onPressed: onExit,
              filled: true),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _Progress(step: step, total: steps.length))
        ]),
        const Spacer(),
        Text('КРОК ${step + 1}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColorsV2.accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8)),
        const SizedBox(height: AppSpacing.md),
        Semantics(
            liveRegion: true,
            child: Text(steps[step],
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppColorsV2.onInk, height: 1.25))),
        const Spacer(),
        Row(children: [
          Expanded(
              child: AppButton(
                  label: 'Назад',
                  icon: Icons.arrow_back,
                  onPressed: onPrevious,
                  variant: AppButtonVariant.secondary)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              flex: 2,
              child: AppButton(
                  label: step == steps.length - 1 ? 'Завершити' : 'Далі',
                  icon: step == steps.length - 1
                      ? Icons.check
                      : Icons.arrow_forward,
                  onPressed: onNext))
        ]),
      ]);
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});
  final int step;
  final int total;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Крок ${step + 1} з $total',
            style: const TextStyle(color: AppColorsV2.onInk)),
        const SizedBox(height: 4),
        LinearProgressIndicator(
            value: (step + 1) / total,
            color: AppColorsV2.accent,
            backgroundColor: Colors.white24)
      ]);
}

class _StepList extends StatelessWidget {
  const _StepList({required this.active, required this.total});
  final int active;
  final int total;
  @override
  Widget build(BuildContext context) => ListView.builder(
      shrinkWrap: true,
      itemCount: total,
      itemBuilder: (_, index) => ListTile(
          leading: CircleAvatar(
              backgroundColor: index == active
                  ? AppColorsV2.accent
                  : AppColorsV2.surfaceStrong,
              child: Text('${index + 1}')),
          title: Text('Крок ${index + 1}',
              style: const TextStyle(color: AppColorsV2.onInk))));
}

class _CookingComplete extends StatelessWidget {
  const _CookingComplete({required this.title, required this.onExit});
  final String title;
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.restaurant, size: 72, color: AppColorsV2.accent),
            const SizedBox(height: AppSpacing.md),
            Text('Смачного!',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(color: AppColorsV2.onInk)),
            const SizedBox(height: AppSpacing.sm),
            Text('Ви приготували «$title».',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColorsV2.onInk)),
            const SizedBox(height: AppSpacing.lg),
            AppButton(label: 'До рецепта', onPressed: onExit)
          ])));
}

class _CookingGate extends StatelessWidget {
  const _CookingGate({required this.onUnlock});
  final VoidCallback onUnlock;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock, size: 52, color: AppColorsV2.accent),
            const SizedBox(height: AppSpacing.md),
            Text('Режим готування — у Premium',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: AppColorsV2.onInk),
                textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Відкрити Premium', onPressed: onUnlock)
          ])));
}

class _CookingEmpty extends StatelessWidget {
  const _CookingEmpty();
  @override
  Widget build(BuildContext context) => const Center(
      child: Text('Кроки ще не додані',
          style: TextStyle(color: AppColorsV2.onInk)));
}

class _CookingError extends StatelessWidget {
  const _CookingError({required this.onExit});
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) =>
      Center(child: AppButton(label: 'Повернутися', onPressed: onExit));
}
