import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/subscription/purchase_adapter.dart';

void main() {
  test('retries a transient wake failure before hiding demo offers', () async {
    final adapter = _CatalogueAdapter([503, 200]);
    final client = ApiClient(
      dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter,
      tokenProvider: () async => 'buyer-token',
      tenantSlug: 'ohorodnik-oleksandr',
      locale: 'uk',
    );

    final snapshot = await WebDemoPurchaseAdapter(client).load();

    expect(adapter.calls, 2);
    expect(snapshot.phase, PaywallPhase.idle);
    expect(snapshot.products, hasLength(1));
    expect(snapshot.products.single.id, 'demo-monthly');
  });
}

class _CatalogueAdapter implements HttpClientAdapter {
  _CatalogueAdapter(this.statuses);

  final List<int> statuses;
  int calls = 0;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final status = statuses[calls++];
    final body = status == 200
        ? {
            'commerceMode': 'demo',
            'demoPurchaseAvailable': true,
            'offers': [
              {
                'offerKey': 'demo-monthly',
                'title': 'Щомісячний доступ',
                'amountMinor': 0,
                'currency': 'EUR',
                'billingPeriod': 'P1M',
                'productKind': 'subscription',
                'accessScope': 'tenant',
                'collectionIds': [],
              },
            ],
          }
        : {'detail': 'wake in progress'};
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
