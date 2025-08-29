import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Unified error handling service for consistent error management across the app
class ErrorHandler {
  /// Convert various error types to user-friendly messages
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    }
    
    if (error is Exception) {
      return _handleGenericException(error);
    }
    
    // Fallback for unknown error types
    return 'An unexpected error occurred. Please try again.';
  }

  /// Handle Dio HTTP errors with specific user-friendly messages
  static String _handleDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Connection timeout. Please check your internet connection and try again.';
      
      case DioExceptionType.connectionError:
        return 'Unable to connect to the server. Please check your internet connection.';
      
      case DioExceptionType.badResponse:
        return _handleHttpStatusError(e.response?.statusCode, e.response?.data);
      
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      
      case DioExceptionType.badCertificate:
        return 'Security certificate error. Please try again later.';
      
      case DioExceptionType.unknown:
      default:
        return 'Network error occurred. Please try again.';
    }
  }

  /// Handle HTTP status code errors
  static String _handleHttpStatusError(int? statusCode, dynamic responseData) {
    switch (statusCode) {
      case 400:
        return _extractDetailFromResponse(responseData) ?? 'Invalid request. Please check your input.';
      
      case 401:
        return 'Authentication required. Please log in again.';
      
      case 403:
        return 'Access denied. You don\'t have permission to perform this action.';
      
      case 404:
        return 'The requested resource was not found.';
      
      case 409:
        return 'Conflict occurred. The resource may have been modified by another user.';
      
      case 422:
        return _extractDetailFromResponse(responseData) ?? 'Invalid data provided. Please check your input.';
      
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      
      case 500:
      case 502:
      case 503:
      case 504:
        return 'Server error occurred. Please try again later.';
      
      default:
        return _extractDetailFromResponse(responseData) ?? 'An error occurred. Please try again.';
    }
  }

  /// Handle generic exceptions
  static String _handleGenericException(Exception e) {
    final message = e.toString();
    
    // Remove common exception prefixes for cleaner user messages
    if (message.startsWith('Exception: ')) {
      return message.substring(11);
    }
    
    if (message.startsWith('FormatException: ')) {
      return 'Invalid data format received. Please try again.';
    }
    
    if (message.startsWith('TimeoutException: ')) {
      return 'Operation timed out. Please try again.';
    }
    
    return message.isNotEmpty ? message : 'An unexpected error occurred.';
  }

  /// Extract error detail from API response
  static String? _extractDetailFromResponse(dynamic responseData) {
    if (responseData == null) return null;
    
    try {
      if (responseData is Map<String, dynamic>) {
        // Try common error message fields
        return responseData['detail'] ?? 
               responseData['message'] ?? 
               responseData['error'] ??
               responseData['errors']?.toString();
      }
      
      if (responseData is String) {
        return responseData;
      }
    } catch (e) {
      // If parsing fails, return null to use default message
      debugPrint('Error parsing response data: $e');
    }
    
    return null;
  }

  /// Log error for debugging (only in debug mode)
  static void logError(dynamic error, [StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('Error: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }

  /// Check if error is network-related
  static bool isNetworkError(dynamic error) {
    if (error is DioException) {
      return error.type == DioExceptionType.connectionError ||
             error.type == DioExceptionType.connectionTimeout ||
             error.type == DioExceptionType.receiveTimeout ||
             error.type == DioExceptionType.sendTimeout;
    }
    return false;
  }

  /// Check if error is authentication-related
  static bool isAuthError(dynamic error) {
    if (error is DioException && error.response?.statusCode != null) {
      return error.response!.statusCode == 401 || error.response!.statusCode == 403;
    }
    return false;
  }

  /// Check if error is server-related
  static bool isServerError(dynamic error) {
    if (error is DioException && error.response?.statusCode != null) {
      final statusCode = error.response!.statusCode!;
      return statusCode >= 500 && statusCode < 600;
    }
    return false;
  }

  /// Get retry-able status for an error
  static bool isRetryable(dynamic error) {
    if (isNetworkError(error) || isServerError(error)) {
      return true;
    }
    
    if (error is DioException && error.response?.statusCode == 429) {
      return true; // Rate limited - can retry after delay
    }
    
    return false;
  }
}

/// Error types for categorizing errors
enum ErrorType {
  network,
  authentication,
  validation,
  server,
  unknown,
}

/// Structured error information
class AppError {
  final String message;
  final ErrorType type;
  final String? code;
  final bool isRetryable;
  final dynamic originalError;

  const AppError({
    required this.message,
    required this.type,
    this.code,
    this.isRetryable = false,
    this.originalError,
  });

  factory AppError.fromException(dynamic error) {
    final message = ErrorHandler.getErrorMessage(error);
    final isRetryable = ErrorHandler.isRetryable(error);
    
    ErrorType type = ErrorType.unknown;
    String? code;
    
    if (ErrorHandler.isNetworkError(error)) {
      type = ErrorType.network;
    } else if (ErrorHandler.isAuthError(error)) {
      type = ErrorType.authentication;
    } else if (ErrorHandler.isServerError(error)) {
      type = ErrorType.server;
    } else if (error is DioException && error.response?.statusCode != null) {
      final statusCode = error.response!.statusCode!;
      if (statusCode >= 400 && statusCode < 500) {
        type = ErrorType.validation;
      }
      code = statusCode.toString();
    }
    
    return AppError(
      message: message,
      type: type,
      code: code,
      isRetryable: isRetryable,
      originalError: error,
    );
  }

  @override
  String toString() => message;
}
