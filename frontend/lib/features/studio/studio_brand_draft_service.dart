import '../../core/api/api_client.dart';
import '../../core/branding/brand_config.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';

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

  Future<StudioAsset> upload(PlatformFile file,
      {required String altText}) async {
    final bytes = file.bytes;
    if (bytes == null) {
      throw const FormatException('Не вдалося прочитати файл.');
    }
    final contentType = switch (file.extension?.toLowerCase()) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => throw const FormatException('Підтримуються лише JPG, PNG або WebP.'),
    };
    final ticket = await _client.post<Map<String, dynamic>>(
        '/api/v1/studio/assets/upload-ticket',
        data: {
          'filename': file.name,
          'contentType': contentType,
          'sizeBytes': bytes.length,
        });
    final data = ticket.data!;
    await Dio().put<dynamic>(data['uploadUrl'] as String,
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes,
              filename: file.name, contentType: DioMediaType.parse(contentType))
        }),
        options: Options(contentType: 'multipart/form-data'));
    final finalized = await _client.post<Map<String, dynamic>>(
        '/api/v1/studio/assets/${data['assetId']}/finalize',
        data: {'altText': altText});
    return StudioAsset.fromJson(finalized.data!);
  }

  Future<StudioReleaseStatus> releaseStatus() async {
    final response = await _client
        .get<Map<String, dynamic>>('/api/v1/studio/release-status');
    return StudioReleaseStatus.fromJson(response.data!);
  }

  Future<StudioPublishResult> publish() async {
    final response = await _client
        .post<Map<String, dynamic>>('/api/v1/studio/brand-draft/publish');
    return StudioPublishResult.fromJson(response.data!);
  }

  Future<StudioPublishResult> rollback(int sourceVersion) async {
    final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/studio/brand-config/rollback',
        data: {'sourceVersion': sourceVersion});
    return StudioPublishResult.fromJson(response.data!);
  }

  Future<StudioRelease> requestRelease(
      {required String kind, String? platform}) async {
    final response = await _client.post<Map<String, dynamic>>(
        '/api/v1/studio/releases',
        data: {'kind': kind, if (platform != null) 'platform': platform});
    return StudioRelease.fromJson(response.data!);
  }

  Future<List<StudioContentItem>> content() async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/v1/studio/content');
    return (response.data!['content'] as List<dynamic>? ?? const [])
        .map((value) =>
            StudioContentItem.fromJson(Map<String, dynamic>.from(value as Map)))
        .toList();
  }

  Future<void> publishContent(String id) async =>
      _client.post<Map<String, dynamic>>('/api/v1/studio/content/$id/publish');

  Future<List<StudioCollectionItem>> collections() async {
    final response =
        await _client.get<Map<String, dynamic>>('/api/v1/studio/collections');
    return (response.data!['collections'] as List<dynamic>? ?? const [])
        .map((value) => StudioCollectionItem.fromJson(
            Map<String, dynamic>.from(value as Map)))
        .toList();
  }
}

class StudioContentItem {
  const StudioContentItem(
      {required this.id,
      required this.title,
      required this.kind,
      required this.isPublic,
      required this.isPremium});
  final String id, title, kind;
  final bool isPublic, isPremium;
  factory StudioContentItem.fromJson(Map<String, dynamic> json) =>
      StudioContentItem(
          id: json['id'].toString(),
          title: json['title']?.toString() ?? '',
          kind: json['content_kind']?.toString() ?? 'recipe',
          isPublic: json['is_public'] == true,
          isPremium: json['is_premium'] == true);
}

class StudioCollectionItem {
  const StudioCollectionItem(
      {required this.id,
      required this.title,
      required this.status,
      required this.itemCount});
  final String id, title, status;
  final int itemCount;
  factory StudioCollectionItem.fromJson(Map<String, dynamic> json) {
    final titleI18n = json['title_i18n'];
    final items = json['collection_items'] as List<dynamic>? ?? const [];
    return StudioCollectionItem(
        id: json['id'].toString(),
        title: titleI18n is Map ? (titleI18n['uk']?.toString() ?? '') : '',
        status: json['status']?.toString() ?? 'draft',
        itemCount: items.length);
  }
}

class StudioPublishResult {
  const StudioPublishResult({required this.version});
  final int version;
  factory StudioPublishResult.fromJson(Map<String, dynamic> json) =>
      StudioPublishResult(version: json['version'] as int);
}

class StudioRelease {
  const StudioRelease(
      {required this.id,
      required this.kind,
      required this.status,
      required this.storeStatus,
      required this.configVersion});
  final String id, kind, status, storeStatus;
  final int configVersion;
  factory StudioRelease.fromJson(Map<String, dynamic> json) => StudioRelease(
      id: json['id'] as String,
      kind: json['kind'] as String,
      status: json['status'] as String,
      storeStatus: json['storeReleaseStatus'] as String,
      configVersion: json['configVersion'] as int);
}

class StudioReleaseStatus {
  const StudioReleaseStatus(
      {this.configVersion,
      this.web,
      this.mobile,
      this.store,
      this.history = const []});
  final int? configVersion;
  final StudioRelease? web, mobile, store;
  final List<StudioRelease> history;
  factory StudioReleaseStatus.fromJson(Map<String, dynamic> json) {
    StudioRelease? item(String key) => json[key] == null
        ? null
        : StudioRelease.fromJson(Map<String, dynamic>.from(json[key] as Map));
    final config = json['configPublished'];
    return StudioReleaseStatus(
        configVersion: config is Map ? config['version'] as int? : null,
        web: item('webDeployed'),
        mobile: item('mobileBuild'),
        store: item('storeRelease'),
        history: (json['history'] as List<dynamic>? ?? const [])
            .map((value) =>
                StudioRelease.fromJson(Map<String, dynamic>.from(value as Map)))
            .toList());
  }
}

class StudioAsset {
  const StudioAsset(
      {required this.id,
      required this.url,
      required this.altText,
      required this.width,
      required this.height});
  final String id, url, altText;
  final int? width, height;
  factory StudioAsset.fromJson(Map<String, dynamic> json) => StudioAsset(
      id: json['id'] as String,
      url: json['url'] as String,
      altText: json['altText'] as String,
      width: json['width'] as int?,
      height: json['height'] as int?);
}
