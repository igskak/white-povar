import 'package:dio/dio.dart';

/// Unified API error contract for V2 network layer.
enum ApiErrorType {
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  server,
  timeout,
  network,
  cancelled,
  unknown,
}

class ApiError implements Exception {
  const ApiError({
    required this.type,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final ApiErrorType type;
  final String message;
  final int? statusCode;
  final Object? cause;

  bool get isAuthError =>
      type == ApiErrorType.unauthorized || type == ApiErrorType.forbidden;

  factory ApiError.fromDioException(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final responseMessage = _extractResponseMessage(response?.data);

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiError(
          type: ApiErrorType.timeout,
          statusCode: statusCode,
          message: responseMessage ?? 'Request timed out. Please try again.',
          cause: error,
        );
      case DioExceptionType.badResponse:
        return ApiError(
          type: _mapStatusCodeToType(statusCode),
          statusCode: statusCode,
          message: responseMessage ?? _defaultMessageByStatus(statusCode),
          cause: error,
        );
      case DioExceptionType.cancel:
        return ApiError(
          type: ApiErrorType.cancelled,
          statusCode: statusCode,
          message: 'Request was cancelled.',
          cause: error,
        );
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return ApiError(
          type: ApiErrorType.network,
          statusCode: statusCode,
          message: responseMessage ?? 'Network error. Check your connection.',
          cause: error,
        );
      case DioExceptionType.badCertificate:
        return ApiError(
          type: ApiErrorType.unknown,
          statusCode: statusCode,
          message: responseMessage ?? 'Security error while connecting to API.',
          cause: error,
        );
    }
  }

  factory ApiError.unknown(Object error) {
    return ApiError(
      type: ApiErrorType.unknown,
      message: 'Unexpected error occurred.',
      cause: error,
    );
  }

  static ApiErrorType _mapStatusCodeToType(int? statusCode) {
    switch (statusCode) {
      case 400:
        return ApiErrorType.badRequest;
      case 401:
        return ApiErrorType.unauthorized;
      case 403:
        return ApiErrorType.forbidden;
      case 404:
        return ApiErrorType.notFound;
      case 409:
        return ApiErrorType.conflict;
      default:
        if ((statusCode ?? 0) >= 500) {
          return ApiErrorType.server;
        }
        return ApiErrorType.unknown;
    }
  }

  static String _defaultMessageByStatus(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request.';
      case 401:
        return 'Authentication required.';
      case 403:
        return 'You do not have access to this resource.';
      case 404:
        return 'Requested resource was not found.';
      case 409:
        return 'Conflict while processing request.';
      default:
        if ((statusCode ?? 0) >= 500) {
          return 'Server error. Please try again later.';
        }
        return 'Request failed.';
    }
  }

  static String? _extractResponseMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      final message = data['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
      final error = data['error'];
      if (error is String && error.isNotEmpty) {
        return error;
      }
    }
    if (data is String && data.isNotEmpty) {
      return data;
    }
    return null;
  }

  @override
  String toString() {
    return 'ApiError(type: $type, statusCode: $statusCode, message: $message)';
  }
}
