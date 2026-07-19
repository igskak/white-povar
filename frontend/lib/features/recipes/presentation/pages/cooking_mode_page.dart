import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../app/router/route_models.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../subscription/providers/subscription_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../services/cooking_progress_store.dart';
import '../../models/recipe.dart';

class CookingModePage extends ConsumerStatefulWidget {
  const CookingModePage({super.key, required this.recipeId});
  final String recipeId;
  @override
  ConsumerState<CookingModePage> createState() => _CookingModePageState();
}

class _CookingModePageState extends ConsumerState<CookingModePage> {
  int _step = 0;
  bool _complete = false;
  bool _sessionStored = false;
  DateTime? _timerEndsAt;
  Timer? _clock;
  final _progressStore = CookingProgressStore();

  @override
  void initState() {
    super.initState();
    _restoreProgress();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _timerEndsAt != null) setState(() {});
    });
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    _clock?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _restoreProgress() async {
    final saved = await _progressStore.read();
    if (!mounted || saved?.recipe.id != widget.recipeId) return;
    setState(() {
      _step = saved!.step;
      _timerEndsAt = saved.timerEndsAt;
    });
  }

  Future<void> _saveProgress(Recipe recipe) => _progressStore.save(
        CookingProgress(
            recipe: recipe,
            step: _step,
            updatedAt: DateTime.now().toUtc(),
            timerEndsAt: _timerEndsAt),
      );

  Future<void> _startTimer(Recipe recipe) async {
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => const _TimerDialog(),
    );
    if (minutes == null || !mounted) return;
    setState(
        () => _timerEndsAt = DateTime.now().add(Duration(minutes: minutes)));
    await _saveProgress(recipe);
  }

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
          if (recipe.contentKind != ContentKind.recipe &&
              recipe.contentKind != ContentKind.process) {
            return const _CookingEmpty();
          }
          if (recipe.instructions.isEmpty) return const _CookingEmpty();
          _step = _step.clamp(0, recipe.instructions.length - 1);
          if (!_sessionStored) {
            _sessionStored = true;
            // Persist immediately so even the first step survives a restart.
            _saveProgress(recipe);
          }
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
            onTimer: () => _startTimer(recipe),
            timerLabel: _timerLabel(),
            onSelectStep: (step) async {
              setState(() => _step = step);
              await _saveProgress(recipe);
            },
            onPrevious: _step == 0 ? null : () => setState(() => _step--),
            onNext: () async {
              if (_step == recipe.instructions.length - 1) {
                setState(() => _complete = true);
                await _progressStore.clear();
                if (isAuthenticated) {
                  try {
                    await ref
                        .read(recipeServiceProvider)
                        .recordHistory(recipe.id, 'cooked');
                  } catch (_) {
                    // Completion stays local; a network retry must not undo it.
                  }
                }
              } else {
                setState(() => _step++);
                await _saveProgress(recipe);
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
        content: const Text(
            'Прогрес збережено на цьому пристрої — ви зможете продовжити без мережі.'),
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

  String? _timerLabel() {
    final endsAt = _timerEndsAt;
    if (endsAt == null) return null;
    final remaining = endsAt.difference(DateTime.now());
    if (remaining.isNegative) return 'Таймер завершено';
    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _CookingStep extends StatelessWidget {
  const _CookingStep(
      {required this.title,
      required this.step,
      required this.steps,
      required this.onExit,
      required this.onTimer,
      required this.timerLabel,
      required this.onSelectStep,
      required this.onPrevious,
      required this.onNext});
  final String title;
  final int step;
  final List<String> steps;
  final VoidCallback onExit;
  final VoidCallback onTimer;
  final String? timerLabel;
  final ValueChanged<int> onSelectStep;
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
      onTimer: onTimer,
      timerLabel: timerLabel,
      onPrevious: onPrevious,
      onNext: onNext,
    );
    if (desktop) {
      return SafeArea(
        child: Row(children: [
          SizedBox(
            width: 320,
            child: _StepList(
              active: step,
              steps: steps,
              onSelected: onSelectStep,
            ),
          ),
          const VerticalDivider(width: 1, color: Color(0xFF2E2820)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 40, 56, 32),
              child: content,
            ),
          ),
        ]),
      );
    }
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: content,
          ),
        ),
      ),
    );
  }
}

class _StepContent extends StatelessWidget {
  const _StepContent(
      {required this.step,
      required this.steps,
      required this.onExit,
      required this.onTimer,
      required this.timerLabel,
      required this.onPrevious,
      required this.onNext});
  final int step;
  final List<String> steps;
  final VoidCallback onExit;
  final VoidCallback onTimer;
  final String? timerLabel;
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
          Expanded(child: _Progress(step: step, total: steps.length)),
          IconButton(
            tooltip: 'Поставити таймер',
            onPressed: onTimer,
            icon: const Icon(Icons.timer_outlined, color: AppColorsV2.onInk),
          ),
        ]),
        if (timerLabel != null)
          Semantics(
              liveRegion: true,
              child: Text(timerLabel!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColorsV2.onInk))),
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
  const _StepList(
      {required this.active, required this.steps, required this.onSelected});
  final int active;
  final List<String> steps;
  final ValueChanged<int> onSelected;
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
          child: _Progress(step: active, total: steps.length),
        ),
        const Divider(height: 1, color: Color(0xFF2E2820)),
        Expanded(
          child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: steps.length,
              itemBuilder: (_, index) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: ListTile(
                      selected: index == active,
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadius.md),
                      leading: CircleAvatar(
                          backgroundColor: index == active
                              ? AppColorsV2.accent
                              : index < active
                                  ? AppColorsV2.success
                                  : const Color(0xFF2E2820),
                          child: index < active
                              ? const Icon(Icons.check,
                                  color: AppColorsV2.ink, size: 18)
                              : Text('${index + 1}')),
                      title: Text(steps[index],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColorsV2.onInk)),
                      onTap: () => onSelected(index),
                    ),
                  )),
        ),
      ]);
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

class _TimerDialog extends StatefulWidget {
  const _TimerDialog();
  @override
  State<_TimerDialog> createState() => _TimerDialogState();
}

class _TimerDialogState extends State<_TimerDialog> {
  int _minutes = 5;
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Таймер'),
        content: DropdownButton<int>(
          value: _minutes,
          isExpanded: true,
          items: const [1, 5, 10, 15, 30]
              .map((minutes) =>
                  DropdownMenuItem(value: minutes, child: Text('$minutes хв')))
              .toList(),
          onChanged: (value) => setState(() => _minutes = value ?? _minutes),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Скасувати')),
          FilledButton(
              onPressed: () => Navigator.pop(context, _minutes),
              child: const Text('Почати')),
        ],
      );
}
