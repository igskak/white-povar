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
    Duration startupBudget = const Duration(seconds: 6),
    Duration remoteTimeout = const Duration(seconds: 30),
    Duration retryDelay = const Duration(seconds: 2),
    int remoteAttempts = 2,
  })  : _storage = storage,
        _remoteLoader = remoteLoader,
        _bundledLoader = bundledLoader ??
            (() => rootBundle.loadString(_pilotBootstrapAsset)),
        _startupBudget = startupBudget,
        _remoteTimeout = remoteTimeout,
        _retryDelay = retryDelay,
        _remoteAttempts = remoteAttempts;

  final String tenantSlug;
  final BrandBootstrapStorage _storage;
  final BrandBootstrapRemoteLoader _remoteLoader;
  final BundledBootstrapLoader _bundledLoader;

  /// How long a cold start waits for published configuration before falling
  /// back. A warm API answers in about a second; anything slower is not worth
  /// holding the splash screen for.
  final Duration _startupBudget;

  /// The request itself is allowed to run far longer than the startup budget:
  /// the API sleeps between sessions, and a wake-up can take tens of seconds.
  /// Giving up early is what used to leave a device pinned to a stale brand.
  final Duration _remoteTimeout;
  final Duration _retryDelay;
  final int _remoteAttempts;

  /// Returns the configuration this session runs on. Published changes apply
  /// immediately when they arrive inside the startup budget; a slower response
  /// still refreshes the cache in the background, so the next cold start picks
  /// it up rather than the session changing brand mid-flight.
  Future<TenantBootstrap> load({
    ValueChanged<TenantBootstrap>? onLateArrival,
  }) async {
    final bundled = _parseForTenant(await _bundledLoader());
    final cached = await _loadCached();

    // Deliberately not awaited past the budget: the refresh keeps running and
    // persists whatever it eventually gets.
    final refresh = _refreshFromRemote();
    final fresh = await refresh.timeout(_startupBudget, onTimeout: () => null);
    if (fresh == null && onLateArrival != null) {
      // The API sleeps between sessions, so a wake-up routinely outruns the
      // startup budget. Handing the late answer back means a just-published
      // change lands in this session instead of waiting for the next start —
      // which read as "publishing does nothing" for anyone who reloaded once.
      unawaited(refresh.then((late) {
        if (late != null) onLateArrival(late);
      }));
    }

    return fresh ?? cached ?? bundled;
  }

  /// Re-reads published configuration now, for a session already running.
  /// Returns null when the API could not be reached; the caller keeps what it
  /// has rather than falling back to something older.
  Future<TenantBootstrap?> refresh() => _refreshFromRemote();

  /// Never throws; a failed refresh simply leaves the cache untouched.
  Future<TenantBootstrap?> _refreshFromRemote() async {
    for (var attempt = 1; attempt <= _remoteAttempts; attempt++) {
      try {
        final source =
            await _remoteLoader.load(tenantSlug).timeout(_remoteTimeout);
        final bootstrap = _parseForTenant(source);
        await _storage.write(tenantSlug, source);
        return bootstrap;
      } catch (_) {
        // Cached/bundled config is a valid, tenant-specific offline fallback.
        if (attempt == _remoteAttempts) return null;
        await Future<void>.delayed(_retryDelay);
      }
    }
    return null;
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
