import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'store_catalog_service.dart';

/// Boundary for StoreKit / Play Billing. COM-02 replaces the production
/// implementation; UI-03 only consumes the data and outcomes exposed here.
abstract interface class PurchaseAdapter {
  Future<PaywallSnapshot> load();
  Future<PurchaseOutcome> purchase(PurchaseProduct product);
  Future<PurchaseOutcome> restore();
  Future<void> manageSubscription();
}

enum PaywallPhase {
  idle,
  productsLoading,
  productsUnavailable,
  purchasing,
  success,
  error,
  userCancelled,
  active,
  grace,
  billingRetry,
  expired,
  cancelled,
}

class PurchaseProduct {
  const PurchaseProduct({
    required this.id,
    required this.title,
    required this.price,
    this.detail,
    this.trial,
    this.badge,
  });

  final String id;
  final String title;
  final String price;
  final String? detail;
  final String? trial;
  final String? badge;
}

class PaywallSnapshot {
  const PaywallSnapshot({
    required this.phase,
    this.products = const [],
    this.message,
    this.renewsOn,
  });

  final PaywallPhase phase;
  final List<PurchaseProduct> products;
  final String? message;
  final DateTime? renewsOn;
}

class PurchaseOutcome {
  const PurchaseOutcome(this.phase, {this.message});

  final PaywallPhase phase;
  final String? message;
}

/// The web does not sell products in the MVP. It can only reflect server-side
/// entitlements once COM-03 wires that read model into the paywall.
class DisabledPurchaseAdapter implements PurchaseAdapter {
  const DisabledPurchaseAdapter();

  @override
  Future<PaywallSnapshot> load() async => const PaywallSnapshot(
        phase: PaywallPhase.productsUnavailable,
        message: 'Оформлення підписки стане доступним у мобільному застосунку.',
      );

  @override
  Future<PurchaseOutcome> purchase(PurchaseProduct product) async =>
      const PurchaseOutcome(PaywallPhase.productsUnavailable);

  @override
  Future<PurchaseOutcome> restore() async =>
      const PurchaseOutcome(PaywallPhase.productsUnavailable);

  @override
  Future<void> manageSubscription() async {}
}

/// Fake catalog is intentionally limited to debug and widget tests. Prices are
/// adapter data, never presentation constants.
class FakePurchaseAdapter implements PurchaseAdapter {
  FakePurchaseAdapter({
    this.snapshot = const PaywallSnapshot(
      phase: PaywallPhase.idle,
      products: [
        PurchaseProduct(
          id: 'debug.annual',
          title: 'Річний',
          price: '1 499 ₴',
          detail: '125 ₴/міс після trial',
          trial: '7 днів безкоштовно',
          badge: '−37%',
        ),
        PurchaseProduct(id: 'debug.monthly', title: 'Місячний', price: '199 ₴'),
      ],
    ),
    this.purchaseOutcome = const PurchaseOutcome(PaywallPhase.success),
    this.restoreOutcome = const PurchaseOutcome(PaywallPhase.userCancelled),
  });

  final PaywallSnapshot snapshot;
  final PurchaseOutcome purchaseOutcome;
  final PurchaseOutcome restoreOutcome;

  @override
  Future<PaywallSnapshot> load() async => snapshot;

  @override
  Future<PurchaseOutcome> purchase(PurchaseProduct product) async =>
      purchaseOutcome;

  @override
  Future<PurchaseOutcome> restore() async => restoreOutcome;

  @override
  Future<void> manageSubscription() async {}
}

PurchaseAdapter createPurchaseAdapter() =>
    kDebugMode
        ? FakePurchaseAdapter()
        : kIsWeb
            ? const DisabledPurchaseAdapter()
            : NativeStoreCatalogAdapter(
                catalog: StoreCatalogService(),
                purchases: InAppPurchase.instance,
              );

/// Loads display data from StoreKit / Play Billing. Purchasing, transaction
/// completion, restore and manage links deliberately remain COM-03 work; no
/// native purchase result can grant UI access before the billing webhook does.
class NativeStoreCatalogAdapter implements PurchaseAdapter {
  NativeStoreCatalogAdapter({
    required StoreCatalogService catalog,
    required InAppPurchase purchases,
  })  : _catalog = catalog,
        _purchases = purchases;

  final StoreCatalogService _catalog;
  final InAppPurchase _purchases;

  @override
  Future<PaywallSnapshot> load() async {
    if (!await _purchases.isAvailable()) {
      return const PaywallSnapshot(phase: PaywallPhase.productsUnavailable);
    }
    try {
      final ids = await _catalog.loadStoreProductIds();
      if (ids.isEmpty) return const PaywallSnapshot(phase: PaywallPhase.productsUnavailable);
      final response = await _purchases.queryProductDetails(ids);
      if (response.error != null || response.productDetails.isEmpty) {
        return const PaywallSnapshot(phase: PaywallPhase.productsUnavailable);
      }
      return PaywallSnapshot(
        phase: PaywallPhase.idle,
        products: response.productDetails
            .map((detail) => PurchaseProduct(
                  id: detail.id,
                  title: detail.title,
                  price: detail.price,
                  detail: detail.description.isEmpty ? null : detail.description,
                ))
            .toList(growable: false),
      );
    } catch (_) {
      return const PaywallSnapshot(phase: PaywallPhase.productsUnavailable);
    }
  }

  @override
  Future<PurchaseOutcome> purchase(PurchaseProduct product) async =>
      const PurchaseOutcome(PaywallPhase.productsUnavailable);

  @override
  Future<PurchaseOutcome> restore() async =>
      const PurchaseOutcome(PaywallPhase.productsUnavailable);

  @override
  Future<void> manageSubscription() async {}
}
