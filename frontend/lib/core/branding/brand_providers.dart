import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tenant_bootstrap.dart';

/// Holds the published configuration the running session renders.
///
/// Bootstrap seeds it once, and it can be re-read afterwards: Studio refreshes
/// it the moment a brand is published, and the app refreshes it when it returns
/// to the foreground. Before this, configuration was read at cold start only,
/// so a publish looked like it had done nothing until the app was restarted —
/// twice, whenever the API had to wake up first.
class TenantBrandController extends StateNotifier<TenantBootstrap> {
  TenantBrandController({
    required TenantBootstrap initial,
    required Future<TenantBootstrap?> Function() refresher,
  })  : _refresher = refresher,
        super(initial);

  final Future<TenantBootstrap?> Function() _refresher;

  DateTime? _lastAttempt;
  Future<TenantBootstrap?>? _inFlight;

  /// Re-reads configuration now. Returns null when the API could not be
  /// reached, in which case the session keeps the configuration it has.
  ///
  /// Concurrent callers share one request: a publish and a resume can land
  /// together, and the API is slow enough that a second call would be waste.
  Future<TenantBootstrap?> refresh() {
    final pending = _inFlight;
    if (pending != null) return pending;
    _lastAttempt = DateTime.now();
    final request = _refresher().then((fresh) {
      if (fresh != null) adopt(fresh);
      return fresh;
    }).whenComplete(() => _inFlight = null);
    _inFlight = request;
    return request;
  }

  /// Refreshes only when the last attempt is older than [minInterval]. Used by
  /// ambient triggers such as app resume, which fire far more often than
  /// configuration changes.
  Future<TenantBootstrap?> refreshIfStale({
    Duration minInterval = const Duration(minutes: 5),
  }) {
    final last = _lastAttempt;
    if (last != null && DateTime.now().difference(last) < minInterval) {
      return Future.value(null);
    }
    return refresh();
  }

  /// Takes configuration that arrived by another route — the startup request
  /// that outran its budget, for instance.
  void adopt(TenantBootstrap bootstrap) {
    if (bootstrap.configVersion == state.configVersion) return;
    if (!mounted) return;
    state = bootstrap;
  }
}

final tenantBrandControllerProvider =
    StateNotifierProvider<TenantBrandController, TenantBootstrap>(
  (ref) => throw UnimplementedError('Tenant bootstrap has not been loaded.'),
);

/// The configuration to render with. Reading this rebuilds on a refresh, so
/// call sites need no knowledge of how configuration arrives.
final tenantBootstrapProvider = Provider<TenantBootstrap>(
  (ref) => ref.watch(tenantBrandControllerProvider),
);
