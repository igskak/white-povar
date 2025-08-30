import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../recipes/presentation/widgets/recipe_card.dart';
import '../../providers/search_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) {
    ref.read(simpleTextSearchProvider.notifier).searchRecipes(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Recipes'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search for recipes...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(simpleTextSearchProvider.notifier)
                              .clearSearch();
                          setState(() {}); // Refresh to hide clear button
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {});
                if (value.length >= 2) {
                  _performSearch(value);
                }
              },
              onSubmitted: _performSearch,
            ),
          ),
          Expanded(
            child: _buildSearchResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchState = ref.watch(simpleTextSearchProvider);

    if (searchState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (searchState.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(searchState.error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _performSearch(_searchController.text),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search for recipes',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Enter ingredients, recipe names, or cuisines',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (searchState.results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No recipes found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Try different keywords',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: searchState.results.length,
      itemBuilder: (context, index) {
        final recipe = searchState.results[index];
        return RecipeCard(
          recipe: recipe,
          onTap: () => context.push('/recipes/${recipe.id}'),
        );
      },
    );
  }
}
