import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/state_views.dart';
import '../../studio_brand_draft_service.dart';

class StudioCollectionEditorPage extends ConsumerStatefulWidget {
  const StudioCollectionEditorPage({super.key, this.collectionId});

  final String? collectionId;

  @override
  ConsumerState<StudioCollectionEditorPage> createState() =>
      _StudioCollectionEditorPageState();
}

class _StudioCollectionEditorPageState
    extends ConsumerState<StudioCollectionEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _slug = TextEditingController();
  final _description = TextEditingController();
  final _coverUrl = TextEditingController();
  List<StudioContentItem> _content = const [];
  final List<_CollectionMaterial> _items = [];
  bool _isPremium = false;
  bool _loading = false;
  bool _saving = false;
  Object? _error;
  String? _id;

  @override
  void initState() {
    super.initState();
    _id = widget.collectionId;
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _slug.dispose();
    _description.dispose();
    _coverUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(studioBrandDraftServiceProvider);
      final results = await Future.wait([
        service.content(),
        if (_id != null) service.collection(_id!),
      ]);
      if (!mounted) return;
      _content = results.first as List<StudioContentItem>;
      if (_id != null) {
        final json = results[1] as Map<String, dynamic>;
        final titles = json['title_i18n'];
        final descriptions = json['description_i18n'];
        _title.text = titles is Map ? titles['uk']?.toString() ?? '' : '';
        _description.text =
            descriptions is Map ? descriptions['uk']?.toString() ?? '' : '';
        _slug.text = json['slug']?.toString() ?? '';
        _coverUrl.text = json['cover_url']?.toString() ?? '';
        _isPremium = json['is_premium'] == true;
        final rows = (json['collection_items'] as List<dynamic>? ?? const [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList()
          ..sort((a, b) =>
              _number(a['position']).compareTo(_number(b['position'])));
        _items
          ..clear()
          ..addAll(rows.map((row) => _CollectionMaterial(
                recipeId: row['recipe_id'].toString(),
                isPreview: row['is_preview'] == true,
              )));
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

  static int _number(dynamic value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  String _materialTitle(String id) =>
      _content
          .where((item) => item.id == id)
          .map((item) => item.title)
          .firstOrNull ??
      'Недоступний матеріал';

  Future<void> _save({bool publish = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final service = ref.read(studioBrandDraftServiceProvider);
      final response = await service.saveCollection({
        'slug': _slug.text.trim(),
        'titleI18n': {'uk': _title.text.trim()},
        'descriptionI18n': {'uk': _description.text.trim()},
        'coverUrl':
            _coverUrl.text.trim().isEmpty ? null : _coverUrl.text.trim(),
        'isPremium': _isPremium,
        'items': [
          for (final item in _items)
            {'recipeId': item.recipeId, 'isPreview': item.isPreview},
        ],
      }, id: _id);
      _id = response['id']?.toString();
      if (publish) await service.publishCollection(_id!);
      if (!mounted) return;
      setState(() => _saving = false);
      _message(publish ? 'Колекцію опубліковано.' : 'Колекцію збережено.');
      if (publish) context.go('/studio/content');
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _message('Не вдалося зберегти колекцію: $error');
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Обов’язкове поле' : null;

  String? _validateSlug(String? value) {
    if (_required(value) != null) return _required(value);
    return RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(value!.trim())
        ? null
        : 'Лише малі латинські літери, цифри та дефіси';
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
        title: Text(_id == null ? 'Нова колекція' : 'Редагування колекції'),
        actions: narrow
            ? [
                IconButton(
                  tooltip: 'Зберегти',
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
                  child: const Text('Зберегти'),
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
                    title: 'Не вдалося відкрити колекцію',
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
                          constraints: const BoxConstraints(maxWidth: 960),
                          child: Column(
                            children: [
                              _section('Основне', _basicFields()),
                              _section('Матеріали', _materials()),
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
            controller: _slug,
            decoration: const InputDecoration(labelText: 'Slug'),
            validator: _validateSlug,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Опис'),
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _coverUrl,
            decoration: const InputDecoration(labelText: 'URL обкладинки'),
            keyboardType: TextInputType.url,
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Premium-колекція'),
            value: _isPremium,
            onChanged: (value) => setState(() => _isPremium = value),
          ),
        ],
      );

  Widget _materials() {
    final available =
        _content.where((item) => !_items.any((row) => row.recipeId == item.id));
    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey(_items.length),
          decoration: const InputDecoration(labelText: 'Додати матеріал'),
          items: [
            for (final item in available)
              DropdownMenuItem(value: item.id, child: Text(item.title)),
          ],
          onChanged: (id) {
            if (id != null) {
              setState(() => _items.add(_CollectionMaterial(recipeId: id)));
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (_items.isEmpty)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('У колекції ще немає матеріалів.'),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) newIndex--;
                final item = _items.removeAt(oldIndex);
                _items.insert(newIndex, item);
              });
            },
            itemBuilder: (context, index) {
              final item = _items[index];
              return ListTile(
                key: ValueKey(item.recipeId),
                leading: const Icon(Icons.drag_handle),
                title: Text(_materialTitle(item.recipeId)),
                subtitle: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Безкоштовний перегляд'),
                  value: item.isPreview,
                  onChanged: (value) =>
                      setState(() => item.isPreview = value ?? false),
                ),
                trailing: IconButton(
                  tooltip: 'Видалити з колекції',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() => _items.removeAt(index)),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _CollectionMaterial {
  _CollectionMaterial({required this.recipeId, this.isPreview = false});

  final String recipeId;
  bool isPreview;
}
