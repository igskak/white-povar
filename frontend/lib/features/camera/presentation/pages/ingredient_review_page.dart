import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/detected_ingredient.dart';
import '../../providers/photo_search_provider.dart';
import '../widgets/ingredient_list_widget.dart';
import '../widgets/ingredient_edit_dialog.dart';
import '../widgets/loading_overlay.dart';

class IngredientReviewPage extends ConsumerStatefulWidget {
  final XFile capturedImage;

  const IngredientReviewPage({
    super.key,
    required this.capturedImage,
  });

  @override
  ConsumerState<IngredientReviewPage> createState() => _IngredientReviewPageState();
}

class _IngredientReviewPageState extends ConsumerState<IngredientReviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize ingredients from photo search results
      final photoSearchState = ref.read(photoSearchProvider);
      if (photoSearchState.detectedIngredients.isNotEmpty) {
        ref.read(ingredientEditProvider.notifier).setIngredients(
          photoSearchState.detectedIngredients,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final photoSearchState = ref.watch(photoSearchProvider);
    final ingredients = ref.watch(ingredientEditProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Ingredients'),
        actions: [
          TextButton(
            onPressed: ingredients.isNotEmpty ? _searchRecipes : null,
            child: const Text('Find Recipes'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildImageThumbnail(),
              _buildConfidenceIndicator(photoSearchState.confidence),
              Expanded(
                child: _buildIngredientsSection(ingredients),
              ),
            ],
          ),
          if (photoSearchState.isLoading)
            const LoadingOverlay(message: 'Searching recipes...'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addIngredient,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildImageThumbnail() {
    return Container(
      height: 120,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: kIsWeb
            ? Image.network(
                widget.capturedImage.path,
                width: double.infinity,
                fit: BoxFit.cover,
              )
            : Image.file(
                File(widget.capturedImage.path),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Widget _buildConfidenceIndicator(double confidence) {
    if (confidence <= 0) return const SizedBox.shrink();

    final percentage = (confidence * 100).toInt();
    final color = confidence > 0.7 
        ? Colors.green 
        : confidence > 0.4 
            ? Colors.orange 
            : Colors.red;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
          Text(
            'Detection confidence: $percentage%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection(List<DetectedIngredient> ingredients) {
    if (ingredients.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Detected Ingredients',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              Text(
                '${ingredients.where((i) => i.isConfirmed).length}/${ingredients.length} confirmed',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: IngredientListWidget(
            ingredients: ingredients,
            onIngredientTap: _editIngredient,
            onIngredientToggle: _toggleIngredient,
            onIngredientDelete: _deleteIngredient,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No ingredients detected',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try taking another photo or add ingredients manually',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addIngredient,
              icon: const Icon(Icons.add),
              label: const Text('Add Ingredient'),
            ),
          ],
        ),
      ),
    );
  }

  void _editIngredient(DetectedIngredient ingredient) {
    showDialog(
      context: context,
      builder: (context) => IngredientEditDialog(
        ingredient: ingredient,
        onSave: (name, notes) {
          ref.read(ingredientEditProvider.notifier).updateIngredient(
            ingredient.id,
            name: name,
            notes: notes,
          );
        },
      ),
    );
  }

  void _toggleIngredient(String id) {
    ref.read(ingredientEditProvider.notifier).toggleConfirmation(id);
  }

  void _deleteIngredient(String id) {
    ref.read(ingredientEditProvider.notifier).removeIngredient(id);
  }

  void _addIngredient() {
    showDialog(
      context: context,
      builder: (context) => IngredientEditDialog(
        onSave: (name, notes) {
          ref.read(ingredientEditProvider.notifier).addIngredient(
            name,
            notes: notes,
          );
        },
      ),
    );
  }

  Future<void> _searchRecipes() async {
    final confirmedIngredients = ref.read(ingredientEditProvider.notifier).getConfirmedIngredientNames();
    
    if (confirmedIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please confirm at least one ingredient'),
        ),
      );
      return;
    }

    await ref.read(photoSearchProvider.notifier).searchRecipes(
      ingredients: confirmedIngredients,
    );

    final photoSearchState = ref.read(photoSearchProvider);
    if (photoSearchState.error != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(photoSearchState.error!)),
        );
      }
    } else {
      // Navigate to results page
      if (mounted) {
        context.push('/camera/results');
      }
    }
  }
}
