import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/widgets/design_system.dart';

void main() {
  group('QA-DS design matrix', () {
    testWidgets('four brands render in light and dark at every reference width',
        (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final brand in _referenceBrands) {
        for (final brightness in Brightness.values) {
          for (final width in [390.0, 768.0, 1280.0]) {
            tester.view.physicalSize = Size(width, 1000);
            tester.view.devicePixelRatio = 1;
            await tester.pumpWidget(_matrixApp(brand, brightness));
            await tester.pump();

            expect(find.text(brand.brand.name), findsOneWidget);
            expect(find.text('Продовжити'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: '${brand.tenantSlug}/${brightness.name}/$width',
            );
          }
        }
      }
    });

    testWidgets(
        'semantics and keyboard submit remain available at 200% text '
        'scale with reduced motion', (tester) async {
      var submitted = false;
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        _matrixApp(
          _referenceBrands.first,
          Brightness.dark,
          textScaler: const TextScaler.linear(2),
          disableAnimations: true,
          accessibleNavigation: true,
          fieldController: controller,
          onSubmitted: (_) => submitted = true,
        ),
      );

      expect(find.bySemanticsLabel('Пошук'), findsWidgets);
      expect(find.bySemanticsLabel('Продовжити'), findsWidgets);
      await tester.enterText(find.byType(TextFormField), 'борщ');
      await tester.testTextInput.receiveAction(TextInputAction.done);

      expect(controller.text, 'борщ');
      expect(submitted, isTrue);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    test('theme foregrounds meet the documented contrast floor', () {
      for (final brand in _referenceBrands) {
        final light = AppThemeV2.light(brand);
        final dark = AppThemeV2.dark(brand);
        expect(
          _contrastRatio(
              light.colorScheme.onPrimary, light.colorScheme.primary),
          greaterThanOrEqualTo(4.5),
          reason: '${brand.tenantSlug} light primary action',
        );
        expect(
          _contrastRatio(
              dark.colorScheme.primary, dark.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5),
          reason: '${brand.tenantSlug} dark primary action',
        );
        for (final theme in [light, dark]) {
          final scheme = theme.colorScheme;
          expect(
            _contrastRatio(scheme.onSurface, scheme.surface),
            greaterThanOrEqualTo(4.5),
            reason: '${brand.tenantSlug} surface text',
          );
        }
      }
    });
  });
}

Widget _matrixApp(
  BrandConfig brand,
  Brightness brightness, {
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
  TextEditingController? fieldController,
  ValueChanged<String>? onSubmitted,
}) {
  final theme = brightness == Brightness.dark
      ? AppThemeV2.dark(brand)
      : AppThemeV2.light(brand);
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: MediaQueryData(
        textScaler: textScaler,
        disableAnimations: disableAnimations,
        accessibleNavigation: accessibleNavigation,
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ResponsiveContainer(
            maxWidth: 560,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrandHeader(brand: brand.brand),
                const SizedBox(height: 24),
                AppTextField(
                  controller: fieldController,
                  label: 'Пошук',
                  textInputAction: TextInputAction.done,
                  onSubmitted: onSubmitted,
                ),
                const SizedBox(height: 16),
                ContentCard(
                  semanticLabel: 'Контрольна картка дизайну',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Сезонні рецепти',
                          style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const AppSkeleton(width: 180),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Продовжити',
                  onPressed: () {},
                  expand: true,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter =
      firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
  final darker =
      firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}

final _referenceBrands = [
  _brand('ohorodnik-oleksandr', 'Огороднік Олександр', 'Олександр', '#5D7183',
      '#6B8092', 'grotesque'),
  _brand(
      'terra-kitchen', 'Terra Kitchen', 'Terra', '#9C4E31', '#B86A4A', 'serif'),
  _brand('zelenyi-stil', 'Зелений стіл', 'Марія', '#39736D', '#4C928A',
      'humanist'),
  _brand('pivnichna-kukhnia', 'Північна кухня', 'Іван', '#405B70', '#7595AA',
      'grotesque'),
];

BrandConfig _brand(
  String slug,
  String name,
  String creatorName,
  String accent,
  String accentOnDark,
  String font,
) =>
    BrandConfig.fromJson({
      'schemaVersion': 1,
      'tenantSlug': slug,
      'locale': 'uk',
      'brand': {
        'name': name,
        'creatorName': creatorName,
        'avatar': 'PENDING:/avatar.png',
        'accent': accent,
        'font': font,
        'voice': {
          'greeting': 'Вітаємо',
          'loginTitle': 'Увійти',
          'paywallTitle': 'Колекції',
        },
        'derived': {
          'accentPressed': '#324554',
          'accentOnDark': accentOnDark,
          'onAccent': '#FFFFFF',
          'lightCtaMode': 'accentFill',
        },
      },
    });
