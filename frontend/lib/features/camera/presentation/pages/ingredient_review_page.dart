import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/widgets/state_views.dart';
import '../../models/detected_ingredient.dart';
import '../../providers/photo_search_provider.dart';
import '../widgets/camera_flow_scaffold.dart';
import '../widgets/ingredient_edit_dialog.dart';
import '../widgets/ingredient_list_widget.dart';

class IngredientReviewPage extends ConsumerStatefulWidget {
  const IngredientReviewPage({
    super.key,
    required this.capturedImage,
  });

  final XFile capturedImage;

  @override
  ConsumerState<IngredientReviewPage> createState() =>
      _IngredientReviewPageState();
}

class _IngredientReviewPageState extends ConsumerState<IngredientReviewPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final confirmedCount = ingredients.where((item) => item.isConfirmed).length;

    return CameraFlowScaffold(
      title: 'Review Ingredients',
      step: CameraFlowStep.review,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addIngredient,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton.icon(
          onPressed: confirmedCount == 0 || photoSearchState.isLoading
              ? null
              : _searchRecipes,
          icon: const Icon(Icons.search),
          label: const Text('Find recipes'),
        ),
      ),
      child: _buildContent(
        photoSearchState: photoSearchState,
        ingredients: ingredients,
        confirmedCount: confirmedCount,
      ),
    );
  }

  Widget _buildContent({
    required PhotoSearchState photoSearchState,
    required List<DetectedIngredient> ingredients,
    required int confirmedCount,
  }) {
    if (photoSearchState.isLoading) {
      return const CameraFlowStatusView.loading(
        title: 'Searching recipes',
        subtitle: 'Matching recipes with your selected ingredients.',
      );
    }

    if (photoSearchState.error != null) {
      return CameraFlowStatusView.error(
        title: 'Could not continue',
        subtitle: photoSearchState.error,
        onRetry: _searchRecipes,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            height: 130,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: kIsWeb
                  ? Image.network(widget.capturedImage.path, fit: BoxFit.cover)
                  : Image.file(File(widget.capturedImage.path),
                      fit: BoxFit.cover),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Detected ingredients',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Text('$confirmedCount confirmed'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ingredients.isEmpty
              ? const StateView.empty(
                  title: 'No ingredients detected',
                  subtitle:
                      'Add ingredients manually or go back and retake the photo.',
                  icon: Icons.search_off,
                )
              : IngredientListWidget(
                  ingredients: ingredients,
                  onIngredientTap: _editIngredient,
                  onIngredientToggle: _toggleIngredient,
                  onIngredientDelete: _deleteIngredient,
                ),
        ),
      ],
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
    final confirmedIngredients =
        ref.read(ingredientEditProvider.notifier).getConfirmedIngredientNames();

    if (confirmedIngredients.isEmpty) {
      return;
    }

    await ref.read(photoSearchProvider.notifier).searchRecipes(
          ingredients: confirmedIngredients,
        );

    if (!mounted) {
      return;
    }

    final photoSearchState = ref.read(photoSearchProvider);
    if (photoSearchState.error != null) {
      return;
    }

    context.push('/camera/results');
  }
}
