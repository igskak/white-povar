import 'package:flutter/material.dart';

import '../../app/theme/tokens/app_tokens.dart';

class StateView extends StatelessWidget {
  const StateView.loading({
    super.key,
    this.title = 'Завантаження...',
    this.subtitle,
  })  : icon = Icons.hourglass_top_rounded,
        onRetry = null,
        actionLabel = null,
        isLoading = true;

  const StateView.empty({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.onRetry,
    this.actionLabel,
  }) : isLoading = false;

  const StateView.error({
    super.key,
    this.title = 'Щось пішло не так',
    this.subtitle,
    this.icon = Icons.error_outline_rounded,
    this.onRetry,
    this.actionLabel = 'Повторити',
  }) : isLoading = false;

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onRetry;
  final String? actionLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                Icon(icon, size: 42, color: theme.colorScheme.primary),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(.68),
                  ),
                ),
              ],
              if (onRetry != null && actionLabel != null) ...[
                const SizedBox(height: AppSpacing.md),
                ElevatedButton(
                  onPressed: onRetry,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
