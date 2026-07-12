import 'package:dio/dio.dart';

import 'api_error.dart';

typedef AuthTokenProvider = Future<String?> Function();
typedef AuthErrorHandler = Future<void> Function(ApiError error);

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required AuthTokenProvider tokenProvider,
    this.onAuthError,
  }) : _tokenProvider = tokenProvider;

  final AuthTokenProvider _tokenProvider;
  final AuthErrorHandler? onAuthError;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
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
