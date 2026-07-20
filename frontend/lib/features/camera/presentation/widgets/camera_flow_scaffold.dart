import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../app/theme/brand_theme.dart';
import '../../../../core/widgets/design_system.dart';
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
    this.immersive = false,
  });

  final String title;
  final CameraFlowStep step;
  final Widget child;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool immersive;

  static const _labels = ['Зйомка', 'Перевірка', 'Результати'];

  @override
  Widget build(BuildContext context) {
    final immersiveCapture = immersive &&
        step == CameraFlowStep.capture &&
        !kIsWeb &&
        MediaQuery.sizeOf(context).width < 600;

    // The flow is dark in both themes. ForcedDarkTheme swaps the whole theme,
    // including the SemanticColors extension, so descendants reading
    // `context.semantic` get the dark column rather than light-on-dark.
    return ForcedDarkTheme(
      child: Scaffold(
        backgroundColor: AppColorsV2.ink,
        appBar: immersiveCapture
            ? null
            : AppBar(
                title: Text(title),
                backgroundColor: AppColorsV2.ink,
                foregroundColor: AppColorsV2.onInk,
              ),
        floatingActionButton: floatingActionButton,
        bottomNavigationBar: bottomNavigationBar,
        body: SafeArea(
          child: immersiveCapture
              ? child
              : LayoutBuilder(
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
                                constraints:
                                    const BoxConstraints(maxWidth: 920),
                                child: child,
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return Column(
                      children: [
                        FlowStepper(
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
                  ?.copyWith(color: context.semantic.textSecondary)),
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
                  ?.copyWith(color: context.semantic.textSecondary)),
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
            color: current ? context.semantic.surface : Colors.transparent,
            border: current
                ? Border.all(color: context.semantic.surfaceStrong)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    done || current ? accent : context.semantic.surfaceStrong,
                child: Icon(done ? Icons.check : Icons.circle,
                    size: done ? 16 : 8,
                    color: done || current
                        ? AppColorsV2.ink
                        : context.semantic.textSecondary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: current
                            ? AppColorsV2.onInk
                            : context.semantic.textSecondary,
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
