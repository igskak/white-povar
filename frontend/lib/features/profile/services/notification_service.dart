import '../../../core/api/api_client.dart';
import '../models/notification_preferences.dart';

class NotificationService {
  const NotificationService(this._apiClient);
  final ApiClient _apiClient;

  Future<NotificationPreferences> get() async {
    final response = await _apiClient
        .get<Map<String, dynamic>>('/api/v1/lifecycle/me/preferences');
    return NotificationPreferences.fromJson(response.data!);
  }

  Future<NotificationPreferences> save(
      NotificationPreferences preferences) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/api/v1/lifecycle/me/preferences',
      data: preferences.toJson(),
    );
    return NotificationPreferences.fromJson(response.data!);
  }

  /// Revokes every token for this user in the resolved tenant before logout.
  Future<void> unregisterDevices() =>
      _apiClient.delete<void>('/api/v1/lifecycle/me/devices');
}
