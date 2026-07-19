import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/branding/brand_providers.dart';
import '../../features/auth/services/auth_service.dart';
import 'api_error.dart';
import 'auth_interceptor.dart';

class ApiClient {
  ApiClient({
    String? baseUrl,
    required AuthTokenProvider tokenProvider,
    required String tenantSlug,
    required String locale,
    Dio? dio,
    Duration connectTimeout = const Duration(seconds: 20),
    Duration receiveTimeout = const Duration(seconds: 20),
    Duration sendTimeout = const Duration(seconds: 20),
    List<Duration> getRetryDelays = const [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
    ],
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
                connectTimeout: connectTimeout,
                receiveTimeout: receiveTimeout,
                sendTimeout: sendTimeout,
                headers: {
                  'Content-Type': 'application/json',
                  'Accept-Language': locale,
                },
              ),
            ),
        _getRetryDelays = getRetryDelays {
    _dio.interceptors.add(
      RequestContextInterceptor(
        tokenProvider: tokenProvider,
        tenantSlug: tenantSlug,
        locale: locale,
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: false,
          requestHeader: false,
        ),
      );
    }
  }

  final Dio _dio;
  final List<Duration> _getRetryDelays;

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool retryTransient = true,
  }) async {
    for (var attempt = 0;; attempt++) {
      try {
        return await _guard(() => _dio.get<T>(
              path,
              queryParameters: queryParameters,
              options: options,
              cancelToken: cancelToken,
            ));
      } on ApiError catch (error) {
        if (!retryTransient ||
            !_isTransientGetFailure(error) ||
            attempt >= _getRetryDelays.length) {
          rethrow;
        }
        await Future<void>.delayed(_getRetryDelays[attempt]);
      }
    }
  }

  bool _isTransientGetFailure(ApiError error) =>
      error.type == ApiErrorType.network ||
      error.type == ApiErrorType.timeout ||
      (error.type == ApiErrorType.server &&
          (error.statusCode == 502 ||
              error.statusCode == 503 ||
              error.statusCode == 504));

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _guard(() => _dio.post<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ));
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _guard(() => _dio.put<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ));
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _guard(() => _dio.delete<T>(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
          cancelToken: cancelToken,
        ));
  }

  Future<Response<T>> _guard<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    } catch (error) {
      throw ApiError.unknown(error);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final bootstrap = ref.watch(tenantBootstrapProvider);
  return ApiClient(
    tokenProvider: AuthService().getIdToken,
    tenantSlug: bootstrap.tenantSlug,
    locale: bootstrap.brandConfig.locale,
  );
});
