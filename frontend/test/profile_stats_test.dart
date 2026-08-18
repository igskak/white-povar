import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/app/theme/app_theme.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/branding/brand_config.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/profile/models/profile_stats.dart';
import 'package:frontend/features/profile/presentation/pages/profile_page.dart';
import 'package:frontend/features/profile/providers/profile_stats_provider.dart';
import 'package:frontend/features/profile/services/profile_stats_service.dart';
import 'package:frontend/features/studio/studio_brand_draft_service.dart';
import 'package:frontend/features/subscription/providers/subscription_provider.dart';

void main() {
  group('profile stats contract', () {
    test('missing or nonsensical counts read as zero, never as null', () {
      final stats = ProfileStats.fromJson(const {'saved': 3, 'cooked': -1});

      expect(stats.saved, 3);
      expect(stats.cooked, 0);
      expect(stats.scans, 0);
    });

    test('a signed-out profile reports zeros without calling the API',
        () async {
      final container = ProviderContainer(overrides: [
        currentUserProvider.overrideWithValue(null),
        profileStatsServiceProvider.overrideWithValue(_ExplodingService()),
      ]);
      addTearDown(container.dispose);

      expect(await container.read(profileStatsProvider.future),
          const ProfileStats(saved: 0, cooked: 0, scans: 0));
    });
  });

  group('profile stats presentation', () {
    testWidgets('shows the counts the API returned', (tester) async {
      await tester.pumpWidget(_profileApp(
        stats: () async => const ProfileStats(saved: 1, cooked: 12, scans: 4),
      ));
      await tester.pump();

      expect(_statValue(tester, 'Збережено'), '1');
      expect(_statValue(tester, 'Приготовано'), '12');
      expect(_statValue(tester, 'Сканувань'), '4');
    });

    testWidgets('shows a dash rather than a zero while counts are in flight',
        (tester) async {
      await tester.pumpWidget(_profileApp(
        stats: () => Completer<ProfileStats>().future,
      ));
      await tester.pump();

      expect(_statValue(tester, 'Збережено'), '—');
      expect(_statValue(tester, 'Приготовано'), '—');
      expect(_statValue(tester, 'Сканувань'), '—');
    });

    testWidgets('an unreachable API leaves a dash, not an empty collection',
        (tester) async {
      await tester.pumpWidget(_profileApp(
        stats: () async => throw Exception('offline'),
      ));
      await tester.pump();

      expect(_statValue(tester, 'Збережено'), '—');
      expect(tester.takeException(), isNull);
    });
  });
}

/// Reads the number rendered above a counter's label.
String _statValue(WidgetTester tester, String label) {
  final card = find.ancestor(
    of: find.text(label),
    matching: find.byType(Column),
  );
  final value = find.descendant(of: card.first, matching: find.byType(Text));
  return tester.widget<Text>(value.first).data!;
}

class _ExplodingService extends ProfileStatsService {
  _ExplodingService()
      : super(ApiClient(
          baseUrl: 'https://example.invalid',
          tokenProvider: _noToken,
          tenantSlug: 'ohorodnik-oleksandr',
          locale: 'uk',
        ));

  @override
  Future<ProfileStats> get() async =>
      throw StateError('the API must not be called for a signed-out profile');
}

Future<String?> _noToken() async => null;

Widget _profileApp({required Future<ProfileStats> Function() stats}) =>
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(_user),
        isPremiumProvider.overrideWithValue(false),
        profileAccountDataLoadingProvider.overrideWithValue(false),
        studioSessionProvider.overrideWith((_) async => null),
        profileStatsProvider.overrideWith((_) => stats()),
      ],
      child: MaterialApp(
        theme: AppThemeV2.light(_brand),
        home: const ProfilePage(),
      ),
    );

const _user = User(
  id: 'profile-user',
  email: 'olena@example.com',
  appMetadata: {},
  userMetadata: {},
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
