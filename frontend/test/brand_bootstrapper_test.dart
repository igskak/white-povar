import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/branding/brand_bootstrapper.dart';

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
      "voice": {"greeting": "Ой, друзі", "loginTitle": "Готуйте", "paywallTitle": "Колекції"},
      "derived": {"accentPressed": "#4B5E70", "accentOnDark": "#6B8092", "onAccent": "#FFFFFF", "lightCtaMode": "accentFill"}
    }
  },
  "productConfig": {}, "configVersion": "bundled-pilot-1"
}''';

void main() {
  test('first offline start uses the bundled pilot tenant', () async {
    final storage = _MemoryStorage();
    final result = await _bootstrap(storage, _ThrowingRemote()).load();

    expect(result.tenantSlug, _tenant);
    expect(result.brandConfig.brand.name, 'Огороднік Олександр');
    expect(result.configVersion, 'bundled-pilot-1');
  });

  test('uses the last valid cached version and saves remote for the next start',
      () async {
    final storage = _MemoryStorage();
    final remote = _bundled.replaceAll('bundled-pilot-1', 'remote-v2');
    final first = await _bootstrap(storage, _StaticRemote(remote)).load();
    final second = await _bootstrap(storage, _ThrowingRemote()).load();

    expect(first.configVersion, 'bundled-pilot-1');
    expect(second.configVersion, 'remote-v2');
  });

  test('ignores corrupt cache and retains the bundled tenant', () async {
    final storage = _MemoryStorage()..value = '{not json';
    final result = await _bootstrap(storage, _ThrowingRemote()).load();

    expect(result.configVersion, 'bundled-pilot-1');
  });

  test('does not wait longer than the configured remote timeout', () async {
    final stopwatch = Stopwatch()..start();
    final result = await _bootstrap(
      _MemoryStorage(),
      _NeverRemote(),
      timeout: const Duration(milliseconds: 10),
    ).load();
    stopwatch.stop();

    expect(result.configVersion, 'bundled-pilot-1');
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 250)));
  });
}

BrandBootstrapper _bootstrap(
  _MemoryStorage storage,
  BrandBootstrapRemoteLoader remote, {
  Duration timeout = const Duration(seconds: 3),
}) =>
    BrandBootstrapper(
      tenantSlug: _tenant,
      storage: storage,
      remoteLoader: remote,
      bundledLoader: () async => _bundled,
      remoteTimeout: timeout,
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
