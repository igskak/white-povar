import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_error.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/studio/studio_brand_draft_service.dart';

const _user = User(
  id: 'studio-1',
  email: 'wp-studio@example.com',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-07-15T00:00:00Z',
);

const _session =
    StudioSession(role: 'admin', tenantSlug: 'ohorodnik-oleksandr');

void main() {
  test('a signed-out visitor is not a member without calling the API',
      () async {
    final container = _container(
      user: null,
      service: _FakeService(() async =>
          throw StateError('the API must not be called when signed out')),
    );

    expect(await _read(container), isNull);
  });

  test('a 403 is the private "not a member" answer', () async {
    final container = _container(
      user: _user,
      service: _FakeService(() async => throw const ApiError(
          type: ApiErrorType.forbidden, message: 'forbidden')),
    );

    expect(await _read(container), isNull);
  });

  test('a 401 stays an error rather than being cached as "not a member"',
      () async {
    final container = _container(
      user: _user,
      service: _FakeService(() async => throw const ApiError(
          type: ApiErrorType.unauthorized, message: 'unauthorized')),
    );

    await expectLater(_read(container), throwsA(isA<ApiError>()));
  });

  test('signing in re-resolves membership instead of keeping the guest answer',
      () async {
    final user = StateProvider<User?>((ref) => null);
    final container = ProviderContainer(overrides: [
      currentUserProvider.overrideWith((ref) => ref.watch(user)),
      studioBrandDraftServiceProvider
          .overrideWithValue(_FakeService(() async => _session)),
    ]);
    addTearDown(container.dispose);
    container.listen(studioSessionProvider, (_, __) {});

    expect(await container.read(studioSessionProvider.future), isNull);

    container.read(user.notifier).state = _user;

    expect(await container.read(studioSessionProvider.future), _session);
  });
}

ProviderContainer _container({
  required User? user,
  required StudioBrandDraftService service,
}) {
  final container = ProviderContainer(overrides: [
    currentUserProvider.overrideWithValue(user),
    studioBrandDraftServiceProvider.overrideWithValue(service),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Holds the auto-disposed provider alive for the length of the read.
Future<StudioSession?> _read(ProviderContainer container) {
  container.listen(studioSessionProvider, (_, __) {});
  return container.read(studioSessionProvider.future);
}

class _FakeService extends StudioBrandDraftService {
  _FakeService(this._session)
      : super(ApiClient(
          baseUrl: 'https://example.invalid',
          tokenProvider: _noToken,
          tenantSlug: 'ohorodnik-oleksandr',
          locale: 'uk',
        ));

  final Future<StudioSession> Function() _session;

  @override
  Future<StudioSession> session() => _session();
}

Future<String?> _noToken() async => null;
