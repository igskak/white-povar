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
    return Scaffold(
      backgroundColor: AppColorsV2.ink,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColorsV2.ink,
        foregroundColor: AppColorsV2.onInk,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _CameraStepHeader(
              labels: _labels,
              currentStep: step.index + 1,
            ),
            Expanded(child: child),
          ],
        ),
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
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
