import 'package:flutter/foundation.dart';

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

/// Production deliberately exposes no purchasable products until COM-02.
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
    kDebugMode ? FakePurchaseAdapter() : const DisabledPurchaseAdapter();
