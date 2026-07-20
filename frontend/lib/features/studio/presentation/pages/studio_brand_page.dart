import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/widgets/design_system.dart';
import '../../studio_brand_draft_service.dart';
import '../../studio_brand_validation.dart';
import '../widgets/studio_preview.dart';

/// 13d master frame minimum; the count bounds live in studio_brand_validation.
const int _minPhotoWidth = 1600;
const int _minPhotoHeight = 1200;
const List<String> _photoRoles = ['home', 'login', 'paywall', 'collection'];

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
  late final TextEditingController _rollbackVersion = TextEditingController();
  String _font = 'serif';
  StudioPreviewTab _preview = StudioPreviewTab.home;
  bool _uploadingAsset = false;
  bool _releasing = false;
  StudioReleaseStatus? _releaseStatus;
  String? _avatarUrl;
  List<BrandHeroPhoto> _photos = [];

  /// Upload-time facts the published config does not carry (13m frame states).
  /// Keyed by asset URL and deliberately not persisted.
  final Map<String, String> _photoMeta = {};
  String? _rejectedPhoto;

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
      _releaseStatus =
          await ref.read(studioBrandDraftServiceProvider).releaseStatus();
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

  /// The order of [_photos] is the rotation order the app publishes as-is.
  void _reorderPhotos(int oldIndex, int newIndex) => setState(() {
        // Removing first shifts every later target down by one.
        if (newIndex > oldIndex) newIndex -= 1;
        _photos.insert(newIndex, _photos.removeAt(oldIndex));
        _dirty = true;
      });

  /// Rewrites one frame in place. [BrandHeroPhoto] is immutable and carries no
  /// setters, so an edit re-creates it with the fields that changed.
  void _updatePhoto(
    int index, {
    Set<String>? roles,
    double? focalX,
    double? focalY,
  }) =>
      setState(() {
        final photo = _photos[index];
        _photos[index] = BrandHeroPhoto(
          url: photo.url,
          roles: roles ?? photo.roles,
          focalX: (focalX ?? photo.focalX).clamp(0.0, 1.0),
          focalY: (focalY ?? photo.focalY).clamp(0.0, 1.0),
        );
        _dirty = true;
      });

  Future<void> _release(
      Future<void> Function(StudioBrandDraftService service) action) async {
    setState(() => _releasing = true);
    try {
      final service = ref.read(studioBrandDraftServiceProvider);
      await action(service);
      if (mounted) {
        final status = await service.releaseStatus();
        if (mounted) setState(() => _releaseStatus = status);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
  }

  Future<void> _uploadAsset({required bool avatar}) async {
    final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    setState(() {
      _uploadingAsset = true;
      _rejectedPhoto = null;
    });
    try {
      final asset = await ref
          .read(studioBrandDraftServiceProvider)
          .upload(file, altText: 'Фото бренду ${_name.text.trim()}');
      if (!mounted) return;
      final width = asset.width, height = asset.height;
      // 13d master rules. The server is the authority at publish time; this is
      // the early, local «відхилено» so a too-small frame never reaches a hero.
      if (!avatar &&
          width != null &&
          height != null &&
          (width < _minPhotoWidth || height < _minPhotoHeight)) {
        setState(() => _rejectedPhoto = '${file.name} відхилено: '
            '$width×$height — менше мінімуму '
            '$_minPhotoWidth×$_minPhotoHeight. Завантажте кадр більшої роздільності.');
        return;
      }
      setState(() {
        if (avatar) {
          _avatarUrl = asset.url;
        } else if (_photos.any((photo) => photo.url == asset.url)) {
          // Frames are keyed by URL, so the same asset cannot appear twice.
          return;
        } else {
          if (width != null && height != null) {
            _photoMeta[asset.url] =
                '$width×$height · ${(file.size / 1024).round()} КБ';
          }
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
      _tag,
      _rollbackVersion
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
        appBar: AppBar(
            leading: AppIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Повернутися до застосунку',
              onPressed: () => context.go('/profile'),
            ),
            title: const Text('Creator Studio · Бренд'),
            actions: [
              AppButton(
                label: 'Контент',
                icon: Icons.menu_book_outlined,
                variant: AppButtonVariant.text,
                onPressed: () => context.go('/studio/content'),
              ),
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

  /// Section validity, recomputed from the live controllers on every build so
  /// the markers and the publish gate can never lag behind an edit.
  StudioBrandChecks get _checks => StudioBrandChecks.of(
        name: _name.text,
        creatorName: _creator.text,
        avatar: _avatarUrl,
        accent: _accent.text,
        greeting: _greeting.text,
        loginTitle: _login.text,
        paywallTitle: _paywall.text,
        courseName: _course.text,
        courseTag: _tag.text,
        photoCount: _photos.length,
      );

  Widget _editor() {
    final checks = _checks;
    final contrast = BrandContrast.of(_accent.text);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Бренд застосунку',
          style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 4),
      const Text(
          'Зміни зберігаються як чернетка; публікація та реліз доступні лише Studio admin.'),
      const SizedBox(height: 16),
      _section('1 · Ідентичність',
          [_field(_name, 'Назва бренду'), _field(_creator, 'Ім’я автора')],
          status: checks.identity,
          summary: [
            if (_name.text.trim().isNotEmpty) _name.text.trim(),
            if (_creator.text.trim().isNotEmpty) _creator.text.trim(),
            _avatarUrl == null ? 'аватар відсутній' : 'аватар завантажено',
          ].join(' · ')),
      _section(
        '2 · Колір і шрифт',
        [
          _field(_accent, 'Accent · #RRGGBB'),
          if (contrast != null) _contrastNote(contrast),
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
        ],
        status: checks.colour,
        summary: [
          if (isBrandHex(_accent.text)) _accent.text.trim().toUpperCase(),
          _font,
          if (contrast != null)
            contrast.accentFillAllowed
                ? 'контраст ✓ · CTA = заливка акцентом'
                : 'гейт: CTA = ink у світлій темі',
        ].join(' · '),
      ),
      _section(
          '3 · Голос бренду · 4 рядки',
          [
            _field(_greeting, 'Привітання Home', kGreetingLimit),
            _field(_login, 'Заголовок логіна', kLoginTitleLimit),
            _field(_paywall, 'Заголовок пейвола', kPaywallTitleLimit),
            _field(_course, 'Назва колекції · optional', kCourseNameLimit),
            _field(_tag, 'Course tag · optional')
          ],
          status: checks.voice,
          summary: _course.text.trim().isEmpty
              ? 'курс не опубліковано — курс-картка прихована'
              : 'курс «${_course.text.trim()}»'),
      _section(
          '4 · Фото бренду',
          [
            const Text(
                'JPEG ≥ 1600×1200 (4:3), до 600 КБ після стиснення. Людина або процес у кадрі, '
                'без тексту й логотипів, темніший нижній край.'),
            Wrap(spacing: AppSpacing.xs, children: [
              OutlinedButton.icon(
                  onPressed:
                      _uploadingAsset ? null : () => _uploadAsset(avatar: true),
                  icon: const Icon(Icons.account_circle_outlined),
                  label: const Text('Завантажити avatar')),
              OutlinedButton.icon(
                  onPressed: _uploadingAsset
                      ? null
                      : () => _uploadAsset(avatar: false),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_uploadingAsset ? 'Обробка…' : 'Додати кадр')),
            ]),
            _photoCounter(),
            if (_rejectedPhoto != null)
              _photoNotice(icon: Icons.error_outline, message: _rejectedPhoto!),
            if (_photos.isEmpty)
              _photoNotice(
                  icon: Icons.gradient_outlined,
                  message:
                      'Можна пропустити — логін і обкладинка курсу лишаться на фірмовому градієнті.'),
            if (_photos.isNotEmpty) ...[
              const Text(
                  'Порядок кадрів = ротація в застосунку · перетягніть, щоб змінити.'),
              ReorderableListView.builder(
                key: const ValueKey('studio-hero-photos'),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _photos.length,
                onReorder: _reorderPhotos,
                itemBuilder: (context, index) =>
                    _photoEditor(index, _photos[index]),
              ),
            ],
          ],
          status: checks.photos,
          summary: _photoSummary()),
      _releasePanel(canPublish: checks.canPublish),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error.toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error))),
    ]);
  }

  String _photoSummary() {
    final count = _photos.length;
    if (count == 0) return 'без кадрів — логін лишиться градієнтом';
    if (count < kMinHeroPhotos) {
      return '$count з $kMinHeroPhotos мінімальних · '
          'додайте ще ${kMinHeroPhotos - count} або лишиться градієнт';
    }
    if (count > kMaxHeroPhotos) {
      return '$count кадрів · максимум $kMaxHeroPhotos';
    }
    return '$count з $kMinHeroPhotos–$kMaxHeroPhotos кадрів';
  }

  /// 13b, previewed client-side. The server recomputes the derived palette at
  /// publish, so this states the expected outcome rather than a guarantee.
  Widget _contrastNote(BrandContrast contrast) {
    final semantic = context.semantic;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(contrast.accentFillAllowed ? Icons.check_circle : Icons.info_outline,
          size: 18,
          color:
              contrast.accentFillAllowed ? semantic.success : semantic.warning),
      const SizedBox(width: AppSpacing.xs),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              contrast.accentFillAllowed
                  ? 'Акцент проходить гейт світлої теми — CTA буде заливкою.'
                  : 'Акцент не тримає 3:1 на світлому тлі — CTA стане ink '
                      'із акцентною іконкою.',
              style: Theme.of(context).textTheme.bodySmall),
          Text(
              'на тлі $kLightBackground ${contrast.onLightBackground.toStringAsFixed(1)}:1 · '
              'на ink ${contrast.onInk.toStringAsFixed(1)}:1 · '
              'onAccent = ${contrast.onAccentIsInk ? 'ink' : 'білий'}',
              style: semantic.dataLabel),
          Text('Похідні кольори остаточно рахує сервер при публікації.',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      ),
    ]);
  }

  Widget _releasePanel({required bool canPublish}) {
    final status = _releaseStatus;
    String label(StudioRelease? release, String fallback) =>
        release == null ? fallback : release.status;
    return _section('Публікація та реліз', [
      const Text('Після зміни фото або тексту'),
      const Text('1. Натисніть «Зберегти чернетку» вгорі сторінки.\n'
          '2. Натисніть «Опублікувати зміни» нижче.\n'
          'Для нових фото, текстів і кольорів цього достатньо.'),
      const Divider(),
      Text(
          'Зміни для користувачів: ${status?.configVersion == null ? 'ще не опубліковані' : 'опубліковані · версія ${status!.configVersion}'}'),
      Text('Оновлення сайту: ${label(status?.web, 'не запитано')}'),
      Text(
          'Оновлення мобільних застосунків: ${label(status?.mobile, 'не запитано')}'),
      Text(
          'Відправлення у магазини: ${status?.store?.storeStatus ?? 'не подано'}'),
      const Text(
          'Запит на оновлення лише ставить завдання команді; він не означає, що сайт або застосунок уже оновлено.'),
      const Divider(),
      _releaseAction(
        icon: Icons.publish_outlined,
        title: 'Застосувати зміни для користувачів',
        description: canPublish
            ? 'Публікує збережені фото, тексти, кольори та інші налаштування бренду. Це наступний крок після «Зберегти чернетку».'
            // 13m: publishing stays closed until every required section is
            // green. The server refuses an invalid config anyway; blocking the
            // button here turns a failed request into a visible checklist.
            : 'Спочатку заповніть секції, позначені знаком уваги вище: '
                'публікація вимагає всіх 7 обов’язкових полів.',
        buttonLabel: 'Опублікувати зміни',
        onPressed: _releasing || !canPublish
            ? null
            : () => _release((s) async {
                  await s.publish();
                }),
      ),
      _releaseAction(
        icon: Icons.language_outlined,
        title: 'Оновити сайт',
        description:
            'Потрібно лише коли команда змінила сам сайт або його файли. Для зміни фото й текстів зазвичай не потрібно.',
        buttonLabel: 'Запросити оновлення сайту',
        onPressed: _releasing
            ? null
            : () => _release((s) async {
                  await s.requestRelease(kind: 'web_deploy');
                }),
      ),
      _releaseAction(
        icon: Icons.phone_android_outlined,
        title: 'Зібрати Android-застосунок',
        description:
            'Потрібно, якщо команда змінила функції або вбудовані елементи Android-застосунку. Не потрібно для фото й текстів.',
        buttonLabel: 'Запросити Android-збірку',
        onPressed: _releasing
            ? null
            : () => _release((s) async {
                  await s.requestRelease(
                      kind: 'mobile_build', platform: 'android');
                }),
      ),
      _releaseAction(
        icon: Icons.phone_iphone_outlined,
        title: 'Зібрати iPhone-застосунок',
        description:
            'Потрібно, якщо команда змінила функції або вбудовані елементи iPhone-застосунку. Не потрібно для фото й текстів.',
        buttonLabel: 'Запросити iPhone-збірку',
        onPressed: _releasing
            ? null
            : () => _release((s) async {
                  await s.requestRelease(kind: 'mobile_build', platform: 'ios');
                }),
      ),
      Row(children: [
        SizedBox(
            width: 140,
            child: AppTextField(
                controller: _rollbackVersion, label: 'Версія rollback')),
        const SizedBox(width: 8),
        OutlinedButton(
            onPressed: _releasing
                ? null
                : () {
                    final version = int.tryParse(_rollbackVersion.text);
                    if (version != null) {
                      _release((s) async {
                        await s.rollback(version);
                      });
                    }
                  },
            child: const Text('Відкотити config')),
      ]),
      if (status != null && status.history.isNotEmpty)
        ...status.history.take(5).map((job) => Text(
            '${job.kind} · v${job.configVersion} · ${job.status}${job.storeStatus == 'not_submitted' ? '' : ' · store ${job.storeStatus}'}')),
    ]);
  }

  Widget _releaseAction({
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback? onPressed,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(description),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: onPressed, child: Text(buttonLabel)),
              ])),
        ]),
      );

  /// A collapsible section carrying its own validity (13m): the summary and
  /// the status marker stay visible when the body is folded away.
  Widget _section(
    String title,
    List<Widget> children, {
    String? summary,
    StudioSectionStatus? status,
  }) {
    final semantic = context.semantic;
    final (icon, colour, label) = switch (status) {
      StudioSectionStatus.ok => (
          Icons.check_circle,
          semantic.success,
          'секція заповнена'
        ),
      StudioSectionStatus.warning => (
          Icons.info_outline,
          semantic.warning,
          'секція заповнена частково'
        ),
      StudioSectionStatus.invalid => (
          Icons.priority_high,
          semantic.error,
          'секція потребує уваги'
        ),
      null => (null, null, null),
    };
    return Card(
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        leading: icon == null
            ? null
            : Tooltip(message: label!, child: Icon(icon, color: colour)),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: summary == null
            ? null
            : Text(summary, style: Theme.of(context).textTheme.bodySmall),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children
            .map((child) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: child))
            .toList(),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, [int? max]) {
    final field = AppTextField(
        controller: controller,
        label: label,
        onChanged: (_) => _changed(),
        maxLines: 1,
        validator: max == null
            ? null
            : (value) =>
                (value ?? '').length > max ? 'Максимум $max символів' : null);
    if (max == null) return field;
    // Live counter against the 13a schema limit, next to the validator.
    final length = controller.text.characters.length;
    final semantic = context.semantic;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      field,
      Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: Text('$length/$max',
            style: length > max
                ? semantic.dataLabel.copyWith(color: semantic.error)
                : semantic.dataLabel),
      ),
    ]);
  }

  /// One hero frame: drag handle, focal-point editor and the live 13d crops.
  ///
  /// The key is the asset URL, not the list index — a [ReorderableListView]
  /// child must keep its identity across a reorder, and a key that changed on
  /// every focal update would tear down the drag gesture mid-pan.
  Widget _photoEditor(int index, BrandHeroPhoto photo) {
    final semantic = context.semantic;
    final meta = _photoMeta[photo.url];
    return Card(
      key: ValueKey(photo.url),
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ReorderableDragStartListener(
              index: index,
              child: Tooltip(
                message: 'Перетягніть, щоб змінити порядок ротації',
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  child: Icon(Icons.drag_handle, color: semantic.textSecondary),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text('Кадр ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            if (meta != null) Text(meta, style: semantic.dataLabel),
            IconButton(
                tooltip: 'Видалити з чернетки',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => setState(() {
                      _photos.removeAt(index);
                      _dirty = true;
                    })),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _focalPicker(index, photo)),
            const SizedBox(width: AppSpacing.sm),
            _focalCrops(photo),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Row(children: [
            Expanded(
              child: Text(
                  'Тап по кадру ставить точку фокуса — праворуч живі кропи.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            Text(
                'focal {x: ${photo.focalX.toStringAsFixed(2)}, '
                'y: ${photo.focalY.toStringAsFixed(2)}}',
                style: semantic.dataLabel),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
              spacing: AppSpacing.xs,
              children: _photoRoles
                  .map((role) => AppChip(
                      label: role,
                      selected: photo.roles.contains(role),
                      onSelected: (selected) {
                        final roles = Set<String>.from(photo.roles);
                        selected ? roles.add(role) : roles.remove(role);
                        // A frame with no role would never be rendered.
                        if (roles.isNotEmpty) _updatePhoto(index, roles: roles);
                      }))
                  .toList()),
        ]),
      ),
    );
  }

  /// Tap or drag anywhere on the master frame to place focal {x, y} (13m).
  ///
  /// The box is locked to the 4:3 master ratio required by 13d, so a
  /// conforming upload maps its tap position onto the source image 1:1.
  Widget _focalPicker(int index, BrandHeroPhoto photo) => AspectRatio(
        aspectRatio: 4 / 3,
        child: LayoutBuilder(
          builder: (context, constraints) {
            void place(Offset local) => _updatePhoto(
                  index,
                  focalX: local.dx / constraints.maxWidth,
                  focalY: local.dy / constraints.maxHeight,
                );
            return Semantics(
              label: 'Точка фокуса кадру ${index + 1}',
              child: GestureDetector(
                key: ValueKey('studio-focal-picker-$index'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => place(details.localPosition),
                onPanStart: (details) => place(details.localPosition),
                onPanUpdate: (details) => place(details.localPosition),
                child: ClipRRect(
                  borderRadius: AppRadius.md,
                  child: Stack(fit: StackFit.expand, children: [
                    _frameImage(photo.url, fit: BoxFit.cover),
                    Align(
                      alignment:
                          Alignment(photo.focalX * 2 - 1, photo.focalY * 2 - 1),
                      child: _focalMarker(),
                    ),
                  ]),
                ),
              ),
            );
          },
        ),
      );

  /// A draft frame straight from storage. Loading and failure both resolve to
  /// a neutral surface so the editor never shows a broken-image box.
  Widget _frameImage(String url,
          {required BoxFit fit, Alignment alignment = Alignment.center}) =>
      Image.network(
        url,
        fit: fit,
        alignment: alignment,
        errorBuilder: (context, _, __) => ColoredBox(
          color: context.semantic.surfaceStrong,
          child: Icon(Icons.broken_image_outlined,
              color: context.semantic.textSecondary),
        ),
        frameBuilder: (context, child, frame, wasSynchronous) =>
            wasSynchronous || frame != null
                ? child
                : ColoredBox(color: context.semantic.surfaceStrong),
      );

  Widget _focalMarker() => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primary,
          border: Border.all(color: context.semantic.surface, width: 2),
        ),
      );

  /// The three crops 13d derives from one master, all centred on focal.
  Widget _focalCrops(BrandHeroPhoto photo) => SizedBox(
        width: 92,
        child: Column(children: [
          _crop(photo, label: 'Логін', aspectRatio: 390 / 300),
          _crop(photo, label: 'Пейвол', aspectRatio: 390 / 280),
          _crop(photo,
              label: 'Курс', aspectRatio: 1, borderRadius: AppRadius.md),
        ]),
      );

  Widget _crop(
    BrandHeroPhoto photo, {
    required String label,
    required double aspectRatio,
    BorderRadius borderRadius = AppRadius.sm,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppSpacing.xxs),
          ClipRRect(
            borderRadius: borderRadius,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: _frameImage(
                photo.url,
                fit: BoxFit.cover,
                alignment:
                    Alignment(photo.focalX * 2 - 1, photo.focalY * 2 - 1),
              ),
            ),
          ),
        ]),
      );

  Widget _photoCounter() {
    final count = _photos.length;
    final missing = kMinHeroPhotos - count;
    return Text(
      missing > 0
          ? '$count з $kMinHeroPhotos–$kMaxHeroPhotos кадрів · додайте ще $missing'
          : count > kMaxHeroPhotos
              ? '$count з $kMinHeroPhotos–$kMaxHeroPhotos кадрів · приберіть зайві'
              : '$count з $kMinHeroPhotos–$kMaxHeroPhotos кадрів',
      style: context.semantic.dataLabel,
    );
  }

  Widget _photoNotice({required IconData icon, required String message}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.semantic.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
              child:
                  Text(message, style: Theme.of(context).textTheme.bodySmall)),
        ],
      );

  Widget _previews(BrandConfig config) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Живе прев’ю', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<StudioPreviewTab>(
            segments: const [
              ButtonSegment(value: StudioPreviewTab.home, label: Text('Home')),
              ButtonSegment(
                  value: StudioPreviewTab.login, label: Text('Логін')),
              ButtonSegment(
                  value: StudioPreviewTab.paywall, label: Text('Пейвол'))
            ],
            selected: {
              _preview
            },
            onSelectionChanged: (value) =>
                setState(() => _preview = value.first)),
        const SizedBox(height: AppSpacing.sm),
        StudioBrandPreview(config: config, tab: _preview),
        const SizedBox(height: AppSpacing.xs),
        Text(
            'Рендер тими самими віджетами, що й застосунок. Ціни на пейволі — '
            'приклад: справжні приходять з App Store і Google Play.',
            style: Theme.of(context).textTheme.bodySmall),
      ]);
}
