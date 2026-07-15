import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'purchase_adapter.dart';

final purchaseAdapterProvider = Provider<PurchaseAdapter>(
  (ref) => createPurchaseAdapter(),
);

final paywallProvider = StateNotifierProvider<PaywallNotifier, PaywallSnapshot>(
  (ref) => PaywallNotifier(ref.watch(purchaseAdapterProvider)),
);

class PaywallNotifier extends StateNotifier<PaywallSnapshot> {
  PaywallNotifier(this._adapter)
      : super(const PaywallSnapshot(phase: PaywallPhase.productsLoading));

  final PurchaseAdapter _adapter;
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
    state = PaywallSnapshot(
      phase: outcome.phase,
      products: state.products,
      message: outcome.message,
    );
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
    state = PaywallSnapshot(
      phase: outcome.phase,
      products: state.products,
      message: outcome.message,
    );
    _requestInFlight = false;
  }

  Future<void> manageSubscription() => _adapter.manageSubscription();
}
