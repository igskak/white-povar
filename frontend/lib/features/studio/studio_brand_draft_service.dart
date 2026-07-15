import '../../core/api/api_client.dart';
import '../../core/branding/brand_config.dart';

class StudioBrandDraft {
  const StudioBrandDraft({required this.config, required this.version});

  final BrandConfig config;
  final int version;

  factory StudioBrandDraft.fromJson(Map<String, dynamic> json) =>
      StudioBrandDraft(
        config: BrandConfig.fromJson(
            Map<String, dynamic>.from(json['config'] as Map)),
        version: json['version'] as int,
      );
}

class StudioBrandDraftService {
  StudioBrandDraftService(this._client);
  final ApiClient _client;

  Future<StudioBrandDraft> load() async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/v1/studio/brand-draft');
    return StudioBrandDraft.fromJson(response.data!);
  }

  Future<StudioBrandDraft> save(StudioBrandDraft draft) async {
    final response = await _client.put<Map<String, dynamic>>(
      '/api/v1/studio/brand-draft',
      data: {'config': draft.config.toJson(), 'expectedVersion': draft.version},
    );
    return StudioBrandDraft.fromJson(response.data!);
  }
}
