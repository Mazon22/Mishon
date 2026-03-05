import 'package:equatable/equatable.dart';

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
      message: json['message'] ?? 'Произошла неизвестная ошибка',
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

  const ApiException(this.apiError);

  @override
  String toString() => 'ApiException: ${apiError.error} - ${apiError.message}';
}

class OfflineException implements Exception {
  final String message;

  const OfflineException([this.message = 'Отсутствует подключение к интернету']);

  @override
  String toString() => 'OfflineException: $message';
}

class TokenExpiredException implements Exception {
  @override
  String toString() => 'TokenExpiredException: Access token expired';
}

class UnauthorizedException implements Exception {
  final String message;

  const UnauthorizedException([this.message = 'Неавторизованный доступ']);

  @override
  String toString() => 'UnauthorizedException: $message';
}

class ValidationException implements Exception {
  final Map<String, String> errors;

  const ValidationException(this.errors);

  @override
  String toString() => 'ValidationException: $errors';
}
