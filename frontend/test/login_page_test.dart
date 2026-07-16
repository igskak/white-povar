import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/branding/brand_providers.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/features/auth/models/auth_state.dart';
import 'package:frontend/features/auth/presentation/pages/login_page.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';

void main() {
  testWidgets('login renders the brand fallback at mobile, tablet and desktop',
      (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [390.0, 768.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_app());

      expect(find.text('Готуйте з Олександром'), findsOneWidget);
      expect(find.text('Продовжити з Google'), findsNothing);
      expect(find.text('Продовжити як гість'), findsOneWidget);
      final exception = tester.takeException();
      expect(exception, isNull, reason: 'width: $width');
    }
  });

  testWidgets('login goldens at design breakpoints', (tester) async {
    // The committed goldens exercise an explicitly enabled OAuth provider.
    // Production hides it until its Supabase callback is verified.
    if (!AppConfig.googleOAuthEnabled) return;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [390.0, 768.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(_app());
      await expectLater(
        find.byType(LoginPage),
        matchesGoldenFile('goldens/login_page_${width.toInt()}.png'),
      );
    }
  }, tags: 'golden');

  testWidgets('login remains usable at 200% text scale', (tester) async {
    await tester.pumpWidget(_app(textScaler: const TextScaler.linear(2)));
    expect(find.text('Готуйте з Олександром'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'signup, reset and non-enumerating reset sent states are available', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.ensureVisible(find.text('Створити новий акаунт'));
    await tester.tap(find.text('Створити новий акаунт'));
    await tester.pump();
    expect(find.text('Створіть свій акаунт'), findsOneWidget);
    expect(find.text('Мінімум 8 символів'), findsOneWidget);

    await tester.ensureVisible(find.text('У мене вже є акаунт'));
    await tester.tap(find.text('У мене вже є акаунт'));
    await tester.pump();
    await tester.ensureVisible(find.text('Забули пароль?'));
    await tester.tap(find.text('Забули пароль?'));
    await tester.pump();
    expect(find.text('Відновлення пароля'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nobody@example.com');
    await tester.ensureVisible(find.text('Надіслати посилання'));
    await tester.tap(find.text('Надіслати посилання'));
    await tester.pump();
    expect(
      find.text(
        'Якщо акаунт з таким email існує, ми надіслали лист із посиланням для зміни пароля.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('server errors are shown as a safe Ukrainian banner',
      (tester) async {
    await tester.pumpWidget(
      _app(state: const AppAuthState.error('invalid credentials')),
    );

    expect(find.text('Email або пароль не підходять.'), findsOneWidget);
  });
}

Widget _app({
  AppAuthState state = const AppAuthState.unauthenticated(),
  TextScaler? textScaler,
}) =>
    ProviderScope(
      overrides: [
        tenantBootstrapProvider.overrideWithValue(_bootstrap),
        authProvider.overrideWith((ref) => AuthNotifier.testing(state)),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brandConfig),
        darkTheme: AppThemeV2.dark(_brandConfig),
        builder: (context, child) => textScaler == null
            ? child!
            : MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: textScaler),
                child: child!,
              ),
        home: const LoginPage(),
      ),
    );

const _brandConfig = BrandConfig(
  schemaVersion: 1,
  tenantSlug: 'ohorodnik-oleksandr',
  locale: 'uk',
  brand: BrandDetails(
    name: 'Огороднік Олександр',
    creatorName: 'Олександр',
    avatar: 'PENDING:/avatar.png',
    accent: '#5D7183',
    font: 'grotesque',
    voice: BrandVoice(
      greeting: 'Ой, друзі, ну це щось...',
      loginTitle: 'Готуйте з Олександром',
      paywallTitle: 'Колекції Олександра',
    ),
    derived: DerivedBrandColors(
      accentPressed: '#4B5E70',
      accentOnDark: '#6B8092',
      onAccent: '#FFFFFF',
      lightCtaMode: 'accentFill',
    ),
    heroPhotos: [],
  ),
);

const _bootstrap = TenantBootstrap(
  tenantSlug: 'ohorodnik-oleksandr',
  brandConfig: _brandConfig,
  configVersion: 'test',
);
