import 'package:flutter/material.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../models/recipe.dart';

/// Reusable protected detail sections. Future content kinds can supply their
/// own labels and blocks without duplicating the detail page composition.
class ContentDetailSections extends StatelessWidget {
  const ContentDetailSections({
    super.key,
    required this.ingredients,
    required this.steps,
    this.leading,
  });

  final List<Ingredient> ingredients;
  final List<String> steps;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(height: AppSpacing.xl)
          ],
          _SectionTitle(
            title: 'Інгредієнти',
            trailing:
                ingredients.isEmpty ? null : '${ingredients.length} позицій',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (ingredients.isEmpty)
            const _EmptySection(label: 'Список інгредієнтів ще готується.')
          else
            ...ingredients
                .map((ingredient) => _IngredientRow(ingredient: ingredient)),
          const SizedBox(height: AppSpacing.xl),
          const _SectionTitle(title: 'Приготування'),
          const SizedBox(height: AppSpacing.md),
          if (steps.isEmpty)
            const _EmptySection(label: 'Покрокова інструкція ще готується.')
          else
            ...steps.asMap().entries.map(
                  (entry) => _InstructionStep(
                    number: entry.key + 1,
                    text: entry.value,
                  ),
                ),
        ],
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});
  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (trailing != null)
            Text(trailing!, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.ingredient});
  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColorsV2.surfaceStrong)),
        ),
        child: Row(
          children: [
            const Icon(Icons.circle, size: 8, color: AppColorsV2.accent),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(ingredient.name)),
            Text(
              '${ingredient.amount} ${ingredient.unit}'.trim(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColorsV2.textSecondary,
                  ),
            ),
          ],
        ),
      );
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor:
                  number == 1 ? AppColorsV2.accent : AppColorsV2.surfaceStrong,
              foregroundColor:
                  number == 1 ? AppColorsV2.ink : AppColorsV2.textPrimary,
              child: Text('$number'),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
                child:
                    Text(text, style: Theme.of(context).textTheme.bodyLarge)),
          ],
        ),
      );
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColorsV2.textSecondary,
            ),
      );
}
