import 'package:flutter/material.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../app/theme/brand_theme.dart';
import '../../../../core/widgets/state_views.dart';

enum CameraFlowStep {
  capture,
  review,
  results,
}

class CameraFlowScaffold extends StatelessWidget {
  const CameraFlowScaffold({
    super.key,
    required this.title,
    required this.step,
    required this.child,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final String title;
  final CameraFlowStep step;
  final Widget child;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  static const _labels = ['Зйомка', 'Перевірка', 'Результати'];

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final brand = base.extension<BrandThemeExtension>();
    final darkScheme = base.colorScheme.copyWith(
      brightness: Brightness.dark,
      primary: brand?.accentOnDark ?? base.colorScheme.primary,
      surface: const Color(0xFF221D16),
      onSurface: AppColorsV2.onInk,
    );

    return Theme(
      data: base.copyWith(
        brightness: Brightness.dark,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: AppColorsV2.ink,
        textTheme: base.textTheme.apply(
          bodyColor: AppColorsV2.onInk,
          displayColor: AppColorsV2.onInk,
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColorsV2.ink,
        appBar: AppBar(
          title: Text(title),
          backgroundColor: AppColorsV2.ink,
          foregroundColor: AppColorsV2.onInk,
        ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 1024) {
                return Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: _DesktopCameraStepRail(
                        title: title,
                        labels: _labels,
                        currentStep: step.index + 1,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 920),
                          child: child,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  _CameraStepHeader(
                    labels: _labels,
                    currentStep: step.index + 1,
                  ),
                  Expanded(child: child),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopCameraStepRail extends StatelessWidget {
  const _DesktopCameraStepRail({
    required this.title,
    required this.labels,
    required this.currentStep,
  });

  final String title;
  final List<String> labels;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final accent =
        Theme.of(context).extension<BrandThemeExtension>()?.accentOnDark ??
            AppColorsV2.premiumGold;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('Крок $currentStep з ${labels.length}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColorsV2.onInk.withOpacity(.62))),
          const SizedBox(height: AppSpacing.lg),
          for (var index = 0; index < labels.length; index++)
            _DesktopStep(
              label: labels[index],
              index: index + 1,
              done: index + 1 < currentStep,
              current: index + 1 == currentStep,
              accent: accent,
            ),
          const Spacer(),
          Text('Фото обробляється лише для пошуку рецептів.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColorsV2.onInk.withOpacity(.48))),
        ],
      ),
    );
  }
}

class _DesktopStep extends StatelessWidget {
  const _DesktopStep({
    required this.label,
    required this.index,
    required this.done,
    required this.current,
    required this.accent,
  });

  final String label;
  final int index;
  final bool done;
  final bool current;
  final Color accent;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            color: current ? const Color(0xFF221D16) : Colors.transparent,
            border: current ? Border.all(color: const Color(0xFF2E2820)) : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: done || current
                    ? accent
                    : AppColorsV2.onInk.withOpacity(.14),
                child: Icon(done ? Icons.check : Icons.circle,
                    size: done ? 16 : 8,
                    color: done || current
                        ? AppColorsV2.ink
                        : AppColorsV2.onInk.withOpacity(.5)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: current
                            ? AppColorsV2.onInk
                            : AppColorsV2.onInk.withOpacity(.58),
                        fontWeight: current ? FontWeight.w700 : null)),
              ),
            ]),
          ),
        ),
      );
}

class CameraFlowStatusView extends StatelessWidget {
  const CameraFlowStatusView.loading({
    super.key,
    required this.title,
    required this.subtitle,
  })  : _error = null,
        _onRetry = null,
        _isError = false;

  const CameraFlowStatusView.error({
    super.key,
    required this.title,
    this.subtitle,
    required VoidCallback onRetry,
  })  : _error = subtitle,
        _onRetry = onRetry,
        _isError = true;

  final String title;
  final String? subtitle;
  final String? _error;
  final VoidCallback? _onRetry;
  final bool _isError;

  @override
  Widget build(BuildContext context) {
    if (_isError) {
      return StateView.error(
        title: title,
        subtitle: _error,
        onRetry: _onRetry,
      );
    }

    return StateView.loading(
      title: title,
      subtitle: subtitle,
    );
  }
}

class _CameraStepHeader extends StatelessWidget {
  const _CameraStepHeader({
    required this.labels,
    required this.currentStep,
  });

  final List<String> labels;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Row(
        children: List.generate(labels.length, (index) {
          final stepNumber = index + 1;
          final isDone = stepNumber < currentStep;
          final isCurrent = stepNumber == currentStep;
          final color = isDone || isCurrent
              ? Theme.of(context)
                      .extension<BrandThemeExtension>()
                      ?.accentOnDark ??
                  AppColorsV2.premiumGold
              : AppColorsV2.onInk.withOpacity(.18);

          return Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: color,
                  child: Text(
                    '$stepNumber',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    labels[index],
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isCurrent
                          ? AppColorsV2.onInk
                          : AppColorsV2.onInk.withOpacity(.52),
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
                if (index < labels.length - 1)
                  Container(
                    width: 16,
                    height: 1,
                    color: AppColorsV2.onInk.withOpacity(.16),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
