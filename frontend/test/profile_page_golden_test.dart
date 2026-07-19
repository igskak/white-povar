import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/app/router/app_router.dart';
import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/core/branding/brand_providers.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/profile/presentation/pages/profile_page.dart';
import 'package:frontend/features/studio/studio_brand_draft_service.dart';
import 'package:frontend/features/subscription/providers/subscription_provider.dart';

void main() {
  testWidgets('Profile state goldens at handoff breakpoints', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final state in _ProfileFixtureState.values) {
      for (final width in [390.0, 768.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(
          _profileApp(state, fixtureKey: '${state.name}-$width'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await expectLater(
          find.byType(AdaptiveNavigationShell),
          matchesGoldenFile(
            'goldens/profile_state_${state.name}_${width.toInt()}.png',
          ),
        );
        expect(tester.takeException(), isNull,
            reason: '${state.name} at $width');
      }
    }
  }, tags: 'golden');
}

Widget _profileApp(
  _ProfileFixtureState state, {
  required String fixtureKey,
}) =>
    ProviderScope(
      key: ValueKey(fixtureKey),
      overrides: [
        tenantBootstrapProvider.overrideWithValue(_bootstrap),
        currentUserProvider.overrideWithValue(
          state == _ProfileFixtureState.guest ? null : _user,
        ),
        isPremiumProvider.overrideWithValue(
          state == _ProfileFixtureState.premium,
        ),
        studioSessionProvider.overrideWith((_) async => null),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brand),
        home: const AdaptiveNavigationShell(
          selectedIndex: 3,
          onDestinationSelected: _ignoreDestination,
          child: ProfilePage(embeddedInDesktopShell: true),
        ),
      ),
    );

void _ignoreDestination(int _) {}

enum _ProfileFixtureState { guest, free, premium }

const _user = User(
  id: 'profile-user',
  email: 'olena@example.com',
  appMetadata: {},
  userMetadata: {'full_name': 'Олена Коваль'},
  aud: 'authenticated',
  createdAt: '2026-07-15T00:00:00Z',
);

const _brand = BrandConfig(
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
      greeting: 'Ой, друзі',
      loginTitle: 'Готуйте з Олександром',
      paywallTitle: 'Колекції Олександра',
      courseName: 'Майстерня Олександра',
    ),
    derived: DerivedBrandColors(
      accentPressed: '#4B5E70',
      accentOnDark: '#6B8092',
      onAccent: '#FFFFFF',
      lightCtaMode: 'accentFill',
    ),
    heroPhotos: [],
    courseTag: 'maisternia-oleksandra',
  ),
);

const _bootstrap = TenantBootstrap(
  tenantSlug: 'ohorodnik-oleksandr',
  brandConfig: _brand,
  configVersion: 'profile-golden',
);
