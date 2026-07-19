import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/design_system.dart';
import '../../studio_brand_draft_service.dart';

/// Internal inventory intentionally reuses the same card primitive used by
/// consumer surfaces.  It is not a screenshot and makes publication state
/// explicit before an editor opens the consumer detail route for QA.
class StudioContentPage extends ConsumerStatefulWidget {
  const StudioContentPage({super.key});

  @override
  ConsumerState<StudioContentPage> createState() => _StudioContentPageState();
}

class _StudioContentPageState extends ConsumerState<StudioContentPage> {
  List<StudioContentItem> _content = const [];
  List<StudioCollectionItem> _collections = const [];
  Object? _error;
  bool _loading = true;
  String _tab = 'Матеріали';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(studioBrandDraftServiceProvider);
      final result =
          await Future.wait([service.content(), service.collections()]);
      if (mounted) {
        setState(() {
          _content = result[0] as List<StudioContentItem>;
          _collections = result[1] as List<StudioCollectionItem>;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _publish(StudioContentItem item) async {
    await ref.read(studioBrandDraftServiceProvider).publishContent(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: AppIconButton(
            icon: Icons.arrow_back,
            tooltip: 'Повернутися до застосунку',
            onPressed: () => context.go('/profile'),
          ),
          title: const Text('Creator Studio · Контент'),
          actions: [
            AppButton(
              label: 'Бренд',
              icon: Icons.palette_outlined,
              variant: AppButtonVariant.text,
              onPressed: () => context.go('/studio/brand'),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'Матеріали', label: Text('Матеріали')),
                        ButtonSegment(
                            value: 'Колекції', label: Text('Колекції'))
                      ],
                      selected: {
                        _tab
                      },
                      onSelectionChanged: (value) =>
                          setState(() => _tab = value.first)),
                  const SizedBox(height: 16),
                  if (_error != null)
                    Text('Не вдалося оновити Studio: $_error'),
                  if (_tab == 'Матеріали')
                    ..._content.map(_contentCard)
                  else
                    ..._collections.map(_collectionCard),
                  if ((_tab == 'Матеріали' ? _content : _collections).isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                            'Ще немає матеріалів. Створіть чернетку через Studio API.')),
                ]),
              ),
      );

  Widget _contentCard(StudioContentItem item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ContentCard(
          semanticLabel: 'Матеріал ${item.title}',
          child: Row(children: [
            const Icon(Icons.menu_book_outlined),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(item.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(
                      '${item.kind} · ${item.isPremium ? 'premium' : 'free'} · ${item.isPublic ? 'опубліковано' : 'чернетка'}')
                ])),
            if (!item.isPublic)
              AppButton(label: 'Опублікувати', onPressed: () => _publish(item)),
          ]),
        ),
      );

  Widget _collectionCard(StudioCollectionItem item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ContentCard(
            child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.collections_bookmark_outlined),
                title: Text(item.title),
                subtitle:
                    Text('${item.itemCount} матеріалів · ${item.status}'))),
      );
}
