import 'package:flutter/material.dart';

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
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: ingredient.isConfirmed ? 2 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Confirmation checkbox
              Checkbox(
                value: ingredient.isConfirmed,
                onChanged: (_) => onToggle(),
                activeColor: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              
              // Ingredient info
              Expanded(
                child: Column(
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
                            : Colors.grey[600],
                      ),
                    ),
                    if (ingredient.notes?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        ingredient.notes!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                    if (ingredient.confidence > 0) ...[
                      const SizedBox(height: 4),
                      _buildConfidenceIndicator(context),
                    ],
                  ],
                ),
              ),
              
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onTap,
                    icon: const Icon(Icons.edit, size: 20),
                    tooltip: 'Edit ingredient',
                  ),
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, size: 20),
                    tooltip: 'Remove ingredient',
                    color: Colors.red[400],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceIndicator(BuildContext context) {
    final percentage = (ingredient.confidence * 100).toInt();
    final color = ingredient.confidence > 0.7 
        ? Colors.green 
        : ingredient.confidence > 0.4 
            ? Colors.orange 
            : Colors.red;

    return Row(
      children: [
        Container(
          width: 60,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: Colors.grey[300],
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
        ? ingredients.map((i) => i.confidence).reduce((a, b) => a + b) / ingredients.length
        : 0.0;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildSummaryItem(
                  context,
                  'Confirmed',
                  '$confirmedCount/$totalCount',
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildSummaryItem(
                  context,
                  'Confidence',
                  '${(averageConfidence * 100).toInt()}%',
                  Icons.analytics,
                  averageConfidence > 0.7 ? Colors.green : Colors.orange,
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
