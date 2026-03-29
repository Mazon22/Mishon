import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../auth/auth_session_support.dart';
import '../constants/api_constants.dart';
import '../models/auth_model.dart';
import '../providers/auth_session_events.dart';
import '../storage/secure_storage.dart';
import 'exceptions.dart';

class ApiClient {
  static const _connectivityCacheTtl = Duration(seconds: 3);

  final Dio _dio;
  final SecureStorage _storage;
  final AuthSessionEvents _authSessionEvents;
  final _logger = Logger();
  final _connectivity = Connectivity();

  bool? _lastConnectivityResult;
  DateTime? _lastConnectivityCheckAt;
  Future<bool>? _pendingConnectivityCheck;
  Future<bool>? _refreshOperation;

  ApiClient({
    required SecureStorage storage,
    required AuthSessionEvents authSessionEvents,
  }) : _storage = storage,
       _authSessionEvents = authSessionEvents,
       _dio = Dio(
         BaseOptions(
           baseUrl: ApiConstants.baseUrl,
           connectTimeout: ApiConstants.connectTimeout,
           receiveTimeout: ApiConstants.receiveTimeout,
           sendTimeout: ApiConstants.sendTimeout,
           headers: {
             'Content-Type': 'application/json',
             'Accept': 'application/json',
           },
         ),
       ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _handleRequest,
        onResponse: (response, handler) {
          _logger.d(
            'Response: ${response.statusCode} ${response.requestOptions.path}',
          );
          handler.next(response);
        },
        onError: _handleError,
      ),
    );
  }

  Dio get dio => _dio;

  Future<void> _handleRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final hasConnection = await _hasConnection();
      if (!hasConnection) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: OfflineException(),
          ),
        );
        return;
      }

      if (!_isPublicEndpoint(options)) {
        await _storage.warmup();

        final token = _storage.cachedToken;
        if (token == null || token.isEmpty) {
          handler.next(options);
          return;
        }

        if (_storage.isAccessTokenExpiredSync()) {
          final refreshed = await _ensureFreshAccessToken();
          if (!refreshed) {
            await _invalidateSession();
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                error: TokenExpiredException(),
              ),
            );
            return;
          }
        }

        final effectiveToken = _storage.cachedToken ?? await _storage.readToken();
        if (effectiveToken != null && effectiveToken.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $effectiveToken';
        }
      }

      if (options.data is FormData) {
        options.headers.remove('Content-Type');
      }

      _logger.d('Request: ${options.method} ${options.path}');
      handler.next(options);
    } on DioException catch (error) {
      handler.reject(error);
    } catch (error, stackTrace) {
      _logger.e(
        'Request preparation failed for ${options.method} ${options.path}',
        error: error,
        stackTrace: stackTrace,
      );
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: error,
        ),
      );
    }
  }

  Future<void> _handleError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = error.response?.statusCode ?? 0;
    final isRefreshRequest = error.requestOptions.extra['isRefreshRequest'] == true;
    final isRecoverableRefreshRejection =
        isRefreshRequest && (statusCode == 400 || statusCode == 401 || statusCode == 403);

    if (isRecoverableRefreshRejection) {
      _logger.w('Refresh token rejected by backend');
    } else {
      _logger.e('Error: ${error.type} - ${error.message}');
    }

    final shouldTryRefresh =
        statusCode == 401 &&
        !_isPublicEndpoint(error.requestOptions) &&
        error.requestOptions.extra['authRetryAttempted'] != true &&
        error.requestOptions.extra['isRefreshRequest'] != true;

    if (shouldTryRefresh) {
      try {
        final refreshed = await _ensureFreshAccessToken();
        if (refreshed) {
          final retryOptions = error.requestOptions.copyWith(
            headers: Map<String, dynamic>.from(error.requestOptions.headers),
            extra: <String, dynamic>{
              ...error.requestOptions.extra,
              'authRetryAttempted': true,
            },
          );
          final token = _storage.cachedToken ?? await _storage.readToken();
          if (token != null && token.isNotEmpty) {
            retryOptions.headers['Authorization'] = 'Bearer $token';
          }
          handler.resolve(await _retry(retryOptions));
          return;
        }

        await _invalidateSession();
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            type: DioExceptionType.badResponse,
            error: TokenExpiredException(),
            response: error.response,
          ),
        );
        return;
      } on DioException catch (refreshError) {
        handler.reject(_mapDioException(refreshError));
        return;
      }
    }

    if (statusCode == 401 &&
        !_isPublicEndpoint(error.requestOptions) &&
        error.requestOptions.extra['isRefreshRequest'] == true) {
      await _invalidateSession();
    }

    handler.next(_mapDioException(error));
  }

  Future<bool> _hasConnection() async {
    final now = DateTime.now();
    final lastCheckAt = _lastConnectivityCheckAt;
    if (_lastConnectivityResult != null &&
        lastCheckAt != null &&
        now.difference(lastCheckAt) <= _connectivityCacheTtl) {
      return _lastConnectivityResult!;
    }

    final pendingCheck = _pendingConnectivityCheck;
    if (pendingCheck != null) {
      return pendingCheck;
    }

    final future = _resolveConnectivity();
    _pendingConnectivityCheck = future;
    try {
      final result = await future;
      _lastConnectivityResult = result;
      _lastConnectivityCheckAt = DateTime.now();
      return result;
    } finally {
      _pendingConnectivityCheck = null;
    }
  }

  Future<bool> _resolveConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  bool _isPublicEndpoint(RequestOptions options) {
    if (options.extra['skipAuth'] == true) {
      return true;
    }

    final path = options.path;
    return path.contains('/auth/register') ||
        path.contains('/auth/login') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/refresh-token') ||
        path.contains('/auth/verify-email') ||
        path.contains('/auth/resend-verification') ||
        path.contains('/auth/forgot-password') ||
        path.contains('/auth/reset-password');
  }

  Future<bool> _ensureFreshAccessToken() {
    final currentOperation = _refreshOperation;
    if (currentOperation != null) {
      return currentOperation;
    }

    final operation = _refreshToken().whenComplete(() {
      _refreshOperation = null;
    });
    _refreshOperation = operation;
    return operation;
  }

  Future<bool> _refreshToken() async {
    await _storage.warmup();

    final refreshToken =
        _storage.cachedRefreshToken ?? await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      _logger.w('No refresh token available');
      return false;
    }

    if (_storage.isRefreshTokenExpiredSync()) {
      _logger.w('Refresh token expired');
      return false;
    }

    try {
      final response = await _dio.post(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
        options: Options(
          extra: const {'skipAuth': true, 'isRefreshRequest': true},
        ),
      );

      final authResponse = AuthResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
      await persistAuthResponse(_storage, authResponse);
      _logger.i(
        'Token refreshed successfully until ${resolveAccessTokenExpiry(authResponse)}',
      );
      return true;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode ?? 0;
      if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
        _logger.w('Refresh token rejected by backend');
        return false;
      }
      rethrow;
    }
  }

  Future<void> _invalidateSession() async {
    await _storage.clearAuthState();
    _authSessionEvents.notifyInvalidated();
  }

  DioException _mapDioException(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return DioException(
        requestOptions: error.requestOptions,
        type: error.type,
        error: OfflineException.timeout(),
        response: error.response,
      );
    }

    if (error.type == DioExceptionType.connectionError) {
      return DioException(
        requestOptions: error.requestOptions,
        type: error.type,
        error: OfflineException(),
        response: error.response,
      );
    }

    if (error.response?.data != null) {
      try {
        final apiError = ApiError.fromJson(error.response!.data);
        return DioException(
          requestOptions: error.requestOptions,
          type: error.type,
          error: ApiException(apiError, statusCode: error.response?.statusCode),
          response: error.response,
        );
      } catch (_) {
        // Fall through to the original Dio error when payload is not shared API shape.
      }
    }

    return error;
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) {
    return _dio.fetch<dynamic>(requestOptions);
  }
}
