import 'package:flutter/material.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/premium.dart';

/// The Home entry points, shared with the Creator Studio live preview (13m).
///
/// The preview renders the app's own widgets rather than a mock, so a change
/// here cannot make the editor and the consumer app disagree.
class ScanBanner extends StatelessWidget {
  const ScanBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ContentCard(
        onTap: onTap,
        semanticLabel: 'Сканувати інгредієнти',
        child: Row(
          children: [
            const Icon(Icons.photo_camera_outlined),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Сканувати інгредієнти',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text('Фото продуктів → рецепти за 10 секунд',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      );
}

/// Brand course card (13g). Hidden when the brand publishes no course;
/// locked for guests and free users; active for premium.
class BrandCourseCard extends StatelessWidget {
  const BrandCourseCard({
    super.key,
    required this.courseName,
    required this.locked,
    required this.onOpen,
    required this.onUnlock,
  });

  final String courseName;
  final bool locked;
  final VoidCallback onOpen;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return PremiumGateCard(
        title: courseName,
        message: 'Авторський курс від шефа доступний у Premium.',
        ctaLabel: 'Відкрити Premium',
        onUnlock: onUnlock,
      );
    }
    return ContentCard(
      onTap: onOpen,
      semanticLabel: 'Відкрити колекцію $courseName',
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: AppColorsV2.premiumGold),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Преміум-колекція',
                    style: Theme.of(context).textTheme.labelLarge),
                Text(courseName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_rounded),
        ],
      ),
    );
  }
}
