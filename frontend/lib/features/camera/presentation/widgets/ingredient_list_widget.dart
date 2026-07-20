import 'package:flutter/material.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../models/detected_ingredient.dart';

class IngredientListWidget extends StatelessWidget {
  final List<DetectedIngredient> ingredients;
  final Function(DetectedIngredient) onIngredientTap;
  final Function(String) onIngredientToggle;
  final Function(String) onIngredientDelete;

  const IngredientListWidget({
    super.key,
    required this.ingredients,
    required this.onIngredientTap,
    required this.onIngredientToggle,
    required this.onIngredientDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: ingredients.length,
      itemBuilder: (context, index) {
        final ingredient = ingredients[index];
        return IngredientCard(
          ingredient: ingredient,
          onTap: () => onIngredientTap(ingredient),
          onToggle: () => onIngredientToggle(ingredient.id),
          onDelete: () => onIngredientDelete(ingredient.id),
        );
      },
    );
  }
}

class IngredientCard extends StatelessWidget {
  final DetectedIngredient ingredient;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const IngredientCard({
    super.key,
    required this.ingredient,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    // Handoff §3 IngredientRow: checkbox 22 inside a 44 hit area.
    final confirmation = SizedBox.square(
      dimension: 44,
      child: Center(
        child: SizedBox.square(
          dimension: 22,
          child: Checkbox(
            value: ingredient.isConfirmed,
            onChanged: (_) => onToggle(),
            activeColor: Theme.of(context).colorScheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );
    // < 60% confidence needs an explicit confirmation prompt.
    final lowConfidence =
        ingredient.confidence > 0 && ingredient.confidence < .6;
    final ingredientInfo = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ingredient.name,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: ingredient.isConfirmed
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: ingredient.isConfirmed
                    ? null
                    : Theme.of(context).colorScheme.onSurface.withOpacity(.52),
              ),
        ),
        if (ingredient.notes?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            ingredient.notes!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(.62),
                ),
          ),
        ],
        if (ingredient.confidence > 0) ...[
          const SizedBox(height: 4),
          _buildConfidenceIndicator(context),
        ],
        if (lowConfidence) ...[
          const SizedBox(height: 4),
          Text(
            'Підтвердіть цей продукт',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: semantic.warning),
          ),
        ],
      ],
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onTap,
          icon: const Icon(Icons.edit, size: 20),
          tooltip: 'Редагувати продукт',
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete, size: 20),
          tooltip: 'Видалити продукт',
          color: semantic.error,
        ),
      ],
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: ingredient.isConfirmed ? 2 : 1,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lg,
        side: BorderSide(
          color: lowConfidence ? semantic.warning : semantic.surfaceStrong,
          width: lowConfidence ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lg,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 340) {
                return Column(
                  children: [
                    Row(children: [
                      confirmation,
                      const SizedBox(width: 8),
                      Expanded(child: ingredientInfo),
                    ]),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(children: [
                confirmation,
                const SizedBox(width: 8),
                Expanded(child: ingredientInfo),
                actions,
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicator(BuildContext context) {
    final percentage = (ingredient.confidence * 100).toInt();
    final semantic = context.semantic;
    final color = ingredient.confidence > 0.7
        ? semantic.success
        : ingredient.confidence > 0.4
            ? semantic.warning
            : semantic.error;

    return Row(
      children: [
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.14),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ingredient.confidence,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$percentage%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );
  }
}

class IngredientSummary extends StatelessWidget {
  final List<DetectedIngredient> ingredients;

  const IngredientSummary({
    super.key,
    required this.ingredients,
  });

  @override
  Widget build(BuildContext context) {
    final confirmedCount = ingredients.where((i) => i.isConfirmed).length;
    final totalCount = ingredients.length;
    final averageConfidence = ingredients.isNotEmpty
        ? ingredients.map((i) => i.confidence).reduce((a, b) => a + b) /
            ingredients.length
        : 0.0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Підсумок',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSummaryItem(
                  context,
                  'Підтверджено',
                  '$confirmedCount/$totalCount',
                  Icons.check_circle,
                  context.semantic.success,
                ),
                const SizedBox(width: 16),
                _buildSummaryItem(
                  context,
                  'Точність',
                  '${(averageConfidence * 100).toInt()}%',
                  Icons.analytics,
                  averageConfidence > 0.7
                      ? context.semantic.success
                      : context.semantic.warning,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
        ),
      ],
    );
  }
}
