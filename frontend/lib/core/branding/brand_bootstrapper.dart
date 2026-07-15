import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'brand_config.dart';
import 'tenant_bootstrap.dart';

const _pilotBootstrapAsset = 'assets/branding/pilot_bootstrap.json';

abstract interface class BrandBootstrapStorage {
  Future<String?> read(String tenantSlug);
  Future<void> write(String tenantSlug, String value);
}

class SharedPreferencesBrandBootstrapStorage implements BrandBootstrapStorage {
  static const _keyPrefix = 'tenant-bootstrap:';

  const SharedPreferencesBrandBootstrapStorage();

  @override
  Future<String?> read(String tenantSlug) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString('$_keyPrefix$tenantSlug');
  }

  @override
  Future<void> write(String tenantSlug, String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('$_keyPrefix$tenantSlug', value);
  }
}

abstract interface class BrandBootstrapRemoteLoader {
  Future<String> load(String tenantSlug);
}

class HttpBrandBootstrapRemoteLoader implements BrandBootstrapRemoteLoader {
  // Startup adapter: bootstrap resolves the tenant context before Riverpod can
  // construct ApiClient. All post-bootstrap config requests use ApiClient.
  HttpBrandBootstrapRemoteLoader({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<String> load(String tenantSlug) async {
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/api/v1/bootstrap/$tenantSlug'),
      headers: const {'Accept': 'application/json'},
    );
    if (response.statusCode != 200) {
      throw StateError('Bootstrap request failed with ${response.statusCode}.');
    }
    return response.body;
  }
}

typedef BundledBootstrapLoader = Future<String> Function();

class BrandBootstrapper {
  BrandBootstrapper({
    required this.tenantSlug,
    required BrandBootstrapStorage storage,
    required BrandBootstrapRemoteLoader remoteLoader,
    BundledBootstrapLoader? bundledLoader,
    Duration remoteTimeout = const Duration(seconds: 3),
  })  : _storage = storage,
        _remoteLoader = remoteLoader,
        _bundledLoader = bundledLoader ??
            (() => rootBundle.loadString(_pilotBootstrapAsset)),
        _remoteTimeout = remoteTimeout;

  final String tenantSlug;
  final BrandBootstrapStorage _storage;
  final BrandBootstrapRemoteLoader _remoteLoader;
  final BundledBootstrapLoader _bundledLoader;
  final Duration _remoteTimeout;

  /// Returns the version selected at cold start. A newer remote response is
  /// persisted only, so an active session never changes brand unexpectedly.
  Future<TenantBootstrap> load() async {
    final bundled = _parseForTenant(await _bundledLoader());
    final cached = await _loadCached();
    final selected = cached ?? bundled;

    try {
      final remoteSource =
          await _remoteLoader.load(tenantSlug).timeout(_remoteTimeout);
      _parseForTenant(remoteSource);
      await _storage.write(tenantSlug, remoteSource);
    } catch (_) {
      // Cached/bundled config is a valid, tenant-specific offline fallback.
    }

    return selected;
  }

  Future<TenantBootstrap?> _loadCached() async {
    try {
      final cached = await _storage.read(tenantSlug);
      return cached == null ? null : _parseForTenant(cached);
    } catch (_) {
      return null;
    }
  }

  TenantBootstrap _parseForTenant(String source) {
    final bootstrap = TenantBootstrap.fromJson(decodeJsonObject(source));
    if (bootstrap.tenantSlug != tenantSlug) {
      throw const FormatException('Bootstrap belongs to another tenant.');
    }
    return bootstrap;
  }
}
