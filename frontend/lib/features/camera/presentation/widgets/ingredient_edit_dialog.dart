import 'package:flutter/material.dart';

import '../../models/detected_ingredient.dart';

class IngredientEditDialog extends StatefulWidget {
  final DetectedIngredient? ingredient;
  final Function(String name, String? notes) onSave;

  const IngredientEditDialog({
    super.key,
    this.ingredient,
    required this.onSave,
  });

  @override
  State<IngredientEditDialog> createState() => _IngredientEditDialogState();
}

class _IngredientEditDialogState extends State<IngredientEditDialog> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.ingredient?.name ?? '');
    _notesController = TextEditingController(text: widget.ingredient?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.ingredient != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Ingredient' : 'Add Ingredient'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Ingredient Name',
                hintText: 'e.g., tomatoes, onions, garlic',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an ingredient name';
                }
                return null;
              },
              autofocus: !isEditing,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g., diced, fresh, large',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            if (isEditing && widget.ingredient!.confidence > 0) ...[
              const SizedBox(height: 16),
              _buildConfidenceInfo(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveIngredient,
          child: Text(isEditing ? 'Update' : 'Add'),
        ),
      ],
    );
  }

  Widget _buildConfidenceInfo() {
    final confidence = widget.ingredient!.confidence;
    final percentage = (confidence * 100).toInt();
    final color = confidence > 0.7 
        ? Colors.green 
        : confidence > 0.4 
            ? Colors.orange 
            : Colors.red;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(
            confidence > 0.7 
                ? Icons.check_circle 
                : confidence > 0.4 
                    ? Icons.warning 
                    : Icons.error,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Detection Confidence',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$percentage% - ${_getConfidenceDescription(confidence)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getConfidenceDescription(double confidence) {
    if (confidence > 0.8) return 'Very confident';
    if (confidence > 0.6) return 'Confident';
    if (confidence > 0.4) return 'Somewhat confident';
    return 'Low confidence';
  }

  void _saveIngredient() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final notes = _notesController.text.trim();
      
      widget.onSave(name, notes.isEmpty ? null : notes);
      Navigator.of(context).pop();
    }
  }
}

class QuickIngredientSelector extends StatelessWidget {
  final Function(String) onIngredientSelected;
  final List<String> commonIngredients = const [
    'Onion',
    'Garlic',
    'Tomato',
    'Carrot',
    'Potato',
    'Bell Pepper',
    'Mushroom',
    'Spinach',
    'Basil',
    'Parsley',
    'Salt',
    'Black Pepper',
    'Olive Oil',
    'Butter',
    'Cheese',
    'Egg',
    'Chicken',
    'Rice',
    'Pasta',
    'Flour',
  ];

  const QuickIngredientSelector({
    super.key,
    required this.onIngredientSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Add',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: commonIngredients.map((ingredient) {
            return ActionChip(
              label: Text(ingredient),
              onPressed: () => onIngredientSelected(ingredient),
              backgroundColor: Theme.of(context).colorScheme.surface,
            );
          }).toList(),
        ),
      ],
    );
  }
}

class IngredientSuggestions extends StatelessWidget {
  final String query;
  final Function(String) onSuggestionSelected;
  
  // In a real app, this would come from an API or database
  final List<String> allIngredients = const [
    'Onion', 'Garlic', 'Tomato', 'Carrot', 'Potato', 'Bell Pepper',
    'Mushroom', 'Spinach', 'Basil', 'Parsley', 'Oregano', 'Thyme',
    'Salt', 'Black Pepper', 'Paprika', 'Cumin', 'Olive Oil', 'Butter',
    'Milk', 'Cream', 'Cheese', 'Mozzarella', 'Parmesan', 'Egg',
    'Chicken Breast', 'Ground Beef', 'Salmon', 'Flour', 'Rice', 'Pasta',
    'Bread', 'Sugar', 'Honey', 'Lemon', 'Lime', 'Coconut Milk',
  ];

  const IngredientSuggestions({
    super.key,
    required this.query,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (query.length < 2) return const SizedBox.shrink();

    final suggestions = allIngredients
        .where((ingredient) => 
            ingredient.toLowerCase().contains(query.toLowerCase()))
        .take(5)
        .toList();

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggestions',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        ...suggestions.map((suggestion) {
          return ListTile(
            dense: true,
            title: Text(suggestion),
            leading: const Icon(Icons.search, size: 16),
            onTap: () => onSuggestionSelected(suggestion),
          );
        }),
      ],
    );
  }
}
