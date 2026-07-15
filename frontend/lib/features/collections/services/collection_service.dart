import '../../../core/api/api_client.dart';
import '../models/collection.dart';

class CollectionService {
  CollectionService(this._apiClient);
  final ApiClient _apiClient;

  Future<List<ContentCollection>> getCollections(
      {int limit = 20, int offset = 0}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/api/v1/collections/',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final data = response.data;
    if (response.statusCode != 200 || data == null) {
      throw Exception('Не вдалося завантажити колекції');
    }
    return (data['collections'] as List<dynamic>? ?? const [])
        .map((item) => ContentCollection.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ContentCollection> getCollection(String id) async {
    final response =
        await _apiClient.get<Map<String, dynamic>>('/api/v1/collections/$id');
    if (response.statusCode != 200 || response.data == null) {
      throw Exception('Не вдалося завантажити колекцію');
    }
    return ContentCollection.fromJson(response.data!);
  }
}
