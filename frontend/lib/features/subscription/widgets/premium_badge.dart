import 'package:flutter/material.dart';

/// Premium badge widget to display on premium content
class PremiumBadge extends StatelessWidget {
  final double size;
  final bool showLabel;
  final Color? backgroundColor;
  final Color? iconColor;

  const PremiumBadge({
    super.key,
    this.size = 24,
    this.showLabel = false,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? Colors.amber.shade700;
    final iColor = iconColor ?? Colors.white;

    if (showLabel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium,
              size: size * 0.8,
              color: iColor,
            ),
            const SizedBox(width: 4),
            Text(
              'PREMIUM',
              style: TextStyle(
                color: iColor,
                fontSize: size * 0.6,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.workspace_premium,
        size: size,
        color: iColor,
      ),
    );
  }
}

/// Premium overlay for locked content
class PremiumOverlay extends StatelessWidget {
  final Widget child;
  final bool isPremium;
  final bool hasAccess;
  final VoidCallback? onTap;

  const PremiumOverlay({
    super.key,
    required this.child,
    required this.isPremium,
    required this.hasAccess,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPremium || hasAccess) {
      return child;
    }

    return Stack(
      children: [
        // Blurred/dimmed content
        Opacity(
          opacity: 0.5,
          child: child,
        ),
        // Lock overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Text(
                          'PREMIUM CONTENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap to upgrade',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
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

/// Small premium indicator for list items
class PremiumIndicator extends StatelessWidget {
  final bool isPremium;

  const PremiumIndicator({
    super.key,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPremium) {
      return const SizedBox.shrink();
    }

    return const PremiumBadge(
      size: 20,
      showLabel: false,
    );
  }
}

