import 'package:flutter/material.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../models/recipe.dart';

/// Reusable protected detail sections. Future content kinds can supply their
/// own labels and blocks without duplicating the detail page composition.
class ContentDetailSections extends StatelessWidget {
  const ContentDetailSections({
    super.key,
    required this.contentKind,
    required this.ingredients,
    required this.steps,
    this.leading,
    this.selectedServings,
    this.baseServings,
    this.onDecreaseServings,
    this.onIncreaseServings,
    this.checkedIngredientIds = const {},
    this.onIngredientToggled,
  });

  /// Decides which sections the content is expected to have at all: a kind
  /// without ingredients drops the section rather than showing it waiting for
  /// a list that will never arrive.
  final ContentKind contentKind;
  final List<Ingredient> ingredients;
  final List<String> steps;

  /// Media that belongs with the recipe — today, the video. On a wide layout
  /// it heads the ingredients column; on a narrow one it sits above both
  /// sections as before.
  final Widget? leading;

  /// Local presentation state owned by the open detail page. It deliberately
  /// never mutates the cached recipe or writes pantry state.
  final int? selectedServings;
  final int? baseServings;
  final VoidCallback? onDecreaseServings;
  final VoidCallback? onIncreaseServings;
  final Set<String> checkedIngredientIds;
  final ValueChanged<String>? onIngredientToggled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        // Decided from the space this widget actually has, not the window: the
        // same page column is a rail narrower inside the navigation shell.
        builder: (context, constraints) => _build(
          context,
          useColumns: constraints.maxWidth >= AppLayout.twoColumnMin,
        ),
      );

  bool get _hasIngredientsSection => contentKind.hasIngredients;

  Widget _build(BuildContext context, {required bool useColumns}) {
    final stepsSection = RecipeStepsSection(steps: steps);

    // With neither the video nor an ingredient list there is nothing to put
    // beside the steps, so the two-column split would only narrow them for no
    // gain.
    final hasSideColumn = leading != null || _hasIngredientsSection;

    if (!useColumns || !hasSideColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(height: AppSpacing.xl),
          ],
          if (_hasIngredientsSection) ...[
            RecipeIngredientsSection(
              ingredients: ingredients,
              selectedServings: selectedServings,
              baseServings: baseServings,
              onDecreaseServings: onDecreaseServings,
              onIncreaseServings: onIncreaseServings,
              checkedIngredientIds: checkedIngredientIds,
              onIngredientToggled: onIngredientToggled,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
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
                if (_hasIngredientsSection)
                  const SizedBox(height: AppSpacing.xl),
              ],
              if (_hasIngredientsSection)
                RecipeIngredientsSection(
                  ingredients: ingredients,
                  selectedServings: selectedServings,
                  baseServings: baseServings,
                  onDecreaseServings: onDecreaseServings,
                  onIncreaseServings: onIncreaseServings,
                  checkedIngredientIds: checkedIngredientIds,
                  onIngredientToggled: onIngredientToggled,
                ),
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

class RecipeIngredientsSection extends StatelessWidget {
  const RecipeIngredientsSection({
    super.key,
    required this.ingredients,
    this.selectedServings,
    this.baseServings,
    this.onDecreaseServings,
    this.onIncreaseServings,
    this.checkedIngredientIds = const {},
    this.onIngredientToggled,
  });

  final List<Ingredient> ingredients;
  final int? selectedServings;
  final int? baseServings;
  final VoidCallback? onDecreaseServings;
  final VoidCallback? onIncreaseServings;
  final Set<String> checkedIngredientIds;
  final ValueChanged<String>? onIngredientToggled;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Інгредієнти',
            trailing: selectedServings == null
                ? (ingredients.isEmpty
                    ? null
                    : Text('${ingredients.length} позицій',
                        style: Theme.of(context).textTheme.bodySmall))
                : _ServingStepper(
                    servings: selectedServings!,
                    onDecrease: onDecreaseServings,
                    onIncrease: onIncreaseServings,
                  ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (ingredients.isEmpty)
            const _EmptySection(label: 'Список інгредієнтів ще готується.')
          else
            ...ingredients.map((ingredient) => _IngredientRow(
                  ingredient: ingredient,
                  amount: scaledIngredientAmount(
                    ingredient.amount,
                    selectedServings: selectedServings,
                    baseServings: baseServings,
                  ),
                  checked: checkedIngredientIds.contains(ingredient.id),
                  onChanged: onIngredientToggled == null
                      ? null
                      : () => onIngredientToggled!(ingredient.id),
                )),
        ],
      );
}

class RecipeStepsSection extends StatelessWidget {
  const RecipeStepsSection({super.key, required this.steps});

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
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (trailing != null) trailing!,
        ],
      );
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.ingredient,
    required this.amount,
    required this.checked,
    this.onChanged,
  });
  final Ingredient ingredient;
  final double amount;
  final bool checked;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: context.semantic.surfaceStrong)),
        ),
        child: Row(
          children: [
            Semantics(
              label: 'Позначити інгредієнт ${ingredient.name}',
              checked: checked,
              child: Checkbox(
                value: checked,
                onChanged: onChanged == null ? null : (_) => onChanged!(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ingredient.name,
                      style: TextStyle(
                        decoration: checked ? TextDecoration.lineThrough : null,
                      )),
                  if (ingredient.notes?.trim().isNotEmpty ?? false)
                    Text(ingredient.notes!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.semantic.textSecondary,
                            )),
                ],
              ),
            ),
            Text(
              '${formatIngredientAmount(amount)} ${ingredient.unit}'.trim(),
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
              backgroundColor: context.semantic.surfaceStrong,
              foregroundColor: context.semantic.textPrimary,
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

class _ServingStepper extends StatelessWidget {
  const _ServingStepper({
    required this.servings,
    this.onDecrease,
    this.onIncrease,
  });

  final int servings;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Зменшити порції',
            onPressed: servings > 1 ? onDecrease : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          Semantics(
            label: 'Вибрано $servings порцій',
            child: Text('$servings',
                style: Theme.of(context).textTheme.titleSmall),
          ),
          IconButton(
            tooltip: 'Збільшити порції',
            onPressed: onIncrease,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      );
}

/// Uses the recipe's immutable source amount and protects malformed legacy
/// serving counts. Keeping it public makes the rounding contract easy to test.
double scaledIngredientAmount(
  double amount, {
  int? selectedServings,
  int? baseServings,
}) {
  final base = baseServings ?? 0;
  final selected = selectedServings ?? base;
  if (base <= 0 || selected <= 0 || !amount.isFinite) return amount;
  return amount * selected / base;
}

String formatIngredientAmount(double value) {
  if (!value.isFinite) return '';
  if (value == value.roundToDouble()) return value.toInt().toString();
  // Four fractional places preserve small quantities without exposing binary
  // floating point noise; Ukrainian UI uses a comma as the decimal separator.
  final raw = (value.abs() < .001 && value != 0
          ? value.toStringAsPrecision(4)
          : value.toStringAsFixed(4))
      .replaceFirst(RegExp(r'0+$'), '');
  return raw.replaceFirst(RegExp(r'\.$'), '').replaceAll('.', ',');
}
