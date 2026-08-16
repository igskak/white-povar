import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/branding/brand_assets.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/branding/brand_providers.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';
import 'package:frontend/core/widgets/design_system.dart';
import 'package:frontend/features/home/presentation/widgets/home_scene.dart';
import 'package:frontend/features/studio/presentation/pages/studio_brand_page.dart';
import 'package:frontend/features/studio/presentation/widgets/studio_preview.dart';
import 'package:frontend/features/studio/studio_brand_draft_service.dart';

void main() {
  // Studio renders draft frames straight from storage; the test serves a 1x1
  // PNG so the focal editor and its crops lay out for real.
  setUpAll(() => HttpOverrides.global = _FakeImageHttpOverrides());
  tearDownAll(() => HttpOverrides.global = null);

  testWidgets('a tap on the frame writes both focalX and focalY (13m)',
      (tester) async {
    await _pumpStudio(tester);

    final picker = find.byKey(const ValueKey('studio-focal-picker-0'));
    expect(picker, findsOneWidget);

    // Image dimensions are not exposed by the fake HTTP decoder, so the
    // loading-state editor maps against the complete 4:3 surface.
    final rect = tester.getRect(picker);
    await tester.tapAt(Offset(
      rect.left + rect.width * .25,
      rect.top + rect.height * .25,
    ));
    await tester.pump();

    final photo = _publishedPhotos(tester).single;
    expect(photo.focalX, closeTo(.25, .02));
    expect(photo.focalY, closeTo(.25, .02));
  });

  testWidgets('focal point stays clamped to 0..1 when dragged past the edge',
      (tester) async {
    await _pumpStudio(tester);

    final rect =
        tester.getRect(find.byKey(const ValueKey('studio-focal-picker-0')));
    final gesture = await tester.startGesture(rect.center);
    await gesture.moveTo(rect.bottomRight + const Offset(200, 200));
    await gesture.up();
    await tester.pump();

    final photo = _publishedPhotos(tester).single;
    expect(photo.focalX, lessThanOrEqualTo(1));
    expect(photo.focalY, lessThanOrEqualTo(1));
    expect(photo.focalX, greaterThan(.9));
    expect(photo.focalY, greaterThan(.9));
  });

  testWidgets('avatar crop picker updates focal point in the live config',
      (tester) async {
    await _pumpStudio(tester);

    final picker = find.byKey(const ValueKey('studio-avatar-crop-picker'));
    expect(picker, findsOneWidget);
    final rect = tester.getRect(picker);
    await tester.tapAt(Offset(
      rect.left + rect.width * .3,
      rect.top + rect.height * .25,
    ));
    await tester.pump();

    final crop = _publishedBrand(tester).avatarCrop;
    expect(crop.focalX, closeTo(.3, .02));
    expect(crop.focalY, closeTo(.25, .02));
  });

  testWidgets('dragging a frame reorders the published rotation',
      (tester) async {
    await _pumpStudio(tester, photos: _threePhotos);

    expect(_publishedPhotos(tester).map((photo) => photo.url), [
      'https://assets.example/a.jpg', 'https://assets.example/b.jpg', //
      'https://assets.example/c.jpg'
    ]);

    final list = tester.widget<ReorderableListView>(
      find.byKey(const ValueKey('studio-hero-photos')),
    );
    // Exercising onReorder directly keeps the assertion on the contract
    // (rotation order) rather than on drag-handle pixel geometry.
    list.onReorder(0, 3);
    await tester.pump();

    expect(_publishedPhotos(tester).map((photo) => photo.url), [
      'https://assets.example/b.jpg', 'https://assets.example/c.jpg', //
      'https://assets.example/a.jpg'
    ]);
  });

  testWidgets('publishing is gated on the required sections being green',
      (tester) async {
    await _pumpStudio(tester);

    expect(_publishButton(tester).onPressed, isNotNull,
        reason: 'the seeded draft has all 7 required fields');

    // Emptying one required field must close the gate, not fail at the server.
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Огороднік Олександр'), '');
    await tester.pump();

    expect(_publishButton(tester).onPressed, isNull);
  });

  testWidgets('publishing carries the unsaved edit with it', (tester) async {
    final service = await _pumpStudio(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Ой, друзі, ну це щось...'),
        'Нове привітання');
    await tester.pump();
    expect(find.text('Чернетка · зміни ще не збережені'), findsOneWidget);

    await tester.tap(find.byWidget(_publishButton(tester)));
    await tester.pump();
    await tester.pump();

    // The old two-step flow published whatever had last been saved, so an
    // unsaved edit silently republished the previous config.
    expect(service.calls, ['load', 'save', 'publish']);
    expect(find.textContaining('Опубліковано · версія'), findsOneWidget);
  });

  testWidgets('an edit saves itself once the author pauses', (tester) async {
    final service = await _pumpStudio(tester);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Ой, друзі, ну це щось...'), 'Хай');
    await tester.pump();
    expect(service.calls, ['load'], reason: 'not while the author is typing');

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();

    expect(service.calls, ['load', 'save']);
    expect(find.text('Чернетка збережена'), findsOneWidget);
  });

  testWidgets('publishing re-reads the config the app is rendering',
      (tester) async {
    final published = _bootstrap('16');
    final brand = TenantBrandController(
      initial: _bootstrap('15'),
      refresher: () async => published,
    );

    await _pumpStudio(tester, brand: brand);
    await tester.tap(find.byWidget(_publishButton(tester)));
    await tester.pump();
    await tester.pump();

    // Without this the author had to reload the page — twice, if the API had
    // to wake up — before seeing what they had just published.
    expect(brand.state.configVersion, '16');
    expect(
        find.textContaining('Застосунок уже показує ці зміни'), findsOneWidget);
  });

  testWidgets('preview falls back to the gradient login without heroPhotos',
      (tester) async {
    await tester.pumpWidget(_previewApp(_config(heroPhotos: const [])));
    await tester.pump();

    // 13d: the brand gradient carries the creator name instead of a photo.
    expect(find.text('Олександр'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview hides the course card when courseName is empty',
      (tester) async {
    await tester.pumpWidget(_previewApp(_config(), tab: StudioPreviewTab.home));
    await tester.pump();
    expect(find.byType(BrandCourseCard), findsOneWidget);

    await tester.pumpWidget(
        _previewApp(_config(withCourse: false), tab: StudioPreviewTab.home));
    await tester.pump();
    expect(find.byType(BrandCourseCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('each preview viewport shows the composition that width renders',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;

    final config = _config(heroPhotos: const [
      BrandHeroPhoto(url: 'https://assets.example/home.jpg', roles: {'home'}),
    ]);

    await tester.pumpWidget(_previewApp(config, tab: StudioPreviewTab.home));
    await tester.pump();

    // The phone keeps the brand header and the capture entry points…
    expect(find.byType(HomeIntro), findsOneWidget);
    expect(find.byType(HomeDesktopSections), findsNothing);
    final phoneBanner = tester.getSize(find.byType(BrandHeroBanner).first);

    await tester.pumpWidget(_previewApp(config,
        tab: StudioPreviewTab.home, viewport: StudioPreviewViewport.desktop));
    await tester.pump();

    // …while the desktop leaves both to the shell and opens on the photo.
    expect(find.byType(HomeDesktopSections), findsOneWidget);
    expect(find.byType(HomeIntro), findsNothing);
    expect(find.text('Від шефа'), findsOneWidget);

    // The point of the second viewport: the published crop is not the phone's.
    // A wide column clamps the banner's height, so its shape is flatter.
    final desktopBanner = tester.getSize(find.byType(BrandHeroBanner).first);
    expect(phoneBanner.aspectRatio, closeTo(BrandMediaAspectRatio.banner, .01));
    expect(desktopBanner.aspectRatio, greaterThan(3));

    // …and the crop thumbnail promises exactly that shape, so a frame kept
    // inside the desktop thumbnail is a frame the page really shows.
    expect(desktopBanner.aspectRatio,
        closeTo(BrandMediaAspectRatio.bannerOnDesktop(), .01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the crop stack covers both banner shapes', (tester) async {
    await _pumpStudio(tester);

    double ratioOf(String slot) => tester
        .widget<AspectRatio>(find.byKey(ValueKey('studio-crop-$slot')))
        .aspectRatio;

    expect(ratioOf('banner'), BrandMediaAspectRatio.banner);
    expect(ratioOf('banner-desktop'), BrandMediaAspectRatio.bannerOnDesktop());
    expect(ratioOf('banner-desktop'), greaterThan(ratioOf('banner')),
        reason: 'the desktop column crops the same photo flatter');
  });

  testWidgets('login has no desktop composition to promise', (tester) async {
    for (final tab in StudioPreviewTab.values) {
      expect(
        StudioBrandPreview.supportsViewportChoice(tab),
        tab == StudioPreviewTab.home,
        reason: '$tab',
      );
    }

    // Asking for it anyway still renders the compact scene rather than a
    // stretched invention of one.
    await tester.pumpWidget(_previewApp(_config(),
        tab: StudioPreviewTab.login, viewport: StudioPreviewViewport.desktop));
    await tester.pump();

    expect(find.text('Готуйте з Олександром'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<_FakeStudioService> _pumpStudio(
  WidgetTester tester, {
  List<BrandHeroPhoto> photos = const [
    BrandHeroPhoto(url: 'https://assets.example/a.jpg', roles: {'login'}),
  ],
  TenantBrandController? brand,
}) async {
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  tester.view.physicalSize = const Size(1280, 2400);
  tester.view.devicePixelRatio = 1;

  final service = _FakeStudioService(photos);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      studioBrandDraftServiceProvider.overrideWithValue(service),
      if (brand != null)
        tenantBrandControllerProvider.overrideWith((ref) => brand),
    ],
    child: const MaterialApp(home: StudioBrandPage()),
  ));
  await tester.pump();
  await tester.pump();
  return service;
}

AppButton _publishButton(WidgetTester tester) =>
    tester.widget<AppButton>(find.byWidgetPredicate((widget) =>
        widget is AppButton && widget.label == 'Опублікувати зміни'));

TenantBootstrap _bootstrap(String version) => TenantBootstrap(
      tenantSlug: 'ohorodnik-oleksandr',
      brandConfig: _config(),
      configVersion: version,
    );

/// The frames exactly as the draft would publish them.
List<BrandHeroPhoto> _publishedPhotos(WidgetTester tester) => tester
    .widget<StudioBrandPreview>(find.byType(StudioBrandPreview))
    .config
    .brand
    .heroPhotos;

BrandDetails _publishedBrand(WidgetTester tester) => tester
    .widget<StudioBrandPreview>(find.byType(StudioBrandPreview))
    .config
    .brand;

Widget _previewApp(
  BrandConfig config, {
  StudioPreviewTab tab = StudioPreviewTab.login,
  StudioPreviewViewport viewport = StudioPreviewViewport.phone,
}) =>
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: StudioBrandPreview(
              config: config,
              tab: tab,
              viewport: viewport,
            ),
          ),
        ),
      ),
    );

class _FakeStudioService extends StudioBrandDraftService {
  _FakeStudioService(this.photos)
      : super(ApiClient(
          baseUrl: 'https://example.invalid',
          tokenProvider: () async => null,
          tenantSlug: 'ohorodnik-oleksandr',
          locale: 'uk',
        ));

  final List<BrandHeroPhoto> photos;

  /// Ordered record of what the page asked the server to do, so a test can
  /// assert that publishing carried the unsaved edit with it.
  final List<String> calls = [];
  int version = 1;
  int publishedVersion = 0;

  @override
  Future<StudioBrandDraft> load() async {
    calls.add('load');
    return StudioBrandDraft(
        config: _config(heroPhotos: photos), version: version);
  }

  @override
  Future<StudioBrandDraft> save(StudioBrandDraft draft) async {
    calls.add('save');
    version = draft.version + 1;
    return StudioBrandDraft(config: draft.config, version: version);
  }

  @override
  Future<StudioPublishResult> publish() async {
    calls.add('publish');
    publishedVersion = version;
    return StudioPublishResult(version: version);
  }

  @override
  Future<StudioReleaseStatus> releaseStatus() async => StudioReleaseStatus(
      configVersion: publishedVersion == 0 ? null : publishedVersion);
}

const _threePhotos = [
  BrandHeroPhoto(url: 'https://assets.example/a.jpg', roles: {'login'}),
  BrandHeroPhoto(url: 'https://assets.example/b.jpg', roles: {'home'}),
  BrandHeroPhoto(url: 'https://assets.example/c.jpg', roles: {'paywall'}),
];

BrandConfig _config({
  List<BrandHeroPhoto> heroPhotos = const [],
  bool withCourse = true,
}) =>
    BrandConfig(
      schemaVersion: 1,
      tenantSlug: 'ohorodnik-oleksandr',
      locale: 'uk',
      brand: BrandDetails(
        name: 'Огороднік Олександр',
        creatorName: 'Олександр',
        avatar: 'https://assets.example/avatar.jpg',
        avatarCrop: const BrandCrop(zoom: 2),
        accent: '#5D7183',
        font: 'grotesque',
        voice: BrandVoice(
          greeting: 'Ой, друзі, ну це щось...',
          loginTitle: 'Готуйте з Олександром',
          paywallTitle: 'Колекції Олександра',
          courseName: withCourse ? 'Майстерня Олександра' : null,
        ),
        derived: const DerivedBrandColors(
          accentPressed: '#4B5E70',
          accentOnDark: '#6B8092',
          onAccent: '#FFFFFF',
          lightCtaMode: 'accentFill',
        ),
        heroPhotos: heroPhotos,
        courseTag: withCourse ? 'maisternia-oleksandra' : null,
      ),
    );

/// A 1x1 transparent PNG served for every image request in this test.
const List<int> _transparentPng = [
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

class _FakeImageHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Duration idleTimeout = const Duration(seconds: 15);
  @override
  String? userAgent;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();

  @override
  void noSuchMethod(Invocation invocation) {}
}

class _FakeHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();

  @override
  void noSuchMethod(Invocation invocation) {}
}

class _FakeHttpClientResponse implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;
  @override
  int get contentLength => _transparentPng.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(Uint8List.fromList(_transparentPng)).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  void noSuchMethod(Invocation invocation) {}
}

class _FakeHttpHeaders implements HttpHeaders {
  @override
  void noSuchMethod(Invocation invocation) {}
}
