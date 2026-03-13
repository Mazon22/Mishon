import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';

bool get _isRuLocale => Intl.getCurrentLocale().toLowerCase().startsWith('ru');

class ApiError extends Equatable {
  final String error;
  final String message;
  final int? statusCode;
  final DateTime? timestamp;

  const ApiError({
    required this.error,
    required this.message,
    this.statusCode,
    this.timestamp,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) {
    return ApiError(
      error: json['error'] ?? 'Unknown Error',
      message:
          json['message'] ??
          (_isRuLocale
              ? 'Произошла неизвестная ошибка'
              : 'An unknown error occurred'),
      statusCode: json['statusCode'],
      timestamp: json['timestamp'] != null 
          ? DateTime.parse(json['timestamp']).toLocal() 
          : null,
    );
  }

  @override
  List<Object?> get props => [error, message, statusCode, timestamp];
}

class ApiException implements Exception {
  final ApiError apiError;
  final int? statusCode;

  const ApiException(this.apiError, {this.statusCode});

  @override
  String toString() => 'ApiException: ${apiError.error} - ${apiError.message} (Status: ${statusCode ?? 'N/A'})';
}

class OfflineException implements Exception {
  final String message;

  OfflineException([String? message])
    : message =
          message ??
          (_isRuLocale
              ? 'Отсутствует подключение к интернету'
              : 'No internet connection');

  OfflineException.timeout([String? message])
    : message =
          message ??
          (_isRuLocale ? 'Таймаут соединения' : 'Connection timed out');

  @override
  String toString() => 'OfflineException: $message';
}

class TokenExpiredException implements Exception {
  @override
  String toString() => 'TokenExpiredException: Access token expired';
}

class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException([String? message])
    : message =
          message ?? (_isRuLocale ? 'Неавторизованный доступ' : 'Unauthorized access');

  @override
  String toString() => 'UnauthorizedException: $message';
}

class ValidationException implements Exception {
  final Map<String, String> errors;

  const ValidationException(this.errors);

  @override
  String toString() => 'ValidationException: $errors';
}
