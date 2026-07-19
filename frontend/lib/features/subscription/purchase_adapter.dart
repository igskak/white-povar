import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_error.dart';
import 'store_catalog_service.dart';

/// Boundary for StoreKit / Play Billing and server entitlement confirmation.
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
  notAllowlisted,
  purchasing,
  confirmationPending,
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
    this.accessScope = PurchaseAccessScope.tenant,
    this.collectionIds = const [],
  });

  final String id;
  final String title;
  final String price;
  final String? detail;
  final String? trial;
  final String? badge;
  final PurchaseAccessScope accessScope;
  final List<String> collectionIds;
}

enum PurchaseAccessScope { tenant, collection }

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
  const PurchaseOutcome(
    this.phase, {
    this.message,
    this.requiresEntitlementConfirmation = false,
    this.accessScope,
    this.collectionId,
  });

  final PaywallPhase phase;
  final String? message;

  /// StoreKit/Play completion merely means the store accepted a transaction.
  /// It never grants access: COM-03 waits for the server-issued entitlement.
  final bool requiresEntitlementConfirmation;
  final PurchaseAccessScope? accessScope;
  final String? collectionId;
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

PurchaseAdapter createPurchaseAdapter(ApiClient apiClient) => kIsWeb
    ? WebDemoPurchaseAdapter(apiClient)
    : kDebugMode
        ? FakePurchaseAdapter()
        : NativeStoreCatalogAdapter(
            catalog: StoreCatalogService(),
            purchases: InAppPurchase.instance,
          );

/// Web demo commerce is server-catalogue driven. It never sends client-owned
/// price, duration, user, or collection values. The notifier still refreshes
/// the server entitlement before presenting premium access.
class WebDemoPurchaseAdapter implements PurchaseAdapter {
  WebDemoPurchaseAdapter(this._apiClient, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final ApiClient _apiClient;
  final Uuid _uuid;
  bool _demoPurchaseAvailable = false;

  @override
  Future<PaywallSnapshot> load() async {
    try {
      final response = await _loadCatalogueWithWakeRetry();
      final data = response.data ?? const <String, dynamic>{};
      _demoPurchaseAvailable = data['commerceMode'] == 'demo' &&
          data['demoPurchaseAvailable'] == true;
      final offers = (data['offers'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => _productFromOffer(Map<String, dynamic>.from(item)))
          .toList(growable: false);
      if (offers.isEmpty) {
        return const PaywallSnapshot(
          phase: PaywallPhase.productsUnavailable,
          message: 'Демо-пропозиції зараз недоступні.',
        );
      }
      if (data['commerceMode'] == 'demo' && !_demoPurchaseAvailable) {
        return PaywallSnapshot(
          phase: PaywallPhase.notAllowlisted,
          products: offers,
          message: 'Демо-доступ поки недоступний для цього акаунта.',
        );
      }
      if (data['commerceMode'] != 'demo') {
        return PaywallSnapshot(
          phase: PaywallPhase.productsUnavailable,
          products: offers,
          message: 'Оформлення доступу зараз недоступне.',
        );
      }
      return PaywallSnapshot(phase: PaywallPhase.idle, products: offers);
    } catch (_) {
      return const PaywallSnapshot(
        phase: PaywallPhase.productsUnavailable,
        message: 'Не вдалося завантажити пропозиції. Спробуйте ще раз.',
      );
    }
  }

  /// Render's free instances can return a short 502/503 while waking. Retry
  /// only transport failures so a signed-in, allowlisted buyer does not see a
  /// false unavailable state during the normal cold-start window. Auth and
  /// access errors remain fail-closed and are never retried.
  Future<Response<Map<String, dynamic>>> _loadCatalogueWithWakeRetry() async {
    // A Render free instance may need close to a minute to wake. Keep the
    // screen in its normal loading state through that bounded window instead
    // of requiring an eligible buyer to discover and press Retry.
    const delays = [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
      Duration(seconds: 16),
      Duration(seconds: 20),
    ];
    for (var attempt = 0;; attempt++) {
      try {
        return await _apiClient.get<Map<String, dynamic>>(
          '/api/v1/commerce/catalogue',
        );
      } on ApiError catch (error) {
        final retryable = error.type == ApiErrorType.network ||
            error.type == ApiErrorType.timeout ||
            (error.type == ApiErrorType.server &&
                (error.statusCode == 502 || error.statusCode == 503));
        if (!retryable || attempt >= delays.length) rethrow;
        await Future<void>.delayed(delays[attempt]);
      }
    }
  }

  @override
  Future<PurchaseOutcome> purchase(PurchaseProduct product) async {
    if (!_demoPurchaseAvailable) {
      return const PurchaseOutcome(PaywallPhase.notAllowlisted);
    }
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '/api/v1/commerce/demo-purchases',
        data: {'offerKey': product.id},
        options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
      );
      final result = response.data ?? const <String, dynamic>{};
      if (result['accepted'] != true) {
        return const PurchaseOutcome(PaywallPhase.error);
      }
      return PurchaseOutcome(
        PaywallPhase.confirmationPending,
        requiresEntitlementConfirmation: true,
        accessScope: result['scopeType'] == 'collection'
            ? PurchaseAccessScope.collection
            : PurchaseAccessScope.tenant,
        collectionId: result['collectionId']?.toString(),
      );
    } on ApiError catch (error) {
      return PurchaseOutcome(
        PaywallPhase.error,
        message: _demoPurchaseErrorMessage(error),
      );
    } catch (_) {
      return const PurchaseOutcome(
        PaywallPhase.error,
        message: 'Не вдалося підтвердити демо-доступ. Спробуйте ще раз.',
      );
    }
  }

  @override
  Future<PurchaseOutcome> restore() async => const PurchaseOutcome(
        PaywallPhase.confirmationPending,
        requiresEntitlementConfirmation: true,
      );

  @override
  Future<void> manageSubscription() async {}

  PurchaseProduct _productFromOffer(Map<String, dynamic> offer) {
    final amount = offer['amountMinor'];
    final currency = offer['currency']?.toString() ?? '';
    final price = amount is num ? '${amount / 100} $currency' : currency;
    final collectionIds = (offer['collectionIds'] as List? ?? const [])
        .map((id) => id.toString())
        .toList(growable: false);
    return PurchaseProduct(
      id: offer['offerKey'].toString(),
      title: offer['title']?.toString() ?? 'Premium-доступ',
      price: price,
      detail: offer['description']?.toString(),
      badge: offer['badge']?.toString(),
      trial: offer['trialDays'] == null ? null : '${offer['trialDays']} днів',
      accessScope: offer['accessScope'] == 'collection'
          ? PurchaseAccessScope.collection
          : PurchaseAccessScope.tenant,
      collectionIds: collectionIds,
    );
  }
}

String _demoPurchaseErrorMessage(ApiError error) => switch (error.type) {
      ApiErrorType.unauthorized =>
        'Увійдіть знову, щоб активувати демо-доступ.',
      ApiErrorType.forbidden => 'Демо-доступ недоступний для цього акаунта.',
      ApiErrorType.timeout ||
      ApiErrorType.network =>
        'Не вдалося зв’язатися з сервером. Спробуйте ще раз.',
      _ => 'Не вдалося підтвердити демо-доступ. Спробуйте ще раз.',
    };

/// Loads display data and launches StoreKit / Play Billing. No native purchase
/// result can grant UI access before the billing webhook creates an entitlement.
class NativeStoreCatalogAdapter implements PurchaseAdapter {
  NativeStoreCatalogAdapter({
    required StoreCatalogService catalog,
    required InAppPurchase purchases,
  })  : _catalog = catalog,
        _purchases = purchases;

  final StoreCatalogService _catalog;
  final InAppPurchase _purchases;
  final Map<String, ProductDetails> _products = {};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  Completer<PurchaseOutcome>? _pendingOutcome;

  @override
  Future<PaywallSnapshot> load() async {
    if (!await _purchases.isAvailable()) {
      return const PaywallSnapshot(phase: PaywallPhase.productsUnavailable);
    }
    try {
      final ids = await _catalog.loadStoreProductIds();
      if (ids.isEmpty) {
        return const PaywallSnapshot(phase: PaywallPhase.productsUnavailable);
      }
      final response = await _purchases.queryProductDetails(ids);
      if (response.error != null || response.productDetails.isEmpty) {
        return const PaywallSnapshot(phase: PaywallPhase.productsUnavailable);
      }
      _products
        ..clear()
        ..addEntries(response.productDetails
            .map((detail) => MapEntry(detail.id, detail)));
      _purchaseSubscription ??= _purchases.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (_, __) => _finish(const PurchaseOutcome(PaywallPhase.error)),
      );
      return PaywallSnapshot(
        phase: PaywallPhase.idle,
        products: response.productDetails
            .map((detail) => PurchaseProduct(
                  id: detail.id,
                  title: detail.title,
                  price: detail.price,
                  detail:
                      detail.description.isEmpty ? null : detail.description,
                ))
            .toList(growable: false),
      );
    } catch (_) {
      return const PaywallSnapshot(phase: PaywallPhase.productsUnavailable);
    }
  }

  @override
  Future<PurchaseOutcome> purchase(PurchaseProduct product) async {
    final detail = _products[product.id];
    if (detail == null || _pendingOutcome != null) {
      return const PurchaseOutcome(PaywallPhase.productsUnavailable);
    }
    final pending = _pendingOutcome = Completer<PurchaseOutcome>();
    final launched = await _purchases.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: detail),
    );
    if (!launched) {
      _finish(const PurchaseOutcome(PaywallPhase.error));
    }
    return pending.future;
  }

  @override
  Future<PurchaseOutcome> restore() async {
    if (_pendingOutcome != null) {
      return const PurchaseOutcome(PaywallPhase.purchasing);
    }
    final pending = _pendingOutcome = Completer<PurchaseOutcome>();
    await _purchases.restorePurchases();
    // A store may emit no restored item when nothing is owned. The provider
    // still refreshes the server entitlement, which is the authority.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    _finish(const PurchaseOutcome(
      PaywallPhase.purchasing,
      requiresEntitlementConfirmation: true,
    ));
    return pending.future;
  }

  @override
  Future<void> manageSubscription() async {
    await launchUrl(
      Uri.parse(defaultTargetPlatform == TargetPlatform.iOS
          ? 'https://apps.apple.com/account/subscriptions'
          : 'https://play.google.com/store/account/subscriptions'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (purchase.pendingCompletePurchase) {
        await _purchases.completePurchase(purchase);
      }
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _finish(const PurchaseOutcome(
            PaywallPhase.purchasing,
            requiresEntitlementConfirmation: true,
          ));
        case PurchaseStatus.canceled:
          _finish(const PurchaseOutcome(PaywallPhase.userCancelled));
        case PurchaseStatus.error:
          _finish(PurchaseOutcome(
            PaywallPhase.error,
            message: purchase.error?.message,
          ));
        case PurchaseStatus.pending:
          break;
      }
    }
  }

  void _finish(PurchaseOutcome outcome) {
    final pending = _pendingOutcome;
    if (pending != null && !pending.isCompleted) {
      pending.complete(outcome);
    }
    _pendingOutcome = null;
  }
}
