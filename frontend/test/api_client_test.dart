import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_error.dart';

void main() {
  test('adds tenant, locale and request ID headers without a guest token',
      () async {
    final adapter = _RecordingAdapter();
    final client = _client(adapter, token: null);

    await client.get<Map<String, dynamic>>('/recipes');

    expect(adapter.request.headers['X-Tenant-Slug'], 'ohorodnik-oleksandr');
    expect(adapter.request.headers['Accept-Language'], 'uk');
    expect(adapter.request.headers['X-Request-ID'], isNotEmpty);
    expect(adapter.request.headers, isNot(contains('Authorization')));
  });

  test('adds the bearer token only when an authenticated token exists',
      () async {
    final adapter = _RecordingAdapter();
    final client = _client(adapter, token: 'token-123');

    await client.get<Map<String, dynamic>>('/recipes');

    expect(adapter.request.headers['Authorization'], 'Bearer token-123');
  });

  test('maps API and network failures to typed errors', () async {
    for (final entry in {
      401: ApiErrorType.unauthorized,
      403: ApiErrorType.forbidden,
      404: ApiErrorType.notFound,
      409: ApiErrorType.conflict,
    }.entries) {
      final client =
          _client(_RecordingAdapter(statusCode: entry.key), token: null);
      await expectLater(
        client.get<Map<String, dynamic>>('/recipes'),
        throwsA(
            isA<ApiError>().having((error) => error.type, 'type', entry.value)),
      );
    }

    final networkClient =
        _client(_RecordingAdapter(networkError: true), token: null);
    await expectLater(
      networkClient.get<Map<String, dynamic>>('/recipes'),
      throwsA(isA<ApiError>()
          .having((error) => error.type, 'type', ApiErrorType.network)),
    );
  });
}

ApiClient _client(_RecordingAdapter adapter, {required String? token}) {
  return ApiClient(
    dio: Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter,
    tokenProvider: () async => token,
    tenantSlug: 'ohorodnik-oleksandr',
    locale: 'uk',
  );
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.statusCode = 200, this.networkError = false});

  final int statusCode;
  final bool networkError;
  late RequestOptions request;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (networkError) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return ResponseBody.fromString(
      jsonEncode({'detail': 'failure'}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
