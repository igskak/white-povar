import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/config/app_config.dart';

/// Fetches server-owned product identifiers. Prices and trial information are
/// intentionally read from the native store SDK, never from this response.
class StoreCatalogService {
  StoreCatalogService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Set<String>> loadStoreProductIds() async {
    final store = defaultTargetPlatform == TargetPlatform.iOS
        ? 'app_store'
        : 'play_store';
    final response = await _client.get(
      Uri.parse('${AppConfig.apiBaseUrl}/api/v1/commerce/store-products?store=$store'),
      headers: {'X-Tenant-Slug': AppConfig.tenantSlug},
    );
    if (response.statusCode != 200) throw StateError('Store catalogue unavailable');
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final products = decoded['products'] as List<dynamic>? ?? const [];
    final ids = products
        .whereType<Map<String, dynamic>>()
        .map((product) => product['storeProductId'])
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    return ids;
  }
}
