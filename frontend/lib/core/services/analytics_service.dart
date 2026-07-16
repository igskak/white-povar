import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';

/// The app sends only allowlisted aggregate events; user content never leaves
/// a feature through this service.  The API also enforces consent server-side.
class AnalyticsService {
  AnalyticsService(this._api);
  final ApiClient _api;

  Future<bool> consent() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/api/v1/analytics/me/consent',
    );
    return response.data?['analytics_consent'] == true;
  }

  Future<void> setConsent(bool enabled) => _api.put<void>(
        '/api/v1/analytics/me/consent',
        data: {'analytics_consent': enabled},
      );
}

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(ref.watch(apiClientProvider)),
);
