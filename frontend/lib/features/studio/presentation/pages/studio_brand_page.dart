import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/branding/brand_assets.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/widgets/design_system.dart';
import '../../studio_brand_draft_service.dart';

final studioBrandDraftServiceProvider = Provider<StudioBrandDraftService>(
    (ref) => StudioBrandDraftService(ref.watch(apiClientProvider)));

class StudioBrandPage extends ConsumerStatefulWidget {
  const StudioBrandPage({super.key});

  @override
  ConsumerState<StudioBrandPage> createState() => _StudioBrandPageState();
}

class _StudioBrandPageState extends ConsumerState<StudioBrandPage> {
  StudioBrandDraft? _draft;
  Object? _error;
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  late final TextEditingController _name = TextEditingController();
  late final TextEditingController _creator = TextEditingController();
  late final TextEditingController _accent = TextEditingController();
  late final TextEditingController _greeting = TextEditingController();
  late final TextEditingController _login = TextEditingController();
  late final TextEditingController _paywall = TextEditingController();
  late final TextEditingController _course = TextEditingController();
  late final TextEditingController _tag = TextEditingController();
  String _font = 'serif';
  int _preview = 0;
  bool _uploadingAsset = false;
  String? _avatarUrl;
  List<BrandHeroPhoto> _photos = [];

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
      final draft = await ref.read(studioBrandDraftServiceProvider).load();
      _setDraft(draft);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  void _setDraft(StudioBrandDraft draft) {
    final brand = draft.config.brand;
    _draft = draft;
    _name.text = brand.name;
    _creator.text = brand.creatorName;
    _accent.text = brand.accent;
    _greeting.text = brand.voice.greeting;
    _login.text = brand.voice.loginTitle;
    _paywall.text = brand.voice.paywallTitle;
    _course.text = brand.voice.courseName ?? '';
    _tag.text = brand.courseTag ?? '';
    _font = brand.font;
    _avatarUrl = brand.avatar;
    _photos = List.of(brand.heroPhotos);
    _dirty = false;
    if (mounted) setState(() => _loading = false);
  }

  BrandConfig? get _previewConfig {
    final current = _draft?.config;
    if (current == null) return null;
    final json = current.toJson();
    final brand = Map<String, dynamic>.from(json['brand'] as Map);
    final voice = Map<String, dynamic>.from(brand['voice'] as Map);
    brand
      ..['name'] = _name.text
      ..['creatorName'] = _creator.text
      ..['accent'] = _accent.text
      ..['font'] = _font;
    brand['avatar'] = _avatarUrl;
    brand['heroPhotos'] = _photos.map((photo) => photo.toJson()).toList();
    voice
      ..['greeting'] = _greeting.text
      ..['loginTitle'] = _login.text
      ..['paywallTitle'] = _paywall.text;
    final course = _course.text.trim(), tag = _tag.text.trim();
    if (course.isEmpty && tag.isEmpty) {
      voice.remove('courseName');
      brand.remove('courseTag');
    } else {
      voice['courseName'] = course;
      brand['courseTag'] = tag;
    }
    brand['voice'] = voice;
    json['brand'] = brand;
    try {
      return BrandConfig.fromJson(json);
    } on FormatException {
      return current;
    }
  }

  Future<void> _save() async {
    final config = _previewConfig;
    final draft = _draft;
    if (config == null || draft == null) return;
    setState(() => _saving = true);
    try {
      _setDraft(await ref
          .read(studioBrandDraftServiceProvider)
          .save(StudioBrandDraft(config: config, version: draft.version)));
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
      if (error.type == ApiErrorType.conflict) _load();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _changed() => setState(() => _dirty = true);

  Future<void> _uploadAsset({required bool avatar}) async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true);
    if (picked == null || picked.files.isEmpty) return;
    setState(() => _uploadingAsset = true);
    try {
      final asset = await ref.read(studioBrandDraftServiceProvider).upload(
          picked.files.single,
          altText: 'Фото бренду ${_name.text.trim()}');
      if (!mounted) return;
      setState(() {
        if (avatar) {
          _avatarUrl = asset.url;
        } else {
          _photos = [
            ..._photos,
            BrandHeroPhoto(url: asset.url, roles: const {'home'})
          ];
        }
        _dirty = true;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _uploadingAsset = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _creator,
      _accent,
      _greeting,
      _login,
      _paywall,
      _course,
      _tag
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error is ApiError &&
        (_error as ApiError).type == ApiErrorType.forbidden) {
      return const Scaffold(
          body: Center(
              child: Text('Creator Studio доступна лише внутрішній команді.')));
    }
    if (_draft == null) {
      return Scaffold(
          body: Center(child: AppButton(label: 'Повторити', onPressed: _load)));
    }
    final preview = _previewConfig!;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (_, __) {},
      child: Scaffold(
        appBar: AppBar(title: const Text('Creator Studio · Бренд'), actions: [
          if (_dirty)
            const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Center(child: Text('Незбережені зміни'))),
          Padding(
              padding: const EdgeInsets.only(right: 12),
              child: AppButton(
                  label: 'Зберегти чернетку',
                  icon: Icons.save_outlined,
                  isLoading: _saving,
                  onPressed: _saving ? null : _save)),
        ]),
        body: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: constraints.maxWidth >= 900
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                      Expanded(child: _editor()),
                                      const SizedBox(width: 24),
                                      SizedBox(
                                          width: 360, child: _previews(preview))
                                    ])
                              : Column(children: [
                                  _editor(),
                                  const SizedBox(height: 24),
                                  _previews(preview)
                                ]))),
                )),
      ),
    );
  }

  Widget _editor() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Бренд застосунку',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        const Text(
            'Зміни зберігаються як чернетка. Публікація доступна в наступному етапі.'),
        const SizedBox(height: 16),
        _section('1 · Ідентичність',
            [_field(_name, 'Назва бренду'), _field(_creator, 'Ім’я автора')]),
        _section('2 · Колір і шрифт', [
          _field(_accent, 'Accent · #RRGGBB'),
          DropdownButtonFormField<String>(
              value: _font,
              decoration: const InputDecoration(labelText: 'Шрифт'),
              items: const [
                DropdownMenuItem(value: 'serif', child: Text('Serif')),
                DropdownMenuItem(value: 'grotesque', child: Text('Grotesque')),
                DropdownMenuItem(value: 'humanist', child: Text('Humanist'))
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _font = value;
                    _dirty = true;
                  });
                }
              })
        ]),
        _section('3 · Голос бренду · 4 рядки', [
          _field(_greeting, 'Привітання Home', 24),
          _field(_login, 'Заголовок логіна', 28),
          _field(_paywall, 'Заголовок пейвола', 28),
          _field(_course, 'Назва колекції · optional', 36),
          _field(_tag, 'Course tag · optional')
        ]),
        _section('4 · Фото бренду', [
          const Text(
              'JPG, PNG або WebP до 12 MB. Сервер перевіряє, стискає і прив’язує файл до цього tenant.'),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
                onPressed:
                    _uploadingAsset ? null : () => _uploadAsset(avatar: true),
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Завантажити avatar')),
            OutlinedButton.icon(
                onPressed:
                    _uploadingAsset ? null : () => _uploadAsset(avatar: false),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(_uploadingAsset ? 'Обробка…' : 'Додати hero')),
          ]),
          ..._photos
              .asMap()
              .entries
              .map((entry) => _photoEditor(entry.key, entry.value)),
        ]),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error.toString(),
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
      ]);

  Widget _section(String title, List<Widget> children) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children.map((child) => Padding(
                padding: const EdgeInsets.only(bottom: 12), child: child))
          ])));
  Widget _field(TextEditingController controller, String label, [int? max]) =>
      AppTextField(
          controller: controller,
          label: label,
          onChanged: (_) => _changed(),
          maxLines: 1,
          validator: max == null
              ? null
              : (value) =>
                  (value ?? '').length > max ? 'Максимум $max символів' : null);

  Widget _photoEditor(int index, BrandHeroPhoto photo) => Card(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        SizedBox(
            height: 120,
            width: double.infinity,
            child: Image.network(photo.url,
                fit: BoxFit.cover,
                alignment:
                    Alignment(photo.focalX * 2 - 1, photo.focalY * 2 - 1))),
        Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: [
              Wrap(
                  spacing: 6,
                  children: ['home', 'login', 'paywall', 'collection']
                      .map((role) => FilterChip(
                          label: Text(role),
                          selected: photo.roles.contains(role),
                          onSelected: (selected) => setState(() {
                                final roles = Set<String>.from(photo.roles);
                                selected ? roles.add(role) : roles.remove(role);
                                if (roles.isNotEmpty) {
                                  _photos[index] = BrandHeroPhoto(
                                      url: photo.url,
                                      roles: roles,
                                      focalX: photo.focalX,
                                      focalY: photo.focalY);
                                }
                                _dirty = true;
                              })))
                      .toList()),
              Row(children: [
                const Text('Фокус'),
                Expanded(
                    child: Slider(
                        value: photo.focalX,
                        onChanged: (value) => setState(() {
                              _photos[index] = BrandHeroPhoto(
                                  url: photo.url,
                                  roles: photo.roles,
                                  focalX: value,
                                  focalY: photo.focalY);
                              _dirty = true;
                            }))),
                IconButton(
                    tooltip: 'Видалити з чернетки',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                          _photos.removeAt(index);
                          _dirty = true;
                        }))
              ]),
            ])),
      ]));

  Widget _previews(BrandConfig config) => Theme(
      data: AppThemeV2.light(config),
      child: Builder(
          builder: (context) =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Живе прев’ю',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Home')),
                      ButtonSegment(value: 1, label: Text('Логін')),
                      ButtonSegment(value: 2, label: Text('Пейвол'))
                    ],
                    selected: {
                      _preview
                    },
                    onSelectionChanged: (v) =>
                        setState(() => _preview = v.first)),
                const SizedBox(height: 12),
                _StudioConsumerPreview(brand: config.brand, tab: _preview)
              ])));
}

class _StudioConsumerPreview extends StatelessWidget {
  const _StudioConsumerPreview({required this.brand, required this.tab});
  final BrandDetails brand;
  final int tab;
  @override
  Widget build(BuildContext context) => AspectRatio(
      aspectRatio: .66,
      child: Card(
          clipBehavior: Clip.antiAlias,
          child: switch (tab) {
            0 =>
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                    padding: const EdgeInsets.all(14),
                    child: BrandHeader(brand: brand)),
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text(brand.voice.greeting,
                        style: Theme.of(context).textTheme.headlineSmall)),
                const Spacer(),
                Padding(
                    padding: const EdgeInsets.all(14),
                    child: AppButton(
                        label: 'Сканувати інгредієнти',
                        icon: Icons.photo_camera_outlined,
                        expand: true,
                        onPressed: () {}))
              ]),
            1 => DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFF16130F)),
                child: Column(children: [
                  Expanded(child: BrandHero(brand: brand, role: 'login')),
                  Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(children: [
                        Text(brand.voice.loginTitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: Colors.white)),
                        const SizedBox(height: 12),
                        const TextField(
                            decoration: InputDecoration(labelText: 'Email')),
                        const SizedBox(height: 8),
                        AppButton(
                            label: 'Увійти', expand: true, onPressed: () {})
                      ]))
                ])),
            _ => DecoratedBox(
                decoration: const BoxDecoration(color: Color(0xFF16130F)),
                child: Column(children: [
                  SizedBox(
                      height: 120,
                      child: BrandHero(brand: brand, role: 'paywall')),
                  Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(brand.voice.paywallTitle,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(color: Colors.white)),
                            const SizedBox(height: 12),
                            Text('Premium-колекції та рецепти',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(.8))),
                            const SizedBox(height: 16),
                            AppButton(
                                label: 'Оформити підписку',
                                expand: true,
                                onPressed: () {})
                          ]))
                ])),
          }));
}
