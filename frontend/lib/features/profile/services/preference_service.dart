import '../../../core/api/api_client.dart';
import '../models/preference_profile.dart';

class PreferenceService {
  const PreferenceService(this._apiClient);
  final ApiClient _apiClient;

  Future<PreferenceProfile> get() async {
    final response = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/auth/me/preferences');
    return PreferenceProfile.fromJson(response.data!);
  }

  Future<PreferenceProfile> save(PreferenceProfile profile) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/auth/me/preferences',
      data: profile.toJson(),
    );
    return PreferenceProfile.fromJson(response.data!);
  }

  Future<void> reset() =>
      _apiClient.delete<void>('/api/v1/auth/me/preferences');
}
