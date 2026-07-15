import '../../../core/api/api_client.dart';
import 'purchase_adapter.dart';

/// Reads only the server-issued entitlement. Store results are intentionally
/// not accepted as proof of premium access.
class CommerceEntitlementService {
  CommerceEntitlementService(this._apiClient);

  final ApiClient _apiClient;

  Future<PaywallSnapshot> read() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/commerce/entitlement-status',
    );
    final data = response.data!;
    final status = data['status']?.toString();
    final phase = switch (status) {
      'active' || 'trial' => PaywallPhase.active,
      'grace' => PaywallPhase.grace,
      'billing_retry' => PaywallPhase.billingRetry,
      'cancelled' => PaywallPhase.cancelled,
      'expired' || 'refunded' || 'revoked' => PaywallPhase.expired,
      _ => PaywallPhase.idle,
    };
    return PaywallSnapshot(
      phase: data['hasAccess'] == true ? phase : PaywallPhase.idle,
      renewsOn: DateTime.tryParse(data['expiresAt']?.toString() ?? ''),
    );
  }
}
