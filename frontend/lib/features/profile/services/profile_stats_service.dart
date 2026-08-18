import '../../../core/api/api_client.dart';
import '../models/profile_stats.dart';

class ProfileStatsService {
  const ProfileStatsService(this._apiClient);
  final ApiClient _apiClient;

  Future<ProfileStats> get() async {
    final response =
        await _apiClient.get<Map<String, dynamic>>('/api/v1/auth/me/stats');
    return ProfileStats.fromJson(response.data!);
  }
}
