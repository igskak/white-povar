import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../app/router/route_models.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../recipes/models/recipe.dart';
import '../../../recipes/repositories/recipe_repository.dart';
import '../../../recipes/presentation/widgets/recipe_card.dart';
import '../../providers/search_provider.dart';
import '../../../voice/providers/voice_input_provider.dart';
import '../widgets/voice_input_status.dart';
import '../../../ai/models/generated_recipe.dart';
import '../../../ai/services/recipe_generation_service.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key, this.initialRoute});

  final SearchRouteLocation? initialRoute;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _showFilters = false;
  String? _activeTag;
  String? _selectedRecipeId;
  final List<String> _recentSearches = [];

  static const _suggestions = [
    'Швидка вечеря',
    'З овочами',
    'Сніданок',
    'Паста',
  ];

  static const _filters = [
    _DiscoveryFilter('До 30 хв', Icons.schedule_outlined),
    _DiscoveryFilter('Без м’яса', Icons.eco_outlined),
    _DiscoveryFilter('Для родини', Icons.people_outline),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final initialValue = widget.initialRoute?.query ?? widget.initialRoute?.tag;
    if (initialValue == null) return;

    _searchController.text = initialValue;
    _activeTag = widget.initialRoute?.tag;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _performSearch(initialValue);
    });
  }

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final route = widget.initialRoute;
    if (route == oldWidget.initialRoute || route == null) return;
    final value = route.query ?? route.tag ?? '';
    if (value == _searchController.text && route.tag == _activeTag) return;
    _searchController.text = value;
    _activeTag = route.tag;
    if (value.isEmpty) {
      ref.read(simpleTextSearchProvider.notifier).clearSearch();
    } else {
      _performSearch(value);
    }
  }

  void _performSearch(String query) {
    ref.read(simpleTextSearchProvider.notifier).searchRecipes(query);
  }

  void _onTextChanged(String value) {
    setState(() => _activeTag = null);
    _updateLocation();
    if (value.trim().length >= 2) {
      _performSearch(value);
    } else if (value.trim().isEmpty) {
      ref.read(simpleTextSearchProvider.notifier).clearSearch();
    }
  }

  Future<void> _requestVoiceConsent() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Голосовий пошук'),
        content: const Text(
          'Ми перетворимо сказане на текст у полі пошуку. Аудіо не '
          'зберігається та не надсилається до каталогу.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Скасувати'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Дозволити мікрофон'),
          ),
        ],
      ),
    );
    if (approved == true && mounted) {
      await ref.read(voiceInputProvider.notifier).startListening();
    }
  }

  void _syncVoiceTranscript(VoiceInputState voiceState) {
    if (voiceState.transcript.isEmpty ||
        voiceState.transcript == _searchController.text) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || voiceState.transcript == _searchController.text) return;
      _searchController.value = TextEditingValue(
        text: voiceState.transcript,
        selection:
            TextSelection.collapsed(offset: voiceState.transcript.length),
      );
      setState(() => _activeTag = null);
      _updateLocation();
      if (voiceState.isFinalTranscript &&
          voiceState.transcript.trim().length >= 2) {
        ref
            .read(simpleTextSearchProvider.notifier)
            .searchVoiceIntent(voiceState.transcript);
      }
    });
  }

  void _applySuggestion(String value) {
    setState(() {
      _activeTag = null;
      _searchController.text = value;
    });
    _updateLocation();
    _performSearch(value);
  }

  void _applyTag(String tag) {
    setState(() {
      _activeTag = tag;
      _searchController.text = tag;
    });
    _updateLocation();
    _performSearch(tag);
  }

  void _updateLocation() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    router.go(
      SearchRouteLocation(
        query: _activeTag == null ? _searchController.text.trim() : null,
        tag: _activeTag,
      ).toUri().toString(),
    );
  }

  void _rememberSearch(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    setState(() {
      _recentSearches.remove(query);
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 3) _recentSearches.removeLast();
    });
  }

  void _clearSearch() {
    setState(() {
      _activeTag = null;
      _selectedRecipeId = null;
      _searchController.clear();
    });
    _updateLocation();
    ref.read(simpleTextSearchProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(simpleTextSearchProvider);
    final voiceState = ref.watch(voiceInputProvider);
    _syncVoiceTranscript(voiceState);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            ResponsiveContainer(
              maxWidth: 1280,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: _SearchHeader(
                  controller: _searchController,
                  isLoading: searchState.isLoading,
                  showFilters: _showFilters,
                  activeTag: _activeTag,
                  filters: _filters,
                  onToggleFilters: () =>
                      setState(() => _showFilters = !_showFilters),
                  onClear: _clearSearch,
                  onChanged: _onTextChanged,
                  onSubmitted: (value) {
                    _rememberSearch(value);
                    if (searchState.confirmationRequired.isNotEmpty) {
                      ref
                          .read(simpleTextSearchProvider.notifier)
                          .searchVoiceIntent(value);
                    } else {
                      _performSearch(value);
                    }
                  },
                  onFilterSelected: _applySuggestion,
                  voiceState: voiceState,
                  confirmationRequired: searchState.confirmationRequired,
                  onStartVoice: _requestVoiceConsent,
                  onStopVoice: () =>
                      ref.read(voiceInputProvider.notifier).stopListening(),
                  onCancelVoice: () =>
                      ref.read(voiceInputProvider.notifier).cancelListening(),
                ),
              ),
            ),
            Expanded(child: _buildBody(searchState)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(SimpleSearchState searchState) {
    if (searchState.error != null) {
      return StateView.error(
        title: 'Пошук не спрацював',
        subtitle: searchState.error,
        onRetry: () => _performSearch(_searchController.text),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return _DiscoveryStart(
        recentSearches: _recentSearches,
        suggestions: _suggestions,
        onSelected: _applySuggestion,
        onTagSelected: _applyTag,
      );
    }

    if (searchState.isLoading && searchState.results.isEmpty) {
      return const _SearchSkeleton();
    }

    if (searchState.results.isEmpty) {
      return _NoResults(
        suggestions: _suggestions,
        onClear: _clearSearch,
        onSelected: _applySuggestion,
        showAiGeneration: searchState.isVoiceIntentSearch,
        onAiGeneration: _showAiGenerationConsent,
      );
    }

    return _SearchResults(
      recipes: searchState.results,
      selectedRecipeId: _selectedRecipeId,
      onSelected: (recipe) => setState(() => _selectedRecipeId = recipe.id),
      confirmationRequired: searchState.confirmationRequired,
      recommendations: searchState.recommendations,
    );
  }

  Future<void> _showAiGenerationConsent() async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Створити AI-рецепт?'),
        content: const Text(
            'За вашим запитом ми надішлемо текст до AI, щоб створити новий рецепт у загальному стилі автора. Це не опублікований рецепт Олександра і не буде збережено без окремої дії.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Скасувати')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Погоджуюсь і створюю')),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AiRecipeGenerationDialog(
        prompt: _searchController.text.trim(),
        service: ref.read(recipeGenerationServiceProvider),
      ),
    );
  }
}

class _AiRecipeGenerationDialog extends StatefulWidget {
  const _AiRecipeGenerationDialog(
      {required this.prompt, required this.service});
  final String prompt;
  final RecipeGenerationService service;

  @override
  State<_AiRecipeGenerationDialog> createState() =>
      _AiRecipeGenerationDialogState();
}

class _AiRecipeGenerationDialogState extends State<_AiRecipeGenerationDialog> {
  String _status = 'Готуємо AI-генерацію…';
  String? _error;
  GeneratedRecipe? _recipe;
  String? _draftId;
  String? _draftMessage;
  bool _savingDraft = false;
  StreamSubscription<RecipeGenerationEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.service.generate(widget.prompt).listen((event) {
      if (!mounted) return;
      setState(() {
        switch (event) {
          case RecipeGenerationStatus(:final message):
            _status = message;
          case RecipeGenerationComplete(:final recipe):
            _recipe = recipe;
          case RecipeGenerationFailure(:final message):
            _error = message;
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    final recipe = _recipe;
    if (recipe == null) return;
    setState(() => _savingDraft = true);
    try {
      final draftId = await widget.service.saveDraft(recipe);
      if (mounted) {
        setState(() {
          _draftId = draftId;
          _draftMessage = 'Чернетку збережено приватно для вас.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _draftMessage = 'Не вдалося зберегти чернетку.');
      }
    } finally {
      if (mounted) {
        setState(() => _savingDraft = false);
      }
    }
  }

  Future<void> _deleteDraft() async {
    final draftId = _draftId;
    if (draftId == null) return;
    try {
      await widget.service.deleteDraft(draftId);
      if (mounted) {
        setState(() {
          _draftId = null;
          _draftMessage = 'Чернетку видалено назавжди.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _draftMessage = 'Не вдалося видалити чернетку.');
      }
    }
  }

  Future<void> _sendFeedback(bool helpful) async {
    final draftId = _draftId;
    if (draftId == null) return;
    try {
      await widget.service.sendDraftFeedback(draftId, helpful: helpful);
      if (mounted) {
        setState(() => _draftMessage = 'Дякуємо за відгук.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _draftMessage = 'Не вдалося надіслати відгук.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(_recipe == null ? 'Створюємо AI-рецепт' : _recipe!.title),
        content: SizedBox(
          width: 440,
          child: _error != null
              ? Text(_error!)
              : _recipe == null
                  ? Row(children: [
                      const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(_status)),
                    ])
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_recipe!.attribution,
                              style: Theme.of(context).textTheme.labelLarge),
                          const SizedBox(height: AppSpacing.sm),
                          Text(_recipe!.description),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                              '${_recipe!.servings} порц. · ${_recipe!.totalTimeMinutes} хв'),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Інгредієнти',
                              style: Theme.of(context).textTheme.titleSmall),
                          ..._recipe!.ingredients.map(
                              (item) => Text('• ${item.amount} ${item.name}')),
                          const SizedBox(height: AppSpacing.sm),
                          Text('Кроки',
                              style: Theme.of(context).textTheme.titleSmall),
                          ..._recipe!.steps.indexed.map(
                              (item) => Text('${item.$1 + 1}. ${item.$2}')),
                          const SizedBox(height: AppSpacing.sm),
                          Text(_recipe!.safetyNote,
                              style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: AppSpacing.sm),
                          const Text(
                              'Перевірте склад усіх продуктів і замінників щодо власних алергенів.'),
                          if (_draftMessage != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(_draftMessage!),
                          ],
                        ],
                      ),
                    ),
        ),
        actions: [
          if (_recipe != null && _draftId == null)
            FilledButton(
              onPressed: _savingDraft ? null : _saveDraft,
              child: Text(_savingDraft ? 'Зберігаємо…' : 'Зберегти чернетку'),
            ),
          if (_draftId != null) ...[
            IconButton(
              tooltip: 'Корисна чернетка',
              onPressed: () => _sendFeedback(true),
              icon: const Icon(Icons.thumb_up_outlined),
            ),
            IconButton(
              tooltip: 'Проблема з чернеткою',
              onPressed: () => _sendFeedback(false),
              icon: const Icon(Icons.thumb_down_outlined),
            ),
            TextButton(
              onPressed: _deleteDraft,
              child: const Text('Видалити чернетку'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
                _recipe == null && _error == null ? 'Скасувати' : 'Закрити'),
          ),
        ],
      );
}

class _SearchHeader extends StatelessWidget {
  const _SearchHeader(
      {required this.controller,
      required this.isLoading,
      required this.showFilters,
      required this.activeTag,
      required this.filters,
      required this.onToggleFilters,
      required this.onClear,
      required this.onChanged,
      required this.onSubmitted,
      required this.onFilterSelected,
      required this.voiceState,
      required this.confirmationRequired,
      required this.onStartVoice,
      required this.onStopVoice,
      required this.onCancelVoice});
  final TextEditingController controller;
  final bool isLoading;
  final bool showFilters;
  final String? activeTag;
  final List<_DiscoveryFilter> filters;
  final VoidCallback onToggleFilters;
  final VoidCallback onClear;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onFilterSelected;
  final VoiceInputState voiceState;
  final List<String> confirmationRequired;
  final VoidCallback onStartVoice;
  final VoidCallback onStopVoice;
  final VoidCallback onCancelVoice;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Пошук', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text('Рецепти, інгредієнти та добірки Олександра.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColorsV2.textSecondary)),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
            controller: controller,
            hint: 'Наприклад: томати, паста, вечеря',
            prefixIcon: const Icon(Icons.search),
            textInputAction: TextInputAction.search,
            suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
              if (isLoading)
                const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))),
              if (controller.text.isNotEmpty)
                AppIconButton(
                  icon: Icons.clear,
                  tooltip: 'Очистити',
                  onPressed: onClear,
                ),
              AppIconButton(
                icon: voiceState.isListening ? Icons.mic : Icons.mic_none,
                tooltip: voiceState.isListening
                    ? 'Зупинити голосове введення'
                    : 'Голосове введення',
                filled: voiceState.isListening,
                onPressed: voiceState.isListening ? onStopVoice : onStartVoice,
              ),
            ]),
            onChanged: onChanged,
            onSubmitted: onSubmitted),
        VoiceInputStatus(
          state: voiceState,
          onRetry: onStartVoice,
          onStop: onStopVoice,
          onCancel: onCancelVoice,
        ),
        if (confirmationRequired.contains('servings'))
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'Уточніть кількість порцій у запиті, щоб звузити рекомендації.',
              semanticsLabel: 'Потрібно підтвердити кількість порцій',
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        Row(children: [
          AppButton(
              label: showFilters ? 'Сховати фільтри' : 'Фільтри',
              icon: Icons.tune_outlined,
              variant: AppButtonVariant.text,
              onPressed: onToggleFilters),
          if (activeTag != null)
            Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: AppChip(
                    label: 'Тег: $activeTag',
                    selected: true,
                    onSelected: (_) => onClear()))
        ]),
        AnimatedSize(
            duration: AppMotion.medium,
            child: showFilters
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: filters
                            .map((filter) => AppChip(
                                label: filter.label,
                                avatar: Icon(filter.icon, size: 16),
                                onSelected: (_) =>
                                    onFilterSelected(filter.label)))
                            .toList()))
                : const SizedBox.shrink()),
        const SizedBox(height: AppSpacing.sm),
      ]);
}

class _DiscoveryStart extends StatelessWidget {
  const _DiscoveryStart(
      {required this.recentSearches,
      required this.suggestions,
      required this.onSelected,
      required this.onTagSelected});
  final List<String> recentSearches;
  final List<String> suggestions;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onTagSelected;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(AppSpacing.md), children: [
        Text('Що готуємо сьогодні?',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text('Почніть з інгредієнта або добірки.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColorsV2.textSecondary)),
        const SizedBox(height: AppSpacing.lg),
        if (recentSearches.isNotEmpty) ...[
          Text('Нещодавні', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: recentSearches
                  .map((item) => AppChip(
                      label: item,
                      avatar: const Icon(Icons.history, size: 16),
                      onSelected: (_) => onSelected(item)))
                  .toList()),
          const SizedBox(height: AppSpacing.lg)
        ],
        Text('Спробуйте', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: suggestions
                .map((item) =>
                    AppChip(label: item, onSelected: (_) => onSelected(item)))
                .toList()),
        const SizedBox(height: AppSpacing.lg),
        ContentCard(
            onTap: () => onTagSelected('maisternia-oleksandra'),
            semanticLabel: 'Відкрити добірку Майстерня Олександра',
            child: Row(children: [
              const Icon(Icons.workspace_premium_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Майстерня Олександра',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Text('Відкрити рецепти з добірки')
                  ]))
            ]))
      ]);
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();
  @override
  Widget build(BuildContext context) => GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 380,
          mainAxisSpacing: AppSpacing.md,
          crossAxisSpacing: AppSpacing.md,
          childAspectRatio: .9),
      itemCount: 6,
      itemBuilder: (_, __) => const Card(
          child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: AppSkeleton(
                            height: double.infinity,
                            borderRadius: AppRadius.md)),
                    SizedBox(height: AppSpacing.md),
                    AppSkeleton(width: 180, height: 20),
                    SizedBox(height: AppSpacing.xs),
                    AppSkeleton(width: 240),
                    SizedBox(height: AppSpacing.xs),
                    AppSkeleton(width: 140)
                  ]))));
}

class _NoResults extends StatelessWidget {
  const _NoResults(
      {required this.suggestions,
      required this.onClear,
      required this.onSelected,
      required this.showAiGeneration,
      required this.onAiGeneration});
  final List<String> suggestions;
  final VoidCallback onClear;
  final ValueChanged<String> onSelected;
  final bool showAiGeneration;
  final VoidCallback onAiGeneration;
  @override
  Widget build(BuildContext context) => Center(
      child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.search_off_rounded, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text('Нічого не знайшли',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text('Спробуйте інший інгредієнт або коротший запит.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColorsV2.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Скинути пошук', onPressed: onClear),
            if (showAiGeneration) ...[
              const SizedBox(height: AppSpacing.xs),
              AppButton(
                label: 'Створити AI-рецепт',
                icon: Icons.auto_awesome_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: onAiGeneration,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Wrap(
                alignment: WrapAlignment.center,
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: suggestions
                    .map((item) => AppChip(
                        label: item, onSelected: (_) => onSelected(item)))
                    .toList())
          ])));
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.recipes,
    required this.selectedRecipeId,
    required this.onSelected,
    this.confirmationRequired = const [],
    this.recommendations = const [],
  });

  final List<Recipe> recipes;
  final String? selectedRecipeId;
  final ValueChanged<Recipe> onSelected;
  final List<String> confirmationRequired;
  final List<VoiceRecommendation> recommendations;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final recommendationById = {
            for (final item in recommendations) item.recipe.id: item,
          };
          if (constraints.maxWidth >= 1024) {
            final selected = recipes
                    .where((recipe) => recipe.id == selectedRecipeId)
                    .firstOrNull ??
                recipes.first;
            return Row(
              children: [
                SizedBox(
                  width: 420,
                  child: _RecipeList(
                    recipes: recipes,
                    selectedRecipeId: selected.id,
                    onSelected: onSelected,
                    recommendations: recommendationById,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: _DiscoveryPreview(
                      recipe: selected,
                      onOpen: () => context.push('/recipes/${selected.id}'),
                    ),
                  ),
                ),
              ],
            );
          }
          final columns = constraints.maxWidth >= 600 ? 3 : 1;
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              // RecipeCard keeps all metadata visible at large text scales.
              childAspectRatio: columns == 1 ? .75 : .55,
            ),
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              final recommendation = recommendationById[recipe.id];
              return Stack(children: [
                RecipeCard(
                    recipe: recipe,
                    onTap: () => context.push('/recipes/${recipe.id}')),
                if (recommendation != null)
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: Tooltip(
                      message: _recommendationDetails(recommendation),
                      child: Semantics(
                        label: _recommendationDetails(recommendation),
                        child: Material(
                          color: Theme.of(context).colorScheme.surface,
                          shape: const StadiumBorder(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xs, vertical: 3),
                            child: Text('Чому підходить',
                                style: Theme.of(context).textTheme.labelSmall),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]);
            },
          );
        },
      );
}

String _recommendationDetails(VoiceRecommendation recommendation) {
  final parts = [...recommendation.whyItFits];
  if (recommendation.missingIngredients.isNotEmpty) {
    parts.add(
        'Потрібно докупити: ${recommendation.missingIngredients.join(', ')}');
  }
  return parts.isEmpty ? 'Частковий збіг запиту' : parts.join('. ');
}

class _RecipeList extends StatelessWidget {
  const _RecipeList(
      {required this.recipes,
      required this.selectedRecipeId,
      required this.onSelected,
      required this.recommendations});
  final List<Recipe> recipes;
  final String selectedRecipeId;
  final ValueChanged<Recipe> onSelected;
  final Map<String, VoiceRecommendation> recommendations;
  @override
  Widget build(BuildContext context) => ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: recipes.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final recipe = recipes[index];
        final recommendation = recommendations[recipe.id];
        return ListTile(
            selected: recipe.id == selectedRecipeId,
            shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
            leading: recipe.isPremium
                ? const Icon(Icons.lock_outline)
                : const Icon(Icons.restaurant_menu_outlined),
            title: Text(recipe.title,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
                recommendation == null
                    ? '${recipe.totalTimeMinutes} хв · ${recipe.cuisine}'
                    : _recommendationDetails(recommendation),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            onTap: () => onSelected(recipe));
      });
}

class _DiscoveryPreview extends StatelessWidget {
  const _DiscoveryPreview({required this.recipe, required this.onOpen});
  final Recipe recipe;
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Обраний рецепт',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Expanded(child: RecipeCard(recipe: recipe, onTap: onOpen)),
            const SizedBox(height: AppSpacing.md),
            AppButton(
                label: 'Відкрити рецепт',
                icon: Icons.arrow_forward,
                expand: true,
                onPressed: onOpen)
          ])));
}

class _DiscoveryFilter {
  const _DiscoveryFilter(this.label, this.icon);
  final String label;
  final IconData icon;
}
