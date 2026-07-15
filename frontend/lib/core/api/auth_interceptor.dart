import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import 'api_error.dart';

typedef AuthTokenProvider = Future<String?> Function();
typedef AuthErrorHandler = Future<void> Function(ApiError error);

class RequestContextInterceptor extends Interceptor {
  RequestContextInterceptor({
    required AuthTokenProvider tokenProvider,
    required String tenantSlug,
    required String locale,
    this.onAuthError,
  })  : _tokenProvider = tokenProvider,
        _tenantSlug = tenantSlug,
        _locale = locale;

  final AuthTokenProvider _tokenProvider;
  final String _tenantSlug;
  final String _locale;
  final AuthErrorHandler? onAuthError;
  final Uuid _uuid = const Uuid();

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['X-Tenant-Slug'] = _tenantSlug;
    options.headers['Accept-Language'] = _locale;
    options.headers['X-Request-ID'] = _uuid.v4();
    final token = await _tokenProvider();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final apiError = ApiError.fromDioException(err);
    if (apiError.isAuthError && onAuthError != null) {
      await onAuthError!(apiError);
    }
    handler.next(err);
  }
}
