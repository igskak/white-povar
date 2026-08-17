import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/tokens/app_tokens.dart';
import '../../../../core/api/api_error.dart';
import '../../../../core/branding/brand_assets.dart';
import '../../../../core/branding/brand_config.dart';
import '../../../../core/branding/brand_providers.dart';
import '../../../../core/widgets/design_system.dart';
import '../../studio_asset_precheck.dart';
import '../../studio_brand_draft_service.dart';
import '../../studio_brand_validation.dart';
import '../widgets/studio_preview.dart';

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
  StudioPreviewViewport _previewViewport = StudioPreviewViewport.phone;
  bool _uploadingAsset = false;
  bool _releasing = false;
  bool _publishing = false;

  /// What the last publish did, in the author's words. Cleared by the next edit.
  String? _publishState;
  DateTime? _savedAt;
  Timer? _autosave;

  /// Long enough that typing a sentence or dragging a crop handle is one save,
  /// short enough that closing the tab rarely loses anything.
  static const Duration _autosaveDelay = Duration(seconds: 3);
  StudioReleaseStatus? _releaseStatus;
  String? _avatarUrl;
  BrandCrop _avatarCrop = const BrandCrop();
  List<BrandHeroPhoto> _photos = [];

  /// Upload-time facts the published config does not carry (13m frame states).
  /// Keyed by asset URL and deliberately not persisted.
  final Map<String, String> _photoMeta = {};

  /// Frame sizes, so a role can be refused with numbers rather than a shrug.
  /// Filled from the tenant's assets on load and from each upload.
  final Map<String, StudioImageSize> _photoSize = {};
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
      await _loadFrameSizes();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  /// Sizes for frames this session did not upload. Best effort: a frame of
  /// unknown size keeps every role, and the server still validates the publish.
  Future<void> _loadFrameSizes() async {
    try {
      final assets = await ref.read(studioBrandDraftServiceProvider).assets();
      if (!mounted) return;
      setState(() {
        for (final asset in assets) {
          final width = asset.width, height = asset.height;
          if (width == null || height == null) continue;
          _photoSize[asset.url] = StudioImageSize(width, height);
          _photoMeta.putIfAbsent(asset.url, () => '$width×$height');
        }
      });
    } catch (_) {
      // Frame sizes are a courtesy; the editor works without them.
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
    _avatarCrop = brand.avatarCrop;
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
    brand['avatarCrop'] = _avatarCrop.toJson();
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

  /// Saves the draft. Returns false when the change did not reach the server,
  /// so the caller does not go on to publish a draft that is still stale.
  ///
  /// Unlike [_setDraft] this leaves the editors alone: an autosave that landed
  /// mid-sentence used to rewrite every controller and send the caret to the
  /// end of the field.
  Future<bool> _save() async {
    _autosave?.cancel();
    final config = _previewConfig;
    final draft = _draft;
    if (config == null || draft == null) return false;
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(studioBrandDraftServiceProvider)
          .save(StudioBrandDraft(config: config, version: draft.version));
      if (mounted) {
        setState(() {
          _draft = saved;
          _dirty = false;
          _error = null;
          _savedAt = DateTime.now();
        });
      }
      return true;
    } on ApiError catch (error) {
      if (!mounted) return false;
      setState(() => _error = error);
      if (error.type == ApiErrorType.conflict) _load();
      return false;
    } catch (error) {
      if (mounted) setState(() => _error = error);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Saves the draft and makes it the configuration users get, in one step.
  ///
  /// The two-button dance — save the draft, then publish it — was the single
  /// most confusing thing in Studio: publishing a draft you had not saved
  /// republished the previous one and looked like nothing happened at all.
  Future<void> _publish() async {
    if (_publishing) return;
    setState(() {
      _publishing = true;
      _publishState = null;
    });
    try {
      if (_dirty && !await _save()) return;
      final service = ref.read(studioBrandDraftServiceProvider);
      final result = await service.publish();
      final status = await service.releaseStatus();
      // Publishing is only half the job: the session the author is looking at
      // still renders the configuration it started with. Re-read it here so
      // "опубліковано" and "видно на екрані" are the same moment.
      final applied = await _refreshRuntimeBrand();
      if (!mounted) return;
      setState(() {
        _releaseStatus = status;
        _publishState = applied
            ? 'Опубліковано · версія ${result.version}. Застосунок уже показує ці зміни.'
            : 'Опубліковано · версія ${result.version}. Користувачі побачать їх, '
                'щойно застосунок зв’яжеться з сервером.';
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.type == ApiErrorType.forbidden ? null : error;
        _publishState = error.type == ApiErrorType.forbidden
            ? 'Чернетку збережено. Публікація доступна лише Studio admin — '
                'попросіть адміністратора натиснути «Опублікувати зміни».'
            : null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  /// Re-reads published configuration into the running session. False when the
  /// app was not started through `bootstrap()` (tests, previews) or the API did
  /// not answer — publishing itself still succeeded either way.
  Future<bool> _refreshRuntimeBrand() async {
    try {
      final controller = ref.read(tenantBrandControllerProvider.notifier);
      return await controller.refresh() != null;
    } catch (_) {
      return false;
    }
  }

  void _changed() {
    setState(() {
      _dirty = true;
      _publishState = null;
    });
    // Crop handles and colour fields emit a change per frame of a drag, so the
    // timer restarts until the author actually pauses.
    _autosave?.cancel();
    _autosave = Timer(_autosaveDelay, () {
      if (mounted && _dirty && !_saving && !_publishing) _save();
    });
  }

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
    double? zoom,
  }) =>
      setState(() {
        final photo = _photos[index];
        _photos[index] = BrandHeroPhoto(
          url: photo.url,
          roles: roles ?? photo.roles,
          focalX: (focalX ?? photo.focalX).clamp(0.0, 1.0),
          focalY: (focalY ?? photo.focalY).clamp(0.0, 1.0),
          zoom: (zoom ?? photo.zoom).clamp(1.0, 3.0),
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

  /// A refusal the author cannot miss: it stays in the photo section next to
  /// the buttons, and passes once through the snackbar so it is seen even when
  /// the section has scrolled away under a tall crop editor.
  void _rejectAsset(String message) {
    if (!mounted) return;
    setState(() => _rejectedPhoto = message);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 8),
      backgroundColor: Theme.of(context).colorScheme.error,
    ));
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
      // 13d master rules, checked before the upload rather than after it: the
      // frame that fails them is named here instead of dying silently between
      // a finished progress label and an unchanged list.
      final bytes = file.bytes;
      final size = bytes == null ? null : await probeImageSize(bytes);
      final rejection = assetRejection(
            fileName: file.name,
            extension: file.extension,
            sizeBytes: file.size,
            bytes: bytes,
            size: size,
          ) ??
          (avatar
              ? null
              : heroFrameRejection(fileName: file.name, size: size!));
      if (rejection != null) {
        _rejectAsset(rejection);
        return;
      }
      final asset = await ref
          .read(studioBrandDraftServiceProvider)
          .upload(file, altText: 'Фото бренду ${_name.text.trim()}');
      if (!mounted) return;
      final width = asset.width, height = asset.height;
      // The server re-decodes the file and may see a size the local probe did
      // not (EXIF rotation, a downscale at finalize). It wins.
      if (!avatar && width != null && height != null) {
        final serverRejection = heroFrameRejection(
            fileName: file.name, size: StudioImageSize(width, height));
        if (serverRejection != null) {
          _rejectAsset(serverRejection);
          return;
        }
      }
      // Frames are keyed by URL, so the same asset cannot appear twice — say so
      // rather than letting the list quietly stay as it was.
      if (!avatar && _photos.any((photo) => photo.url == asset.url)) {
        _rejectAsset('«${file.name}» не додано: цей кадр уже є в списку.');
        return;
      }
      setState(() {
        if (avatar) {
          _avatarUrl = asset.url;
          _avatarCrop = const BrandCrop();
        } else {
          if (width != null && height != null) {
            _photoMeta[asset.url] =
                '$width×$height · ${(file.size / 1024).round()} КБ';
            _photoSize[asset.url] = StudioImageSize(width, height);
          }
          _photos = [
            ..._photos,
            BrandHeroPhoto(url: asset.url, roles: const {'home'})
          ];
        }
        _dirty = true;
      });
    } on ApiError catch (error) {
      _rejectAsset('«${file.name}» не додано: ${error.message}'
          '${error.statusCode == null ? '' : ' (${error.statusCode})'}');
    } catch (error) {
      _rejectAsset('«${file.name}» не додано: '
          '${error is FormatException ? error.message : error}');
    } finally {
      if (mounted) setState(() => _uploadingAsset = false);
    }
  }

  @override
  void dispose() {
    _autosave?.cancel();
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
              Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(child: Text(_saveState))),
              Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: AppButton(
                      label: 'Опублікувати зміни',
                      icon: Icons.publish_outlined,
                      isLoading: _publishing,
                      // One action, not two: it saves whatever is unsaved and
                      // then makes it the configuration users get.
                      onPressed: _publishing || !_checks.canPublish
                          ? null
                          : _publish)),
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

  /// The saving half of the story, kept next to the publish button so the
  /// author never has to wonder whether an edit is safe.
  String get _saveState {
    if (_saving) return 'Зберігаємо…';
    if (_dirty) return 'Чернетка · зміни ще не збережені';
    if (_savedAt != null) return 'Чернетка збережена';
    return '';
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
            _field(_course, 'Назва колекції · необов’язково', kCourseNameLimit),
            _field(_tag, 'Тег колекції · необов’язково')
          ],
          status: checks.voice,
          summary: _course.text.trim().isEmpty
              ? 'курс не опубліковано — курс-картка прихована'
              : 'курс «${_course.text.trim()}»'),
      _section(
          '4 · Фото бренду',
          [
            const Text(
                'JPEG ≥ $kMinHeroPhotoWidth×$kMinHeroPhotoHeight, до 600 КБ після стиснення. '
                'Людина або процес у кадрі, без тексту й логотипів, темніший нижній край. '
                'Home, колекції та пейвол — широкі банери; роль login на широкому '
                'екрані вертикальна, тож для неї кадр має бути ще й від '
                '$kMinLoginPhotoHeight px заввишки. Аватар приймається меншим.'),
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
            // Directly under the buttons: the crop editor below is tall enough
            // to push anything after it off the screen the author is looking at.
            if (_rejectedPhoto != null)
              _photoNotice(
                  icon: Icons.error_outline,
                  message: _rejectedPhoto!,
                  colour: context.semantic.error),
            if (_avatarUrl != null && _isRemoteAsset(_avatarUrl!))
              _avatarCropEditor(),
            _photoCounter(),
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
            child: Text(
                _error is ApiError
                    ? (_error as ApiError).message
                    : _error.toString(),
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
    final published = status?.configVersion;
    return _section('Публікація', [
      Text(
        published == null
            ? 'Користувачі поки не бачать жодних змін: нічого не опубліковано.'
            : 'Користувачі бачать версію $published.',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 4),
      Text(canPublish
          // 13m: publishing stays closed until every required section is green.
          // The server refuses an invalid config anyway; blocking the button
          // turns a failed request into a visible checklist.
          ? 'Кнопка «Опублікувати зміни» вгорі сторінки зберігає чернетку і '
              'одразу віддає її користувачам. Фото, тексти й кольори більше '
              'нічого не потребують.'
          : 'Спочатку заповніть секції, позначені знаком уваги вище: '
              'публікація вимагає всіх 7 обов’язкових полів.'),
      if (_publishState != null) ...[
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.check_circle_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(_publishState!)),
        ]),
      ],
      const SizedBox(height: 12),
      _teamPanel(status),
    ]);
  }

  /// Everything that is not "show my change to readers": store builds, site
  /// deploys, rollback. Folded away because a chef needs none of it, and its
  /// presence beside the publish button is what made the page read as a
  /// four-step process.
  Widget _teamPanel(StudioReleaseStatus? status) {
    String label(StudioRelease? release, String fallback) =>
        release == null ? fallback : release.status;
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: const Text('Для команди · збірки та відкат'),
      subtitle: const Text(
          'Не потрібно для фото, текстів і кольорів — вони вже опубліковані.'),
      children: [
        Text('Оновлення сайту: ${label(status?.web, 'не запитано')}'),
        Text(
            'Оновлення мобільних застосунків: ${label(status?.mobile, 'не запитано')}'),
        Text(
            'Відправлення у магазини: ${status?.store?.storeStatus ?? 'не подано'}'),
        const Text(
            'Запит на оновлення лише ставить завдання команді; він не означає, що сайт або застосунок уже оновлено.'),
        const Divider(),
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
                    await s.requestRelease(
                        kind: 'mobile_build', platform: 'ios');
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
      ],
    );
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

  Widget _avatarCropEditor() {
    final crop = _avatarCrop;
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.xs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Кадрування avatar',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: SizedBox.square(
              dimension: 280,
              child: LayoutBuilder(builder: (context, constraints) {
                void place(Offset local) => setState(() {
                      _avatarCrop = BrandCrop(
                        focalX: (local.dx / constraints.maxWidth)
                            .clamp(_cropMin(crop.zoom), _cropMax(crop.zoom)),
                        focalY: (local.dy / constraints.maxHeight)
                            .clamp(_cropMin(crop.zoom), _cropMax(crop.zoom)),
                        zoom: crop.zoom,
                      );
                      _dirty = true;
                    });
                return GestureDetector(
                  key: const ValueKey('studio-avatar-crop-picker'),
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => place(details.localPosition),
                  onPanStart: (details) => place(details.localPosition),
                  onPanUpdate: (details) => place(details.localPosition),
                  child: ClipRRect(
                    borderRadius: AppRadius.md,
                    child: Stack(fit: StackFit.expand, children: [
                      _avatarCroppedImage(
                        _avatarUrl!,
                        crop: crop,
                      ),
                      CustomPaint(painter: _DashedCirclePainter()),
                    ]),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Перетягніть фото під пунктирним колом. Усередині кола — точне прев’ю аватара.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          _zoomSlider(
            value: crop.zoom,
            onChanged: (zoom) => setState(() {
              _avatarCrop = BrandCrop(
                focalX: crop.focalX.clamp(_cropMin(zoom), _cropMax(zoom)),
                focalY: crop.focalY.clamp(_cropMin(zoom), _cropMax(zoom)),
                zoom: zoom,
              );
              _dirty = true;
            }),
          ),
        ]),
      ),
    );
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
          _zoomSlider(
            value: photo.zoom,
            onChanged: (zoom) => _updatePhoto(index, zoom: zoom),
          ),
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
                        final size = _photoSize[photo.url];
                        // Only the desktop login asks a frame for more than the
                        // upload minimum, so the check lives on the role.
                        final refusal = !selected || size == null
                            ? null
                            : heroRoleRejection(role: role, size: size);
                        if (refusal != null) {
                          _rejectAsset(refusal);
                          return;
                        }
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
  Widget _focalPicker(int index, BrandHeroPhoto photo) => _ContainedFocalPicker(
        key: ValueKey('studio-focal-picker-$index'),
        url: photo.url,
        focal: Offset(photo.focalX, photo.focalY),
        semanticsLabel: 'Точка фокуса кадру ${index + 1}',
        onChanged: (focal) => _updatePhoto(
          index,
          focalX: focal.dx,
          focalY: focal.dy,
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

  Widget _croppedImage(
    String url, {
    required Alignment alignment,
    required double zoom,
  }) =>
      ClipRect(
        child: Transform.scale(
          scale: zoom,
          alignment: alignment,
          child: _frameImage(url, fit: BoxFit.cover, alignment: alignment),
        ),
      );

  Widget _avatarCroppedImage(String url, {required BrandCrop crop}) =>
      LayoutBuilder(builder: (context, constraints) {
        final size = constraints.biggest;
        return ClipRect(
          child: Transform(
            transform: Matrix4.identity()
              ..translate(size.width / 2, size.height / 2)
              ..scale(crop.zoom, crop.zoom, 1)
              ..translate(
                -crop.focalX * size.width,
                -crop.focalY * size.height,
              ),
            child: _frameImage(url, fit: BoxFit.cover),
          ),
        );
      });

  Widget _zoomSlider({
    required double value,
    required ValueChanged<double> onChanged,
  }) =>
      Row(children: [
        const Icon(Icons.zoom_out, size: 18),
        Expanded(
          child: Slider(
            value: value,
            min: 1,
            max: 3,
            divisions: 20,
            label: '${value.toStringAsFixed(1)}×',
            onChanged: onChanged,
          ),
        ),
        const Icon(Icons.zoom_in, size: 18),
        SizedBox(
          width: 42,
          child: Text('${value.toStringAsFixed(1)}×',
              textAlign: TextAlign.end, style: context.semantic.dataLabel),
        ),
      ]);

  /// The four crops derived from one master, all centred on focal.
  ///
  /// These ratios intentionally mirror the real Studio scenes. The old 390/300
  /// and 390/280 placeholders were much taller than the live slots, which made
  /// the thumbnails promise a crop the app could not show — and a banner shown
  /// only at its phone shape made the same promise for desktop, where the
  /// column is wide enough to cut the photo to a band.
  Widget _focalCrops(BrandHeroPhoto photo) => SizedBox(
        width: 92,
        child: Column(children: [
          _crop(photo,
              slot: 'login',
              label: 'Логін',
              aspectRatio: BrandMediaAspectRatio.login),
          _crop(photo,
              slot: 'paywall',
              label: 'Пейвол',
              aspectRatio: BrandMediaAspectRatio.paywall),
          _crop(photo,
              slot: 'banner',
              label: 'Банер',
              aspectRatio: BrandMediaAspectRatio.banner,
              borderRadius: AppRadius.md),
          _crop(photo,
              slot: 'banner-desktop',
              label: 'Десктоп',
              aspectRatio: BrandMediaAspectRatio.bannerOnDesktop(),
              borderRadius: AppRadius.md),
        ]),
      );

  Widget _crop(
    BrandHeroPhoto photo, {
    required String slot,
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
              key: ValueKey('studio-crop-$slot'),
              aspectRatio: aspectRatio,
              child: _croppedImage(
                photo.url,
                alignment:
                    Alignment(photo.focalX * 2 - 1, photo.focalY * 2 - 1),
                zoom: photo.zoom,
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

  Widget _photoNotice(
          {required IconData icon, required String message, Color? colour}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 18, color: colour ?? context.semantic.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
                child: Text(message,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colour))),
          ],
        ),
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
        // Home is laid out twice by the app, so the editor lets you look at
        // both. Login and the paywall have no shared desktop composition yet,
        // and offering the choice there would only promise one.
        if (StudioBrandPreview.supportsViewportChoice(_preview)) ...[
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<StudioPreviewViewport>(
              segments: [
                for (final viewport in StudioPreviewViewport.values)
                  ButtonSegment(value: viewport, label: Text(viewport.label)),
              ],
              selected: {
                _previewViewport
              },
              onSelectionChanged: (value) =>
                  setState(() => _previewViewport = value.first)),
        ],
        const SizedBox(height: AppSpacing.sm),
        StudioBrandPreview(
            config: config, tab: _preview, viewport: _previewViewport),
        const SizedBox(height: AppSpacing.xs),
        Text(_previewCaption(), style: Theme.of(context).textTheme.bodySmall),
      ]);

  String _previewCaption() {
    const shared = 'Рендер тими самими віджетами, що й застосунок.';
    if (_preview == StudioPreviewTab.paywall) {
      return '$shared Ціни — приклад: справжні приходять з App Store і '
          'Google Play.';
    }
    if (StudioBrandPreview.supportsViewportChoice(_preview) &&
        _previewViewport == StudioPreviewViewport.desktop) {
      return '$shared Десктоп — це вікно 1280: бічна панель і верхня смуга '
          'беруть на себе шапку бренду й «Сканувати», а банер отримує ширший '
          'кроп, ніж на телефоні.';
    }
    return shared;
  }
}

bool _isRemoteAsset(String value) =>
    value.startsWith('https://') || value.startsWith('http://');

double _cropMin(double zoom) => .5 / zoom;
double _cropMax(double zoom) => 1 - _cropMin(zoom);

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 12;
    const dash = math.pi / 30;
    const gap = math.pi / 45;
    for (var angle = 0.0; angle < math.pi * 2; angle += dash + gap) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        angle,
        dash,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) => false;
}

class _ContainedFocalPicker extends StatefulWidget {
  const _ContainedFocalPicker({
    super.key,
    required this.url,
    required this.focal,
    required this.semanticsLabel,
    required this.onChanged,
  });

  final String url;
  final Offset focal;
  final String semanticsLabel;
  final ValueChanged<Offset> onChanged;

  @override
  State<_ContainedFocalPicker> createState() => _ContainedFocalPickerState();
}

class _ContainedFocalPickerState extends State<_ContainedFocalPicker> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _sourceSize;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(_ContainedFocalPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _resolveImage();
  }

  void _resolveImage() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _sourceSize = null;
    final stream = NetworkImage(widget.url).resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _sourceSize =
          Size(info.image.width.toDouble(), info.image.height.toDouble()));
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 4 / 3,
        child: LayoutBuilder(builder: (context, constraints) {
          final bounds = Offset.zero & constraints.biggest;
          final imageRect = _containedRect(bounds, _sourceSize);
          void place(Offset local) {
            final point = Offset(
              local.dx.clamp(imageRect.left, imageRect.right),
              local.dy.clamp(imageRect.top, imageRect.bottom),
            );
            widget.onChanged(Offset(
              (point.dx - imageRect.left) / imageRect.width,
              (point.dy - imageRect.top) / imageRect.height,
            ));
          }

          return Semantics(
            label: widget.semanticsLabel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => place(details.localPosition),
              onPanStart: (details) => place(details.localPosition),
              onPanUpdate: (details) => place(details.localPosition),
              child: ClipRRect(
                borderRadius: AppRadius.md,
                child: ColoredBox(
                  color: context.semantic.surfaceStrong,
                  child: Stack(children: [
                    Positioned.fromRect(
                      rect: imageRect,
                      child: Image.network(
                        widget.url,
                        fit: BoxFit.fill,
                        errorBuilder: (context, _, __) => Icon(
                          Icons.broken_image_outlined,
                          color: context.semantic.textSecondary,
                        ),
                      ),
                    ),
                    Positioned(
                      left: imageRect.left +
                          widget.focal.dx * imageRect.width -
                          10,
                      top: imageRect.top +
                          widget.focal.dy * imageRect.height -
                          10,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                          border: Border.all(
                              color: context.semantic.surface, width: 2),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }),
      );
}

Rect _containedRect(Rect bounds, Size? source) {
  if (source == null || source.isEmpty) return bounds;
  final scale = math.min(
    bounds.width / source.width,
    bounds.height / source.height,
  );
  final size = Size(source.width * scale, source.height * scale);
  return Rect.fromCenter(
      center: bounds.center, width: size.width, height: size.height);
}
