import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
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
