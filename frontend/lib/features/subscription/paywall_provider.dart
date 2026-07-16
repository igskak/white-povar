import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import 'commerce_entitlement_service.dart';
import 'purchase_adapter.dart';

final purchaseAdapterProvider = Provider<PurchaseAdapter>(
  (ref) => createPurchaseAdapter(ref.watch(apiClientProvider)),
);

final selectedPurchaseProductProvider = StateProvider<String?>((_) => null);

final paywallProvider = StateNotifierProvider<PaywallNotifier, PaywallSnapshot>(
  (ref) => PaywallNotifier(
    ref.watch(purchaseAdapterProvider),
    () => CommerceEntitlementService(ref.read(apiClientProvider)).read(),
  ),
);

class PaywallNotifier extends StateNotifier<PaywallSnapshot> {
  PaywallNotifier(this._adapter, this._readEntitlement)
      : super(const PaywallSnapshot(phase: PaywallPhase.productsLoading));

  final PurchaseAdapter _adapter;
  final Future<PaywallSnapshot> Function() _readEntitlement;
  bool _requestInFlight = false;

  Future<void> load() async {
    state = const PaywallSnapshot(phase: PaywallPhase.productsLoading);
    state = await _adapter.load();
  }

  Future<void> purchase(PurchaseProduct product) async {
    // A completed transaction is terminal for this presentation session. The
    // caller must refresh entitlement state before another purchase can begin.
    if (_requestInFlight || state.phase == PaywallPhase.success) return;
    _requestInFlight = true;
    state = PaywallSnapshot(
      phase: PaywallPhase.purchasing,
      products: state.products,
    );
    final outcome = await _adapter.purchase(product);
    if (outcome.requiresEntitlementConfirmation) {
      await _confirmEntitlement(outcome);
    } else {
      state = PaywallSnapshot(
        phase: outcome.phase,
        products: state.products,
        message: outcome.message,
      );
    }
    _requestInFlight = false;
  }

  Future<void> restore() async {
    if (_requestInFlight) return;
    _requestInFlight = true;
    state = PaywallSnapshot(
      phase: PaywallPhase.purchasing,
      products: state.products,
    );
    final outcome = await _adapter.restore();
    if (outcome.requiresEntitlementConfirmation) {
      await _confirmEntitlement(outcome);
    } else {
      state = PaywallSnapshot(
        phase: outcome.phase,
        products: state.products,
        message: outcome.message,
      );
    }
    _requestInFlight = false;
  }

  Future<void> manageSubscription() => _adapter.manageSubscription();

  Future<void> _confirmEntitlement([PurchaseOutcome? outcome]) async {
    final products = state.products;
    state = PaywallSnapshot(
      phase: PaywallPhase.confirmationPending,
      products: products,
      message: 'Підтверджуємо доступ на сервері…',
    );
    for (var attempt = 0; attempt < 6; attempt++) {
      try {
        final entitlement = await _readEntitlement();
        if (_isEntitled(entitlement.phase)) {
          state = PaywallSnapshot(
            phase: entitlement.phase,
            products: products,
            renewsOn: entitlement.renewsOn,
          );
          return;
        }
        // A one-off entitlement is collection-scoped, so the generic tenant
        // status deliberately stays false. The server purchase result is still
        // followed by this mandatory read before returning to that collection.
        if (outcome?.accessScope == PurchaseAccessScope.collection &&
            outcome?.collectionId != null) {
          state = PaywallSnapshot(
            phase: PaywallPhase.success,
            products: products,
            message: 'Демо-доступ до колекції активовано.',
          );
          return;
        }
      } catch (_) {
        // Webhook delivery can still be in flight; retry without exposing any
        // transaction detail to the UI or analytics.
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    state = PaywallSnapshot(
      phase: PaywallPhase.error,
      products: products,
      message: 'Платіж обробляється. Оновіть статус трохи пізніше.',
    );
  }
}

bool _isEntitled(PaywallPhase phase) =>
    phase == PaywallPhase.active ||
    phase == PaywallPhase.grace ||
    phase == PaywallPhase.billingRetry;
