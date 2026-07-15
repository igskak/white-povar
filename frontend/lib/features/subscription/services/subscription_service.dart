import '../../../core/api/api_client.dart';
import '../models/subscription.dart';

/// Subscription transport. Authentication and tenant context are supplied by
/// [ApiClient]; callers must never provide or store bearer tokens themselves.
class SubscriptionService {
  SubscriptionService(this._apiClient);

  final ApiClient _apiClient;
  static const _basePath = '/api/v1/subscription';

  Future<SubscriptionStatusResponse> getSubscriptionStatus() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '$_basePath/status',
    );
    return SubscriptionStatusResponse.fromJson(response.data!);
  }

  Future<PremiumAccessCheck> checkPremiumAccess({String? feature}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '$_basePath/check-access',
      queryParameters: feature == null ? null : {'feature': feature},
    );
    return PremiumAccessCheck.fromJson(response.data!);
  }

  Future<Map<String, dynamic>> getAvailableFeatures() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '$_basePath/features',
    );
    return response.data!;
  }

  Future<UpgradePrompt> getUpgradePrompt(String promptType) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '$_basePath/upgrade-prompts/$promptType',
    );
    return UpgradePrompt.fromJson(response.data!);
  }

  Future<Map<String, dynamic>> getSubscriptionTiers() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '$_basePath/tiers',
    );
    return response.data!;
  }
}
