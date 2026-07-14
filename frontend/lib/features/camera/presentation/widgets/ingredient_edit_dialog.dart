import 'package:flutter/material.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
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
    _nameController =
        TextEditingController(text: widget.ingredient?.name ?? '');
    _notesController =
        TextEditingController(text: widget.ingredient?.notes ?? '');
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
      title: Text(isEditing ? 'Редагувати продукт' : 'Додати продукт'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Назва продукту',
                hintText: 'Наприклад: томати, цибуля, часник',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Введіть назву продукту';
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
                labelText: 'Нотатки (необовʼязково)',
                hintText: 'Наприклад: нарізані, свіжі, великі',
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
          child: const Text('Скасувати'),
        ),
        ElevatedButton(
          onPressed: _saveIngredient,
          child: Text(isEditing ? 'Оновити' : 'Додати'),
        ),
      ],
    );
  }

  Widget _buildConfidenceInfo() {
    final confidence = widget.ingredient!.confidence;
    final percentage = (confidence * 100).toInt();
    final color = confidence > 0.7
        ? AppColorsV2.success
        : confidence > 0.4
            ? AppColorsV2.warning
            : AppColorsV2.error;

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
                  'Точність розпізнавання',
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
    if (confidence > 0.8) return 'дуже висока';
    if (confidence > 0.6) return 'висока';
    if (confidence > 0.4) return 'середня';
    return 'низька';
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
    'Цибуля',
    'Часник',
    'Томат',
    'Морква',
    'Картопля',
    'Перець',
    'Гриби',
    'Шпинат',
    'Базилік',
    'Петрушка',
    'Сіль',
    'Чорний перець',
    'Оливкова олія',
    'Вершкове масло',
    'Сир',
    'Яйце',
    'Курка',
    'Рис',
    'Паста',
    'Борошно',
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
          'Швидке додавання',
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

  final List<String> allIngredients = const [
    'Цибуля',
    'Часник',
    'Томат',
    'Морква',
    'Картопля',
    'Перець',
    'Гриби',
    'Шпинат',
    'Базилік',
    'Петрушка',
    'Орегано',
    'Чебрець',
    'Сіль',
    'Чорний перець',
    'Паприка',
    'Кмин',
    'Оливкова олія',
    'Вершкове масло',
    'Молоко',
    'Вершки',
    'Сир',
    'Моцарела',
    'Пармезан',
    'Яйце',
    'Куряча грудка',
    'Фарш',
    'Лосось',
    'Борошно',
    'Рис',
    'Паста',
    'Хліб',
    'Цукор',
    'Мед',
    'Лимон',
    'Лайм',
    'Кокосове молоко',
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
          'Підказки',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(.62),
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
