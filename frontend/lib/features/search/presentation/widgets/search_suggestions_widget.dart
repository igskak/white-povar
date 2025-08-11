import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/search_provider.dart';

class SearchSuggestionsWidget extends ConsumerWidget {
  final String query;
  final ValueChanged<String> onSuggestionSelected;

  const SearchSuggestionsWidget({
    super.key,
    required this.query,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(searchSuggestionsProvider(query));
    final searchHistory = ref.watch(searchHistoryProvider);
    final popularSearches = ref.watch(popularSearchesProvider);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search Suggestions
          suggestionsAsync.when(
            data: (suggestions) {
              if (suggestions.isEmpty) {
                return const SizedBox.shrink();
              }
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Suggestions',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ...suggestions.take(5).map((suggestion) => 
                    _SuggestionTile(
                      suggestion: suggestion,
                      icon: Icons.search,
                      onTap: () => onSuggestionSelected(suggestion),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          
          // Search History
          if (searchHistory.isNotEmpty && query.isEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Recent Searches',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      ref.read(searchHistoryProvider.notifier).clearHistory();
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            ...searchHistory.take(3).map((historyItem) => 
              _SuggestionTile(
                suggestion: historyItem,
                icon: Icons.history,
                onTap: () => onSuggestionSelected(historyItem),
                onRemove: () {
                  ref.read(searchHistoryProvider.notifier).removeSearch(historyItem);
                },
              ),
            ),
          ],
          
          // Popular Searches
          if (query.isEmpty)
            popularSearches.when(
              data: (popular) {
                if (popular.isEmpty) return const SizedBox.shrink();
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Popular Searches',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...popular.take(3).map((popularItem) => 
                      _SuggestionTile(
                        suggestion: popularItem,
                        icon: Icons.trending_up,
                        onTap: () => onSuggestionSelected(popularItem),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  final String suggestion;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _SuggestionTile({
    required this.suggestion,
    required this.icon,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        suggestion,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      trailing: onRemove != null
          ? IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onRemove,
              tooltip: 'Remove from history',
            )
          : const Icon(Icons.north_west, size: 16),
      onTap: onTap,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
