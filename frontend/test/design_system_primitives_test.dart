import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/widgets/design_system.dart';
import 'package:frontend/core/widgets/state_views.dart';

void main() {
  testWidgets('StateView.loading renders progress indicator and text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeV2.light(_brandConfig),
        home: const Scaffold(
          body: StateView.loading(
            title: 'Loading recipes',
            subtitle: 'Preparing feed',
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading recipes'), findsOneWidget);
    expect(find.text('Preparing feed'), findsOneWidget);
  });

  testWidgets('StateView.error retry action is clickable', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeV2.light(_brandConfig),
        home: Scaffold(
          body: StateView.error(
            title: 'Failed',
            subtitle: 'Try again',
            onRetry: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Повторити'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('Elevated button theme keeps minimum 44px tap target', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeV2.light(_brandConfig),
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Action'),
            ),
          ),
        ),
      ),
    );

    final buttonSize = tester.getSize(find.byType(ElevatedButton));
    expect(buttonSize.height, greaterThanOrEqualTo(44));
    expect(buttonSize.width, greaterThanOrEqualTo(44));
  });

  testWidgets('shared primitives expose accessible, interactive controls', (
    WidgetTester tester,
  ) async {
    var chipSelected = false;
    var cardTapped = false;
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeV2.light(_brandConfig),
        home: Scaffold(
          body: ResponsiveContainer(
            child: Column(
              children: [
                BrandHeader(brand: _brandConfig.brand),
                const UserAvatar(name: 'Олена'),
                AppTextField(
                  controller: controller,
                  label: 'Пошук',
                  onSubmitted: (_) {},
                ),
                AppChip(
                  label: 'Швидко',
                  onSelected: (value) => chipSelected = value,
                ),
                const AppBadge(label: 'Premium', icon: Icons.star_rounded),
                ContentCard(
                  semanticLabel: 'Тестова картка',
                  onTap: () => cardTapped = true,
                  child: const Text('Вміст'),
                ),
                const AppSkeleton(width: 120),
                AppIconButton(
                  icon: Icons.close,
                  tooltip: 'Закрити',
                  onPressed: () {},
                ),
                AppButton(label: 'Продовжити', onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'борщ');
    await tester.tap(find.text('Швидко'));
    await tester.tap(find.text('Вміст'));
    await tester.pump();

    expect(controller.text, 'борщ');
    expect(chipSelected, isTrue);
    expect(cardTapped, isTrue);
    expect(find.bySemanticsLabel('Закрити'), findsOneWidget);
    expect(tester.getSize(find.byType(AppIconButton)).height,
        greaterThanOrEqualTo(44));
  });

  testWidgets('shared primitives render in light and dark pilot themes', (
    WidgetTester tester,
  ) async {
    for (final theme in [
      AppThemeV2.light(_brandConfig),
      AppThemeV2.dark(_brandConfig),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ResponsiveContainer(
              child: ContentCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppButton(label: 'Зберегти', onPressed: () {}),
                    const SizedBox(height: 8),
                    const AppSkeleton(width: 200),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Зберегти'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('shared primitives match the pilot brand golden', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 480));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppThemeV2.light(_brandConfig),
        darkTheme: AppThemeV2.dark(_brandConfig),
        home: Scaffold(
          body: ResponsiveContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BrandHeader(brand: _brandConfig.brand),
                const SizedBox(height: 20),
                const AppTextField(
                  label: 'Електронна пошта',
                  hint: 'name@example.com',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    AppChip(label: 'Веганське', onSelected: (_) {}),
                    const SizedBox(width: 8),
                    const AppBadge(label: 'Premium'),
                  ],
                ),
                const SizedBox(height: 12),
                const ContentCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('Сезонні рецепти'),
                      SizedBox(height: 8),
                      AppSkeleton(width: 180),
                    ],
                  ),
                ),
                const Spacer(),
                AppButton(label: 'Продовжити', onPressed: () {}, expand: true),
              ],
            ),
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/design_system_primitives.png'),
    );
  });
}

final _brandConfig = BrandConfig.fromJson({
  'schemaVersion': 1,
  'tenantSlug': 'test-brand',
  'locale': 'uk',
  'brand': {
    'name': 'Test Brand',
    'creatorName': 'Test',
    'avatar': 'PENDING:/avatar.png',
    'accent': '#5D7183',
    'font': 'grotesque',
    'voice': {
      'greeting': 'Hi',
      'loginTitle': 'Login',
      'paywallTitle': 'Paywall'
    },
    'derived': {
      'accentPressed': '#4B5E70',
      'accentOnDark': '#6B8092',
      'onAccent': '#FFFFFF',
      'lightCtaMode': 'accentFill'
    },
  },
});
