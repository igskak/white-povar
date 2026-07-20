import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/studio/studio_brand_validation.dart';

void main() {
  group('13b contrast gates', () {
    test('gold fails the light-theme fill gate and takes ink as onAccent', () {
      // Design 13b, Chef's Table: fill 1.8:1 < 3.0 → CTA = ink.
      final gold = BrandContrast.of('#D9A441')!;
      expect(gold.accentFillAllowed, isFalse);
      expect(gold.onLightBackground, lessThan(3));
      expect(gold.onAccentIsInk, isTrue, reason: 'ink reads on gold at 8.2:1');
    });

    test('green passes the light-theme fill gate and takes white as onAccent',
        () {
      // Design 13b, Зелена миска: fill 3.9:1 ≥ 3.0 → accent fill allowed.
      final green = BrandContrast.of('#3F7D52')!;
      expect(green.accentFillAllowed, isTrue);
      expect(green.onLightBackground, greaterThanOrEqualTo(3));
      expect(green.onAccentIsInk, isFalse);
    });

    test('an unparseable accent yields no gate rather than a wrong one', () {
      expect(BrandContrast.of('D9A441'), isNull);
      expect(BrandContrast.of('#GGGGGG'), isNull);
      expect(contrastRatio('#FFFFFF', 'nope'), isNull);
    });

    test('contrast is symmetric and bounded by black on white', () {
      expect(contrastRatio('#000000', '#FFFFFF'), closeTo(21, .01));
      expect(contrastRatio('#FFFFFF', '#000000'), closeTo(21, .01));
      expect(contrastRatio('#3F7D52', '#3F7D52'), closeTo(1, .001));
    });
  });

  group('13a required-field gate', () {
    test('a complete draft publishes', () {
      expect(_checks().canPublish, isTrue);
    });

    test('each of the 7 required fields blocks publishing on its own', () {
      expect(_checks(name: '').canPublish, isFalse);
      expect(_checks(creatorName: '').canPublish, isFalse);
      expect(_checks(avatar: null).canPublish, isFalse);
      expect(_checks(accent: 'not-a-hex').canPublish, isFalse);
      expect(_checks(greeting: '').canPublish, isFalse);
      expect(_checks(loginTitle: '').canPublish, isFalse);
      expect(_checks(paywallTitle: '').canPublish, isFalse);
    });

    test('a field over its 13a limit is invalid, not merely flagged', () {
      expect(_checks(name: 'x' * (kBrandNameLimit + 1)).identity,
          StudioSectionStatus.invalid);
      expect(_checks(greeting: 'x' * (kGreetingLimit + 1)).voice,
          StudioSectionStatus.invalid);
    });

    test('courseName and courseTag are optional but must travel together', () {
      expect(
          _checks(courseName: '', courseTag: '').voice, StudioSectionStatus.ok);
      expect(_checks(courseName: 'Курс', courseTag: '').voice,
          StudioSectionStatus.invalid);
      expect(_checks(courseName: '', courseTag: 'kurs').voice,
          StudioSectionStatus.invalid);
    });
  });

  group('13d hero frame count', () {
    test('no frames is a supported choice, not an error', () {
      final checks = _checks(photoCount: 0);
      expect(checks.photos, StudioSectionStatus.ok);
      expect(checks.canPublish, isTrue);
    });

    test('one or two frames warns but still publishes as a gradient', () {
      for (final count in [1, 2]) {
        final checks = _checks(photoCount: count);
        expect(checks.photos, StudioSectionStatus.warning);
        expect(checks.canPublish, isTrue, reason: '$count frames');
      }
    });

    test('3..6 frames is the design range', () {
      for (var count = kMinHeroPhotos; count <= kMaxHeroPhotos; count++) {
        expect(_checks(photoCount: count).photos, StudioSectionStatus.ok);
      }
    });

    test('more than six frames blocks publishing', () {
      final checks = _checks(photoCount: kMaxHeroPhotos + 1);
      expect(checks.photos, StudioSectionStatus.invalid);
      expect(checks.canPublish, isFalse);
    });
  });
}

StudioBrandChecks _checks({
  String name = 'Огороднік Олександр',
  String creatorName = 'Олександр',
  String? avatar = 'https://assets.example/avatar.png',
  String accent = '#5D7183',
  String greeting = 'Ой, друзі!',
  String loginTitle = 'Готуйте з Олександром',
  String paywallTitle = 'Колекції Олександра',
  String courseName = 'Майстерня',
  String courseTag = 'maisternia',
  int photoCount = 3,
}) =>
    StudioBrandChecks.of(
      name: name,
      creatorName: creatorName,
      avatar: avatar,
      accent: accent,
      greeting: greeting,
      loginTitle: loginTitle,
      paywallTitle: paywallTitle,
      courseName: courseName,
      courseTag: courseTag,
      photoCount: photoCount,
    );
