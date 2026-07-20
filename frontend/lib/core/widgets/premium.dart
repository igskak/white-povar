import 'package:flutter/material.dart';

import '../../app/theme/tokens/app_tokens.dart';
import 'design_system.dart';

/// Premium tier affordances.
///
/// These are deliberately painted in [AppColorsV2.premiumGold] rather than the
/// tenant accent: premium is a *product* tier that must read the same across
/// every brand (Handoff §5, «premium-золото — системний токен»).
class PremiumBadge extends StatelessWidget {
  const PremiumBadge({
    super.key,
    this.size = 24,
    this.showLabel = false,
    this.backgroundColor,
    this.iconColor,
  });

  final double size;
  final bool showLabel;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? AppColorsV2.premiumGold;
    final iColor = iconColor ?? AppColorsV2.ink;

    if (showLabel) {
      return Semantics(
        label: 'Premium',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadius.md,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.workspace_premium, size: size * 0.8, color: iColor),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                'PREMIUM',
                style: TextStyle(
                  color: iColor,
                  fontSize: size * 0.6,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label: 'Premium',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xxs),
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(Icons.workspace_premium, size: size, color: iColor),
      ),
    );
  }
}

/// Dims locked content behind an ink scrim and an upgrade affordance.
class PremiumOverlay extends StatelessWidget {
  const PremiumOverlay({
    super.key,
    required this.child,
    required this.isPremium,
    required this.hasAccess,
    this.onTap,
  });

  final Widget child;
  final bool isPremium;
  final bool hasAccess;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (!isPremium || hasAccess) return child;

    return Stack(
      children: [
        Opacity(opacity: 0.5, child: child),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColorsV2.ink.withOpacity(0.3),
                  AppColorsV2.ink.withOpacity(0.6),
                ],
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: const BoxDecoration(
                          color: AppColorsV2.premiumGold,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.lock,
                            size: 48, color: AppColorsV2.ink),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const PremiumBadge(size: 20, showLabel: true),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Відкрити Premium',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColorsV2.onInk),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small premium marker for dense list items.
class PremiumIndicator extends StatelessWidget {
  const PremiumIndicator({super.key, required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) =>
      isPremium ? const PremiumBadge(size: 20) : const SizedBox.shrink();
}

/// The shared premium upsell card (Handoff §3 PremiumGateCard) used by recipe
/// detail, the cooking gate and the Home course card.
class PremiumGateCard extends StatelessWidget {
  const PremiumGateCard({
    super.key,
    required this.title,
    required this.message,
    required this.ctaLabel,
    required this.onUnlock,
    this.icon = Icons.workspace_premium,
  });

  final String title;
  final String message;
  final String ctaLabel;
  final VoidCallback onUnlock;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ContentCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          const PremiumBadge(size: 30),
          const SizedBox(height: AppSpacing.sm),
          Text(title,
              textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: context.semantic.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: ctaLabel,
            icon: icon,
            onPressed: onUnlock,
            expand: true,
          ),
        ],
      ),
    );
  }
}
