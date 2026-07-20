import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/features/studio/studio_brand_draft_service.dart';

void main() {
  test(
      'Studio draft retains the complete validated BrandConfig for preview/save',
      () {
    final draft = StudioBrandDraft.fromJson({
      'version': 7,
      'config': {
        'schemaVersion': 1,
        'tenantSlug': 'ohorodnik-oleksandr',
        'locale': 'uk',
        'brand': {
          'name': 'Огороднік Олександр',
          'creatorName': 'Олександр',
          'avatar': 'PENDING:/brands/ohorodnik-oleksandr/avatar-512.png',
          'accent': '#5D7183',
          'font': 'grotesque',
          'voice': {
            'greeting': 'Ой, друзі, ну це щось...',
            'loginTitle': 'Готуйте з Олександром',
            'paywallTitle': 'Колекції Олександра',
            'courseName': 'Майстерня Олександра',
          },
          'courseTag': 'maisternia-oleksandra',
          'heroPhotos': [
            {
              'url': 'https://assets.example/hero.webp',
              'roles': ['login'],
              'focal': {'x': .25, 'y': .75},
            },
          ],
          'logo': null,
          'derived': {
            'accentPressed': '#4B5E70',
            'accentOnDark': '#6B8092',
            'onAccent': '#FFFFFF',
            'lightCtaMode': 'accentFill',
          },
        },
      },
    });

    expect(draft.version, 7);
    expect(draft.config.toJson()['tenantSlug'], 'ohorodnik-oleksandr');
    expect(draft.config.toJson()['brand']['voice']['loginTitle'],
        'Готуйте з Олександром');
    expect(draft.config.brand.heroPhotos.single.focalX, .25);
    expect(draft.config.brand.heroPhotos.single.focalY, .75);
  });

  test('hero frame order and both focal axes survive the publish round trip',
      () {
    // The Studio list order is the rotation order (13m-2); reordering frames
    // and moving a focal point must reach the server exactly as edited.
    const reordered = [
      BrandHeroPhoto(url: 'https://assets.example/b.jpg', roles: {'home'}),
      BrandHeroPhoto(
          url: 'https://assets.example/a.jpg',
          roles: {'login', 'paywall'},
          focalX: .34,
          focalY: .42),
    ];

    final json = reordered.map((photo) => photo.toJson()).toList();
    expect(json.map((photo) => photo['url']),
        ['https://assets.example/b.jpg', 'https://assets.example/a.jpg']);
    // Defaults are 13d's {0.5, 0.4} and are written out, never omitted.
    expect(json.first['focal'], {'x': .5, 'y': .4});
    expect(json.last['focal'], {'x': .34, 'y': .42});

    final parsed = json
        .map((photo) => BrandHeroPhoto.fromJson(photo))
        .toList(growable: false);
    expect(
        parsed.map((photo) => photo.url), reordered.map((photo) => photo.url));
    expect(parsed.last.focalX, .34);
    expect(parsed.last.focalY, .42);
    expect(parsed.last.roles, {'login', 'paywall'});
  });

  test('a focal point outside 0..1 is rejected rather than silently clamped',
      () {
    expect(
      () => BrandHeroPhoto.fromJson({
        'url': 'https://assets.example/a.jpg',
        'roles': ['home'],
        'focal': {'x': 1.4, 'y': .2},
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
