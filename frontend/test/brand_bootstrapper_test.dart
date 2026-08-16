import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/branding/brand_bootstrapper.dart';
import 'package:frontend/core/branding/tenant_bootstrap.dart';

const _tenant = 'ohorodnik-oleksandr';

const _bundled = '''
{
  "tenant": {"slug": "ohorodnik-oleksandr"},
  "brandConfig": {
    "schemaVersion": 1,
    "tenantSlug": "ohorodnik-oleksandr",
    "locale": "uk",
    "brand": {
      "name": "Огороднік Олександр", "creatorName": "Олександр",
      "avatar": "PENDING:/brands/ohorodnik-oleksandr/avatar-512.png",
      "accent": "#5D7183", "font": "grotesque",
      "voice": {"greeting": "Ой, друзі", "loginTitle": "Готуйте", "paywallTitle": "Колекції", "courseName": "Майстерня Олександра"},
      "courseTag": "maisternia-oleksandra",
      "derived": {"accentPressed": "#4B5E70", "accentOnDark": "#6B8092", "onAccent": "#FFFFFF", "lightCtaMode": "accentFill"}
    }
  },
  "productConfig": {}, "configVersion": "bundled-pilot-1"
}''';

final _remote = _bundled.replaceAll('bundled-pilot-1', 'remote-v2');

void main() {
  test('first offline start uses the bundled pilot tenant', () async {
    final storage = _MemoryStorage();
    final result = await _bootstrap(storage, _ThrowingRemote()).load();

    expect(result.tenantSlug, _tenant);
    expect(result.brandConfig.brand.name, 'Огороднік Олександр');
    expect(result.brandConfig.brand.voice.courseName, 'Майстерня Олександра');
    expect(result.brandConfig.brand.courseTag, 'maisternia-oleksandra');
    expect(result.configVersion, 'bundled-pilot-1');
  });

  test('published configuration applies on the start that fetched it',
      () async {
    final storage = _MemoryStorage();
    final result = await _bootstrap(storage, _StaticRemote(_remote)).load();

    expect(result.configVersion, 'remote-v2');
    expect(storage.value, contains('remote-v2'));
  });

  test(
      'a response slower than the startup budget still lands for the next start',
      () async {
    final storage = _MemoryStorage();
    final remote = _DeferredRemote(_remote);
    final first = await _bootstrap(
      storage,
      remote,
      budget: const Duration(milliseconds: 10),
    ).load();

    expect(first.configVersion, 'bundled-pilot-1');

    remote.deliver();
    await pumpEventQueue();
    expect(storage.value, contains('remote-v2'));

    final second = await _bootstrap(storage, _ThrowingRemote()).load();
    expect(second.configVersion, 'remote-v2');
  });

  test('a late response is handed back to the session that asked for it',
      () async {
    final storage = _MemoryStorage();
    final remote = _DeferredRemote(_remote);
    TenantBootstrap? late;

    final started = await _bootstrap(
      storage,
      remote,
      budget: const Duration(milliseconds: 10),
    ).load(onLateArrival: (arrived) => late = arrived);

    // The API sleeps between sessions, so the wake-up routinely outruns the
    // budget. Publishing looked broken because this answer used to be kept for
    // the *next* cold start only.
    expect(started.configVersion, 'bundled-pilot-1');
    expect(late, isNull);

    remote.deliver();
    await pumpEventQueue();

    expect(late?.configVersion, 'remote-v2');
  });

  test('refresh re-reads published configuration for a running session',
      () async {
    final storage = _MemoryStorage();
    final bootstrapper = _bootstrap(storage, _StaticRemote(_remote));

    expect((await bootstrapper.refresh())?.configVersion, 'remote-v2');
    // An unreachable API leaves the caller with what it already had.
    expect(await _bootstrap(storage, _ThrowingRemote()).refresh(), isNull);
  });

  test('retries once before falling back, so a cold API still refreshes',
      () async {
    final storage = _MemoryStorage();
    final remote = _FlakyRemote(_remote);
    final result = await _bootstrap(
      storage,
      remote,
      retryDelay: Duration.zero,
    ).load();

    expect(remote.calls, 2);
    expect(result.configVersion, 'remote-v2');
  });

  test('falls back to the cached version when every attempt fails', () async {
    final storage = _MemoryStorage()..value = _remote;
    final result = await _bootstrap(
      storage,
      _ThrowingRemote(),
      retryDelay: Duration.zero,
    ).load();

    expect(result.configVersion, 'remote-v2');
  });

  test('ignores corrupt cache and retains the bundled tenant', () async {
    final storage = _MemoryStorage()..value = '{not json';
    final result = await _bootstrap(storage, _ThrowingRemote()).load();

    expect(result.configVersion, 'bundled-pilot-1');
  });

  test('does not hold the start longer than the startup budget', () async {
    final stopwatch = Stopwatch()..start();
    final result = await _bootstrap(
      _MemoryStorage(),
      _NeverRemote(),
      budget: const Duration(milliseconds: 10),
      remoteTimeout: const Duration(milliseconds: 20),
    ).load();
    stopwatch.stop();

    expect(result.configVersion, 'bundled-pilot-1');
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 250)));
  });
}

BrandBootstrapper _bootstrap(
  _MemoryStorage storage,
  BrandBootstrapRemoteLoader remote, {
  Duration budget = const Duration(seconds: 6),
  Duration remoteTimeout = const Duration(seconds: 30),
  Duration retryDelay = const Duration(milliseconds: 1),
}) =>
    BrandBootstrapper(
      tenantSlug: _tenant,
      storage: storage,
      remoteLoader: remote,
      bundledLoader: () async => _bundled,
      startupBudget: budget,
      remoteTimeout: remoteTimeout,
      retryDelay: retryDelay,
    );

class _MemoryStorage implements BrandBootstrapStorage {
  String? value;

  @override
  Future<String?> read(String tenantSlug) async => value;

  @override
  Future<void> write(String tenantSlug, String nextValue) async {
    value = nextValue;
  }
}

class _StaticRemote implements BrandBootstrapRemoteLoader {
  _StaticRemote(this.value);
  final String value;

  @override
  Future<String> load(String tenantSlug) async => value;
}

class _ThrowingRemote implements BrandBootstrapRemoteLoader {
  @override
  Future<String> load(String tenantSlug) => Future.error(StateError('offline'));
}

class _NeverRemote implements BrandBootstrapRemoteLoader {
  @override
  Future<String> load(String tenantSlug) => Completer<String>().future;
}

/// Stands in for the sleeping API: the first call fails the way a refused
/// connection does, the retry succeeds.
class _FlakyRemote implements BrandBootstrapRemoteLoader {
  _FlakyRemote(this.value);
  final String value;
  int calls = 0;

  @override
  Future<String> load(String tenantSlug) async {
    calls++;
    if (calls == 1) throw StateError('cold start');
    return value;
  }
}

class _DeferredRemote implements BrandBootstrapRemoteLoader {
  _DeferredRemote(this.value);
  final String value;
  final _completer = Completer<String>();

  @override
  Future<String> load(String tenantSlug) => _completer.future;

  void deliver() => _completer.complete(value);
}
