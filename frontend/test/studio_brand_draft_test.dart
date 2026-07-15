import 'package:flutter_test/flutter_test.dart';
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
          'heroPhotos': [],
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
  });
}
