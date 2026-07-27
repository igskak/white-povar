import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../studio_brand_draft_service.dart';

class StudioRecipeEditorPage extends ConsumerStatefulWidget {
  const StudioRecipeEditorPage({super.key, this.recipeId});

  final String? recipeId;

  @override
  ConsumerState<StudioRecipeEditorPage> createState() =>
      _StudioRecipeEditorPageState();
}

class _StudioRecipeEditorPageState
    extends ConsumerState<StudioRecipeEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _cuisine = TextEditingController(text: 'Українська');
  final _prep = TextEditingController(text: '10');
  final _cook = TextEditingController(text: '20');
  final _servings = TextEditingController(text: '2');
  final _altText = TextEditingController();
  final List<_IngredientDraft> _ingredients = [_IngredientDraft()];
  final List<TextEditingController> _steps = [TextEditingController()];
  final List<String> _selectedTags = [];
  List<String> _availableTags = const [];

  String _category = 'Інше';
  int _difficulty = 1;
  bool _isPremium = false;
  bool _isFeatured = false;
  bool _loading = false;
  bool _saving = false;
  String? _id;
  Object? _error;
  _EditorImage? _primary;
  _EditorImage? _featured;
  _EditorImage? _detail;
  bool _featuredEnabled = false;
  bool _detailEnabled = false;

  @override
  void initState() {
    super.initState();
    _id = widget.recipeId;
    if (_id != null) _load();
    _loadAvailableTags();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _cuisine.dispose();
    _prep.dispose();
    _cook.dispose();
    _servings.dispose();
    _altText.dispose();
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAvailableTags() async {
    try {
      final content = await ref.read(studioBrandDraftServiceProvider).content();
      if (!mounted) return;
      setState(() {
        _availableTags = {
          for (final item in content)
            for (final tag in item.tags)
              if (tag.trim().isNotEmpty) tag.trim(),
        }.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      });
    } catch (_) {
      // Creating a new tag remains available if suggestions cannot be loaded.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json =
          await ref.read(studioBrandDraftServiceProvider).contentItem(_id!);
      if (!mounted) return;
      _title.text = json['title']?.toString() ?? '';
      _description.text = json['description']?.toString() ?? '';
      _category = _categoryFromId(json['category_id']?.toString());
      _difficulty = _integer(json['difficulty_level'], 1).clamp(1, 5).toInt();
      _prep.text = _integer(json['prep_time_minutes'], 0).toString();
      _cook.text = _integer(json['cook_time_minutes'], 0).toString();
      _servings.text = _integer(json['servings'], 1).toString();
      _isPremium = json['is_premium'] == true;
      _isFeatured = json['is_featured'] == true;
      final tags = (json['tags'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList();
      if (tags.isNotEmpty) {
        _cuisine.text = tags.last;
        _selectedTags
          ..clear()
          ..addAll(tags.take(tags.length - 1));
      }

      final steps = json['instructions_structured'] as List<dynamic>? ??
          (json['instructions']?.toString().split('\n') ?? const []);
      _replaceSteps(steps.map((value) => value.toString()).toList());
      final ingredients =
          json['recipe_ingredients'] as List<dynamic>? ?? const [];
      _replaceIngredients(ingredients);

      final presentation = json['image_presentation'];
      if (presentation is Map) {
        _primary = _EditorImage.maybeFromJson(presentation['primary']);
        _featured = _EditorImage.maybeFromJson(presentation['featured']);
        _detail = _EditorImage.maybeFromJson(presentation['detail']);
        _featuredEnabled = _featured != null;
        _detailEnabled = _detail != null;
        _altText.text = _primary?.altText ?? '';
      }
      setState(() => _loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  void _replaceSteps(List<String> values) {
    for (final step in _steps) {
      step.dispose();
    }
    _steps
      ..clear()
      ..addAll((values.isEmpty ? [''] : values)
          .map((value) => TextEditingController(text: value)));
  }

  void _replaceIngredients(List<dynamic> values) {
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    _ingredients
      ..clear()
      ..addAll((values.isEmpty ? [const <String, dynamic>{}] : values).map(
          (value) => _IngredientDraft.fromJson(
              Map<String, dynamic>.from(value as Map))));
  }

  Future<void> _upload(String role) async {
    final alt = _altText.text.trim().isEmpty
        ? _title.text.trim()
        : _altText.text.trim();
    if (alt.isEmpty) {
      _message('Спочатку додайте назву або alt-текст зображення.');
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    setState(() => _saving = true);
    try {
      final asset = await ref.read(studioBrandDraftServiceProvider).upload(
            picked.files.single,
            altText: alt,
            assetKind: 'recipe',
          );
      final image = _EditorImage(
        assetId: asset.id,
        url: asset.url,
        altText: asset.altText,
        width: asset.width,
        height: asset.height,
      );
      setState(() {
        switch (role) {
          case 'featured':
            _featured = image;
            _featuredEnabled = true;
            break;
          case 'detail':
            _detail = image;
            _detailEnabled = true;
            break;
          default:
            _primary = image;
            _altText.text = image.altText;
        }
        _saving = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _message('Не вдалося завантажити фото: $error');
      }
    }
  }

  bool _validate({required bool publishing}) {
    if (!_formKey.currentState!.validate()) return false;
    if (publishing) {
      final hasIngredients =
          _ingredients.any((item) => item.name.text.trim().isNotEmpty);
      final hasSteps = _steps.any((step) => step.text.trim().isNotEmpty);
      if (!hasIngredients || !hasSteps) {
        _message(
          'Для публікації потрібні хоча б один інгредієнт і один крок.',
        );
        return false;
      }
      if (_primary == null) {
        _message('Для публікації потрібна основна фотографія.');
        return false;
      }
    }
    return true;
  }

  Future<void> _save({bool publish = false}) async {
    if (!_validate(publishing: publish)) return;
    setState(() => _saving = true);
    try {
      final response =
          await ref.read(studioBrandDraftServiceProvider).saveContent(
                _payload(),
                id: _id,
              );
      _id = response['id']?.toString();
      if (publish) {
        await ref.read(studioBrandDraftServiceProvider).publishContent(_id!);
      }
      if (!mounted) return;
      setState(() => _saving = false);
      _message(publish ? 'Рецепт опубліковано.' : 'Чернетку збережено.');
      if (publish) context.go('/studio/content');
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _message('Не вдалося зберегти рецепт: $error');
      }
    }
  }

  Map<String, dynamic> _payload() => {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'contentKind': 'recipe',
        'cuisine': _cuisine.text.trim(),
        'category': _category,
        'difficulty': _difficulty,
        'prepTimeMinutes': int.tryParse(_prep.text) ?? 0,
        'cookTimeMinutes': int.tryParse(_cook.text) ?? 0,
        'servings': int.tryParse(_servings.text) ?? 1,
        'ingredients': _ingredients
            .where((item) => item.name.text.trim().isNotEmpty)
            .map((item) => item.toJson())
            .toList(),
        'instructions': _steps
            .map((step) => step.text.trim())
            .where((step) => step.isNotEmpty)
            .toList(growable: false),
        'tags': _selectedTags,
        'isFeatured': _isFeatured,
        'isPremium': _isPremium,
        if (_primary != null)
          'imagePresentation': {
            'primary': _primary!.toJson(altText: _altText.text.trim()),
            'featured': _featuredEnabled ? _featuredPayload(_featured) : null,
            'detail': _detailEnabled ? _featuredPayload(_detail) : null,
          },
      };

  Map<String, dynamic> _featuredPayload(_EditorImage? image) =>
      image?.toJson() ??
      _EditorImage.primaryOverride(
        url: _primary!.url,
        focal: const Offset(.5, .5),
      ).toJson();

  void _message(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Назад до контенту',
          onPressed: () => context.go('/studio/content'),
        ),
        title: Text(_id == null ? 'Новий рецепт' : 'Редагування рецепта'),
        actions: narrow
            ? [
                IconButton(
                  tooltip: 'Зберегти чернетку',
                  onPressed: _saving ? null : () => _save(),
                  icon: const Icon(Icons.save_outlined),
                ),
                IconButton(
                  tooltip: 'Опублікувати',
                  onPressed: _saving ? null : () => _save(publish: true),
                  icon: const Icon(Icons.publish_outlined),
                ),
              ]
            : [
                TextButton(
                  onPressed: _saving ? null : () => _save(),
                  child: const Text('Зберегти чернетку'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton(
                  onPressed: _saving ? null : () => _save(publish: true),
                  child: const Text('Опублікувати'),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: StateView.error(
                    title: 'Не вдалося відкрити рецепт',
                    subtitle: _error.toString(),
                    onRetry: _load,
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _section(
                                'Основне',
                                _basicFields(),
                              ),
                              _section(
                                'Фотографія та кадрування',
                                _mediaFields(),
                              ),
                              _section(
                                'Інгредієнти',
                                _ingredientFields(),
                              ),
                              _section(
                                'Кроки приготування',
                                _stepFields(),
                              ),
                              _section(
                                'Публікація',
                                _publishingFields(),
                              ),
                              const SizedBox(height: 80),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: ContentCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.lg),
              child,
            ],
          ),
        ),
      );

  Widget _basicFields() => Column(
        children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Назва'),
            validator: _required,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Опис'),
            maxLines: 4,
            validator: _required,
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                TextFormField(
                  controller: _cuisine,
                  decoration: const InputDecoration(labelText: 'Кухня'),
                  validator: _required,
                ),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Категорія'),
                  items: _categories
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _category = value ?? 'Інше'),
                ),
              ];
              return constraints.maxWidth < 700
                  ? Column(
                      children: [
                        fields.first,
                        const SizedBox(height: AppSpacing.md),
                        fields.last,
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: fields.first),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: fields.last),
                      ],
                    );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final fields = [
                _numberField(_prep, 'Підготовка, хв'),
                _numberField(_cook, 'Приготування, хв'),
                _numberField(_servings, 'Порції', minimum: 1),
              ];
              return constraints.maxWidth < 600
                  ? Column(
                      children: fields
                          .map((field) => Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: field,
                              ))
                          .toList(),
                    )
                  : Row(
                      children: fields
                          .map((field) => Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      right: AppSpacing.sm),
                                  child: field,
                                ),
                              ))
                          .toList(),
                    );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Text('Складність'),
              Expanded(
                child: Slider(
                  value: _difficulty.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$_difficulty',
                  onChanged: (value) =>
                      setState(() => _difficulty = value.round()),
                ),
              ),
              Text('$_difficulty/5'),
            ],
          ),
          _TagSelector(
            selected: _selectedTags,
            options: _availableTags,
            onAdd: _addTag,
            onRemove: (tag) => setState(() => _selectedTags.remove(tag)),
          ),
        ],
      );

  void _addTag(String rawValue) {
    final value = rawValue.trim();
    if (value.isEmpty ||
        _selectedTags.any((tag) => tag.toLowerCase() == value.toLowerCase())) {
      return;
    }
    setState(() {
      _selectedTags.add(value);
      if (!_availableTags
          .any((tag) => tag.toLowerCase() == value.toLowerCase())) {
        _availableTags = [..._availableTags, value]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      }
    });
  }

  Widget _mediaFields() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _altText,
            decoration: const InputDecoration(
              labelText: 'Alt-текст',
              helperText: 'Коротко опишіть страву для доступності.',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_primary == null)
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _upload('primary'),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Завантажити основне фото'),
            )
          else ...[
            _FocalEditor(
              label: 'Основний фокус',
              image: _primary!,
              onChanged: (value) =>
                  setState(() => _primary = _primary!.withFocal(value)),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _upload('primary'),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Замінити фото'),
            ),
            const SizedBox(height: AppSpacing.lg),
            _CropPreviews(image: _primary!),
            const SizedBox(height: AppSpacing.lg),
            _overrideEditor(
              title: 'Окремий кадр для рецепта дня',
              role: 'featured',
              enabled: _featuredEnabled,
              image: _featured,
              onToggle: (value) => setState(() {
                _featuredEnabled = value;
                if (value && _featured == null) {
                  _featured = _EditorImage.primaryOverride(
                    url: _primary!.url,
                    focal: _primary!.focal,
                  );
                }
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            _overrideEditor(
              title: 'Окремий кадр для відкритого рецепта',
              role: 'detail',
              enabled: _detailEnabled,
              image: _detail,
              onToggle: (value) => setState(() {
                _detailEnabled = value;
                if (value && _detail == null) {
                  _detail = _EditorImage.primaryOverride(
                    url: _primary!.url,
                    focal: _primary!.focal,
                  );
                }
              }),
            ),
          ],
        ],
      );

  Widget _overrideEditor({
    required String title,
    required String role,
    required bool enabled,
    required _EditorImage? image,
    required ValueChanged<bool> onToggle,
  }) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: AppRadius.lg,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(title),
                subtitle: const Text(
                    'Можна змінити лише фокус або завантажити інше фото.'),
                value: enabled,
                onChanged: onToggle,
              ),
              if (enabled && image != null) ...[
                _FocalEditor(
                  label: title,
                  image: image,
                  onChanged: (value) => setState(() {
                    if (role == 'featured') {
                      _featured = image.withFocal(value);
                    } else {
                      _detail = image.withFocal(value);
                    }
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _upload(role),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Використати інше фото'),
                ),
              ],
            ],
          ),
        ),
      );

  Widget _ingredientFields() => Column(
        children: [
          for (var index = 0; index < _ingredients.length; index++) ...[
            _IngredientRow(
              key: ValueKey(_ingredients[index]),
              draft: _ingredients[index],
              onRemove: _ingredients.length == 1
                  ? null
                  : () => setState(() {
                        _ingredients.removeAt(index).dispose();
                      }),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _ingredients.add(_IngredientDraft())),
              icon: const Icon(Icons.add),
              label: const Text('Додати інгредієнт'),
            ),
          ),
        ],
      );

  Widget _stepFields() => Column(
        children: [
          for (var index = 0; index < _steps.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: CircleAvatar(
                    radius: 14,
                    child: Text('${index + 1}'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _steps[index],
                    decoration: const InputDecoration(labelText: 'Опис кроку'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                ),
                IconButton(
                  tooltip: 'Видалити крок',
                  onPressed: _steps.length == 1
                      ? null
                      : () => setState(() {
                            _steps.removeAt(index).dispose();
                          }),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () =>
                  setState(() => _steps.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('Додати крок'),
            ),
          ),
        ],
      );

  Widget _publishingFields() => Column(
        children: [
          SwitchListTile(
            title: const Text('Featured'),
            subtitle: const Text('Показувати як рекомендований рецепт.'),
            value: _isFeatured,
            onChanged: (value) => setState(() => _isFeatured = value),
          ),
          SwitchListTile(
            title: const Text('Premium'),
            subtitle: const Text('Повний рецепт доступний за підпискою.'),
            value: _isPremium,
            onChanged: (value) => setState(() => _isPremium = value),
          ),
        ],
      );

  TextFormField _numberField(
    TextEditingController controller,
    String label, {
    int minimum = 0,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        validator: (value) {
          final number = int.tryParse(value ?? '');
          return number == null || number < minimum ? 'Мінімум $minimum' : null;
        },
      );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Обов’язкове поле' : null;
}

class _FocalEditor extends StatelessWidget {
  const _FocalEditor({
    required this.label,
    required this.image,
    required this.onChanged,
  });

  final String label;
  final _EditorImage image;
  final ValueChanged<Offset> onChanged;

  @override
  Widget build(BuildContext context) {
    final hasDimensions =
        image.width != null && image.height != null && image.height! > 0;
    final aspectRatio = hasDimensions ? image.width! / image.height! : 4 / 3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        AspectRatio(
          aspectRatio: aspectRatio,
          child: LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              onTapDown: (event) => onChanged(Offset(
                (event.localPosition.dx / constraints.maxWidth)
                    .clamp(0, 1)
                    .toDouble(),
                (event.localPosition.dy / constraints.maxHeight)
                    .clamp(0, 1)
                    .toDouble(),
              )),
              onPanUpdate: (event) => onChanged(Offset(
                (event.localPosition.dx / constraints.maxWidth)
                    .clamp(0, 1)
                    .toDouble(),
                (event.localPosition.dy / constraints.maxHeight)
                    .clamp(0, 1)
                    .toDouble(),
              )),
              child: ClipRRect(
                borderRadius: AppRadius.lg,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      ),
                      child: Image.network(image.url, fit: BoxFit.contain),
                    ),
                    Align(
                      alignment: Alignment(
                        image.focal.dx * 2 - 1,
                        image.focal.dy * 2 - 1,
                      ),
                      child: const _FocalMarker(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TagSelector extends StatefulWidget {
  const _TagSelector({
    required this.selected,
    required this.options,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> selected;
  final List<String> options;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<_TagSelector> createState() => _TagSelectorState();
}

class _TagSelectorState extends State<_TagSelector> {
  TextEditingController? _fieldController;
  FocusNode? _focusNode;

  void _select(String value) {
    widget.onAdd(value);
    _fieldController?.clear();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.selected.isNotEmpty) ...[
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: widget.selected
                  .map(
                    (tag) => InputChip(
                      label: Text(tag),
                      onDeleted: () => widget.onRemove(tag),
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Autocomplete<String>(
            optionsBuilder: (value) {
              final query = value.text.trim().toLowerCase();
              return widget.options.where(
                (tag) =>
                    !widget.selected.any((selectedTag) =>
                        selectedTag.toLowerCase() == tag.toLowerCase()) &&
                    (query.isEmpty || tag.toLowerCase().contains(query)),
              );
            },
            onSelected: _select,
            fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
              _fieldController = controller;
              _focusNode = focusNode;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: 'Теги',
                  hintText: 'Знайдіть або створіть тег',
                  helperText:
                      'Оберіть існуючий варіант або введіть новий і натисніть Enter.',
                  suffixIcon: IconButton(
                    tooltip: 'Показати існуючі теги',
                    onPressed: () => _focusNode?.requestFocus(),
                    icon: const Icon(Icons.arrow_drop_down),
                  ),
                ),
                onSubmitted: (value) {
                  widget.onAdd(value);
                  controller.clear();
                },
              );
            },
          ),
        ],
      );
}

class _FocalMarker extends StatelessWidget {
  const _FocalMarker();

  @override
  Widget build(BuildContext context) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(.82),
          border: Border.all(color: Colors.black87, width: 2),
        ),
        child: const Icon(Icons.add, size: 20, color: Colors.black87),
      );
}

class _CropPreviews extends StatelessWidget {
  const _CropPreviews({required this.image});

  final _EditorImage image;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final children = [
            _CropPreview(label: 'Список · 1:1', ratio: 1, image: image),
            _CropPreview(label: 'Каталог · 4:3', ratio: 4 / 3, image: image),
            _CropPreview(label: 'Featured · 3:2', ratio: 3 / 2, image: image),
          ];
          return constraints.maxWidth < 700
              ? Column(
                  children: children
                      .map((child) => Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: child,
                          ))
                      .toList(),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children
                      .map((child) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.sm),
                              child: child,
                            ),
                          ))
                      .toList(),
                );
        },
      );
}

class _CropPreview extends StatelessWidget {
  const _CropPreview({
    required this.label,
    required this.ratio,
    required this.image,
  });

  final String label;
  final double ratio;
  final _EditorImage image;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          AspectRatio(
            aspectRatio: ratio,
            child: ClipRRect(
              borderRadius: AppRadius.md,
              child: Image.network(
                image.url,
                fit: BoxFit.cover,
                alignment: Alignment(
                  image.focal.dx * 2 - 1,
                  image.focal.dy * 2 - 1,
                ),
              ),
            ),
          ),
        ],
      );
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({super.key, required this.draft, this.onRemove});

  final _IngredientDraft draft;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final name = TextFormField(
      controller: draft.name,
      decoration: const InputDecoration(labelText: 'Інгредієнт'),
    );
    final amount = TextFormField(
      controller: draft.amount,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: const InputDecoration(labelText: 'Кількість'),
    );
    final unit = TextFormField(
      controller: draft.unit,
      decoration: const InputDecoration(labelText: 'Одиниця'),
    );
    final notes = TextFormField(
      controller: draft.notes,
      decoration: const InputDecoration(labelText: 'Примітка'),
    );
    final remove = IconButton(
      tooltip: 'Видалити інгредієнт',
      onPressed: onRemove,
      icon: const Icon(Icons.delete_outline),
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 700
          ? Column(
              children: [
                Row(children: [Expanded(child: name), remove]),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(child: amount),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: unit),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                notes,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: name),
                const SizedBox(width: AppSpacing.sm),
                Expanded(flex: 2, child: amount),
                const SizedBox(width: AppSpacing.sm),
                Expanded(flex: 2, child: unit),
                const SizedBox(width: AppSpacing.sm),
                Expanded(flex: 3, child: notes),
                remove,
              ],
            ),
    );
  }
}

class _IngredientDraft {
  _IngredientDraft({
    String name = '',
    String amount = '',
    String unit = '',
    String notes = '',
  })  : name = TextEditingController(text: name),
        amount = TextEditingController(text: amount),
        unit = TextEditingController(text: unit),
        notes = TextEditingController(text: notes);

  factory _IngredientDraft.fromJson(Map<String, dynamic> json) =>
      _IngredientDraft(
        name:
            json['display_name']?.toString() ?? json['name']?.toString() ?? '',
        amount: json['amount']?.toString() ?? '',
        unit: json['unit']?.toString() ??
            _unitFromId(json['unit_id']?.toString()),
        notes: json['preparation_notes']?.toString() ??
            json['notes']?.toString() ??
            '',
      );

  final TextEditingController name;
  final TextEditingController amount;
  final TextEditingController unit;
  final TextEditingController notes;

  Map<String, dynamic> toJson() => {
        'name': name.text.trim(),
        if (double.tryParse(amount.text.replaceAll(',', '.')) != null)
          'amount': double.parse(amount.text.replaceAll(',', '.')),
        'unit': unit.text.trim(),
        if (notes.text.trim().isNotEmpty) 'notes': notes.text.trim(),
      };

  void dispose() {
    name.dispose();
    amount.dispose();
    unit.dispose();
    notes.dispose();
  }
}

class _EditorImage {
  const _EditorImage({
    this.assetId,
    required this.url,
    this.altText = '',
    this.width,
    this.height,
    this.focal = const Offset(.5, .5),
    this.usesPrimary = false,
  });

  factory _EditorImage.primaryOverride({
    required String url,
    required Offset focal,
  }) =>
      _EditorImage(url: url, focal: focal, usesPrimary: true);

  static _EditorImage? maybeFromJson(dynamic value) {
    if (value is! Map || value['url'] == null) return null;
    final focal = value['focal'] is Map ? value['focal'] as Map : const {};
    return _EditorImage(
      assetId: value['asset_id']?.toString(),
      url: value['url'].toString(),
      altText: value['alt_text']?.toString() ?? '',
      width: _nullableInteger(value['width']),
      height: _nullableInteger(value['height']),
      focal: Offset(
        _number(focal['x'], .5).clamp(0, 1).toDouble(),
        _number(focal['y'], .5).clamp(0, 1).toDouble(),
      ),
    );
  }

  final String? assetId;
  final String url;
  final String altText;
  final int? width;
  final int? height;
  final Offset focal;
  final bool usesPrimary;

  _EditorImage withFocal(Offset value) => _EditorImage(
        assetId: assetId,
        url: url,
        altText: altText,
        width: width,
        height: height,
        focal: value,
        usesPrimary: usesPrimary,
      );

  Map<String, dynamic> toJson({String? altText}) => {
        if (usesPrimary)
          'usePrimary': true
        else if (assetId != null)
          'assetId': assetId
        else
          'url': url,
        'altText': altText ?? this.altText,
        'focal': {'x': focal.dx, 'y': focal.dy},
      };
}

int _integer(dynamic value, int fallback) =>
    int.tryParse(value?.toString() ?? '') ?? fallback;

int? _nullableInteger(dynamic value) => int.tryParse(value?.toString() ?? '');

double _number(dynamic value, double fallback) =>
    double.tryParse(value?.toString() ?? '') ?? fallback;

const _categories = [
  'Закуски',
  'Перші страви',
  'Другі страви',
  'Гарніри',
  'Десерти',
  'Напої',
  'Хліб і випічка',
  'Салати',
  'Інше',
];

String _categoryFromId(String? value) => switch (value) {
      '20000000-0000-0000-0000-000000000001' => 'Закуски',
      '20000000-0000-0000-0000-000000000002' => 'Перші страви',
      '20000000-0000-0000-0000-000000000003' => 'Другі страви',
      '20000000-0000-0000-0000-000000000004' => 'Гарніри',
      '20000000-0000-0000-0000-000000000005' => 'Десерти',
      '20000000-0000-0000-0000-000000000006' => 'Напої',
      '20000000-0000-0000-0000-000000000007' => 'Хліб і випічка',
      '20000000-0000-0000-0000-000000000008' => 'Салати',
      _ => 'Інше',
    };

String _unitFromId(String? value) => switch (value) {
      '00000000-0000-0000-0000-000000000001' => 'г',
      '00000000-0000-0000-0000-000000000002' => 'кг',
      '00000000-0000-0000-0000-000000000010' => 'мл',
      '00000000-0000-0000-0000-000000000011' => 'л',
      '00000000-0000-0000-0000-000000000020' => 'шт.',
      '00000000-0000-0000-0000-000000000021' => 'cup',
      '00000000-0000-0000-0000-000000000031' => 'ст. л.',
      '00000000-0000-0000-0000-000000000032' => 'ч. л.',
      _ => '',
    };
