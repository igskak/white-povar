import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/recipe_suggestion.dart';
import '../services/recipe_conversion_service.dart';

class ShoppingListWidget extends StatefulWidget {
  final RecipeSuggestion suggestion;

  const ShoppingListWidget({
    super.key,
    required this.suggestion,
  });

  @override
  State<ShoppingListWidget> createState() => _ShoppingListWidgetState();
}

class _ShoppingListWidgetState extends State<ShoppingListWidget> {
  late Map<String, dynamic> shoppingList;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateShoppingList();
  }

  void _generateShoppingList() {
    setState(() {
      _isLoading = true;
    });

    // Simulate loading time for better UX
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          shoppingList = RecipeConversionService.instance.generateShoppingList(widget.suggestion);
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Generating Shopping List...'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Organizing your ingredients...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Shopping List'),
            Text(
              shoppingList['recipe_title'],
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _copyToClipboard,
            icon: const Icon(Icons.copy),
            tooltip: 'Copy to clipboard',
          ),
          IconButton(
            onPressed: _shareShoppingList,
            icon: const Icon(Icons.share),
            tooltip: 'Share shopping list',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 16),
            _buildShoppingTips(),
            const SizedBox(height: 16),
            _buildCategorizedIngredients(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _copyToClipboard,
        icon: const Icon(Icons.copy),
        label: const Text('Copy List'),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Shopping Summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem(
                  'Total Items',
                  '${shoppingList['total_items']}',
                  Icons.list_alt,
                ),
                _buildSummaryItem(
                  'Estimated Cost',
                  shoppingList['estimated_total_cost'],
                  Icons.attach_money,
                ),
                _buildSummaryItem(
                  'Prep Impact',
                  shoppingList['prep_time_impact'].toString().toUpperCase(),
                  Icons.timer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildShoppingTips() {
    final tips = shoppingList['shopping_tips'] as List<String>? ?? [];
    if (tips.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Shopping Tips',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...tips.map((tip) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                tip,
                style: TextStyle(color: Colors.grey[700]),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorizedIngredients() {
    final categorizedIngredients = shoppingList['categorized_ingredients'] as Map<String, dynamic>;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredients by Category',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        ...categorizedIngredients.entries.map((entry) => 
          _buildCategorySection(entry.key, entry.value as List<dynamic>)
        ),
      ],
    );
  }

  Widget _buildCategorySection(String category, List<dynamic> ingredients) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(_getCategoryIcon(category)),
        title: Text(
          category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${ingredients.length} items'),
        children: ingredients.map((ingredient) => 
          _buildIngredientItem(ingredient as Map<String, dynamic>)
        ).toList(),
      ),
    );
  }

  Widget _buildIngredientItem(Map<String, dynamic> ingredient) {
    return ListTile(
      leading: CircleAvatar(
        radius: 12,
        backgroundColor: _getPriorityColor(ingredient['priority']),
        child: Text(
          ingredient['priority'].toString().substring(0, 1).toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      title: Text(ingredient['name']),
      subtitle: Text('${ingredient['estimated_amount']} • ${ingredient['estimated_cost']}'),
      trailing: Icon(
        Icons.add_shopping_cart,
        color: Colors.grey[400],
        size: 20,
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Meat & Seafood':
        return Icons.set_meal;
      case 'Dairy & Eggs':
        return Icons.egg;
      case 'Fruits':
        return Icons.apple;
      case 'Vegetables':
        return Icons.eco;
      case 'Grains & Bread':
        return Icons.grain;
      case 'Condiments & Spices':
        return Icons.local_dining;
      case 'Pantry & Protein':
        return Icons.kitchen;
      default:
        return Icons.shopping_basket;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _copyToClipboard() {
    final text = _generateClipboardText();
    Clipboard.setData(ClipboardData(text: text));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Shopping list copied to clipboard!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareShoppingList() {
    // For now, just copy to clipboard
    // In a real app, you'd use share_plus package
    _copyToClipboard();
  }

  String _generateClipboardText() {
    final buffer = StringBuffer();
    buffer.writeln('🛒 Shopping List for ${shoppingList['recipe_title']}');
    buffer.writeln('');
    buffer.writeln('📊 Summary:');
    buffer.writeln('• Total Items: ${shoppingList['total_items']}');
    buffer.writeln('• Estimated Cost: ${shoppingList['estimated_total_cost']}');
    buffer.writeln('• Prep Impact: ${shoppingList['prep_time_impact']}');
    buffer.writeln('');

    final categorizedIngredients = shoppingList['categorized_ingredients'] as Map<String, dynamic>;
    
    for (final entry in categorizedIngredients.entries) {
      buffer.writeln('📂 ${entry.key}:');
      final ingredients = entry.value as List<dynamic>;
      for (final ingredient in ingredients) {
        final ing = ingredient as Map<String, dynamic>;
        buffer.writeln('  • ${ing['estimated_amount']} ${ing['name']} (${ing['estimated_cost']})');
      }
      buffer.writeln('');
    }

    final tips = shoppingList['shopping_tips'] as List<String>? ?? [];
    if (tips.isNotEmpty) {
      buffer.writeln('💡 Shopping Tips:');
      for (final tip in tips) {
        buffer.writeln('• $tip');
      }
    }

    return buffer.toString();
  }
}
