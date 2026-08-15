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

  /// Media that belongs with the recipe — today, the video. On a wide layout
  /// it heads the ingredients column; on a narrow one it sits above both
  /// sections as before.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final ingredientsSection = _IngredientsSection(ingredients: ingredients);
    final stepsSection = _StepsSection(steps: steps);
    final useColumns =
        MediaQuery.sizeOf(context).width >= AppLayout.desktopBreakpoint;

    if (!useColumns) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(height: AppSpacing.xl),
          ],
          ingredientsSection,
          const SizedBox(height: AppSpacing.xl),
          stepsSection,
        ],
      );
    }

    // A short ingredient list and a long method do not deserve equal halves:
    // the old 50/50 split left the left column mostly empty while the right
    // one ran to an uncomfortable line length on a wide monitor.
    return Row(
      key: const ValueKey('recipe-sections-two-column'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppLayout.sideColumn,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(height: AppSpacing.xl),
              ],
              ingredientsSection,
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.xxl),
        // Align loosens the tight width Expanded hands down, so the cap can
        // actually bite: past ~760px a step reads as a wall of text no matter
        // how much room the window has.
        Expanded(
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.narrowMax),
              child: stepsSection,
            ),
          ),
        ),
      ],
    );
  }
}

class _IngredientsSection extends StatelessWidget {
  const _IngredientsSection({required this.ingredients});

  final List<Ingredient> ingredients;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        ],
      );
}

class _StepsSection extends StatelessWidget {
  const _StepsSection({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
        decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: context.semantic.surfaceStrong)),
        ),
        child: Row(
          children: [
            Icon(Icons.circle,
                size: 8, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(ingredient.name)),
            Text(
              '${ingredient.amount} ${ingredient.unit}'.trim(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.semantic.textSecondary,
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
              backgroundColor: number == 1
                  ? Theme.of(context).colorScheme.primary
                  : context.semantic.surfaceStrong,
              foregroundColor: number == 1
                  ? Theme.of(context).colorScheme.onPrimary
                  : context.semantic.textPrimary,
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
              color: context.semantic.textSecondary,
            ),
      );
}
