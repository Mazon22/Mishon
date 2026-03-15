import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'exceptions.dart';

class ApiClient {
  static const _connectivityCacheTtl = Duration(seconds: 3);

  final Dio _dio;
  final SecureStorage _storage;
  final _logger = Logger();
  final _connectivity = Connectivity();

  bool _isRefreshing = false;
  bool? _lastConnectivityResult;
  DateTime? _lastConnectivityCheckAt;
  Future<bool>? _pendingConnectivityCheck;
  final _requestQueue = <_QueuedRequest>[];

  ApiClient({required SecureStorage storage})
    : _storage = storage,
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
    final isPublicEndpoint = _isPublicEndpoint(options.path);

    try {
      final hasConnection = await _hasConnection();
      if (!hasConnection) {
        _logger.w(
          'No internet connection for ${options.method} ${options.path}',
        );
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: OfflineException(),
          ),
        );
        return;
      }

      if (!isPublicEndpoint) {
        final isExpired =
            _storage.isCacheHydrated
                ? _storage.isAccessTokenExpiredSync()
                : await _storage.isAccessTokenExpired();

        if (isExpired) {
          _logger.w('Access token expired, attempting refresh');
          final refreshed = await _refreshToken();
          if (!refreshed) {
            await _storage.clear();
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.unknown,
                error: TokenExpiredException(),
              ),
            );
            return;
          }
        }

        final token = _storage.cachedToken ?? await _storage.readToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      }

      if (options.data is FormData) {
        options.headers.remove('Content-Type');
      }

      _logger.d('Request: ${options.method} ${options.path}');
      handler.next(options);
    } catch (e, st) {
      _logger.e(
        'Request preparation failed for ${options.method} ${options.path}',
        error: e,
        stackTrace: st,
      );
      handler.next(options);
    }
  }

  Future<void> _handleError(
    DioException error,
    ErrorInterceptorHandler handler,
  ) async {
    _logger.e('Error: ${error.type} - ${error.message}');

    if (error.response?.statusCode == 401 &&
        !_isPublicEndpoint(error.requestOptions.path)) {
      final tokenExpired =
          error.response?.headers.value('Token-Expired') == 'true';

      if (tokenExpired) {
        if (_isRefreshing) {
          _requestQueue.add(
            _QueuedRequest(
              options: error.requestOptions,
              resolve: handler.resolve,
              reject: handler.reject,
            ),
          );
          return;
        }

        _isRefreshing = true;
        try {
          final refreshed = await _refreshToken();
          if (refreshed) {
            await _replayQueuedRequests();
            final retryOptions = error.requestOptions;
            final newToken = _storage.cachedToken ?? await _storage.readToken();
            if (newToken != null && newToken.isNotEmpty) {
              retryOptions.headers['Authorization'] = 'Bearer $newToken';
            }
            handler.resolve(await _retry(retryOptions));
            return;
          }

          await _storage.clear();
          final tokenExpiredError = DioException(
            requestOptions: error.requestOptions,
            type: DioExceptionType.badResponse,
            error: TokenExpiredException(),
            response: error.response,
          );
          _rejectQueuedRequests(tokenExpiredError);
        } finally {
          _isRefreshing = false;
        }
      } else {
        await _storage.clear();
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      handler.reject(
        DioException(
          requestOptions: error.requestOptions,
          type: error.type,
          error: OfflineException.timeout(),
        ),
      );
      return;
    }

    if (error.type == DioExceptionType.connectionError) {
      handler.reject(
        DioException(
          requestOptions: error.requestOptions,
          type: error.type,
          error: OfflineException(),
        ),
      );
      return;
    }

    if (error.response?.data != null) {
      try {
        final apiError = ApiError.fromJson(error.response!.data);
        handler.reject(
          DioException(
            requestOptions: error.requestOptions,
            type: error.type,
            error: ApiException(
              apiError,
              statusCode: error.response?.statusCode,
            ),
            response: error.response,
          ),
        );
        return;
      } catch (_) {
        // Fall through to the original Dio error when the payload
        // does not match the shared API error shape.
      }
    }

    handler.next(error);
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

  bool _isPublicEndpoint(String path) {
    return path.contains('/auth/register') ||
        path.contains('/auth/login') ||
        path.contains('/auth/refresh-token');
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken =
          _storage.cachedRefreshToken ?? await _storage.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        _logger.w('No refresh token available');
        return false;
      }

      final isRefreshExpired =
          _storage.isCacheHydrated
              ? _storage.isRefreshTokenExpiredSync()
              : await _storage.isRefreshTokenExpired();
      if (isRefreshExpired) {
        _logger.w('Refresh token expired');
        return false;
      }

      final response = await _dio.post(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      if (response.statusCode != 200) {
        return false;
      }

      final data = response.data as Map<String, dynamic>;
      await _storage.writeToken(data['token'] as String);

      if (data['refreshToken'] is String &&
          (data['refreshToken'] as String).isNotEmpty) {
        await _storage.writeRefreshToken(data['refreshToken'] as String);
      }

      if (data['refreshTokenExpiry'] is String) {
        await _storage.writeRefreshTokenExpiry(
          DateTime.parse(data['refreshTokenExpiry'] as String),
        );
      }

      await _storage.writeAccessTokenExpiry(
        DateTime.now().add(const Duration(minutes: 15)),
      );

      _logger.i('Token refreshed successfully');
      return true;
    } catch (e, st) {
      _logger.e('Token refresh failed', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> _replayQueuedRequests() async {
    if (_requestQueue.isEmpty) {
      return;
    }

    final queuedRequests = List<_QueuedRequest>.from(_requestQueue);
    _requestQueue.clear();

    for (final request in queuedRequests) {
      try {
        request.resolve(await _retry(request.options));
      } on DioException catch (dioError) {
        request.reject(dioError);
      }
    }
  }

  void _rejectQueuedRequests(DioException error) {
    if (_requestQueue.isEmpty) {
      return;
    }

    final queuedRequests = List<_QueuedRequest>.from(_requestQueue);
    _requestQueue.clear();

    for (final request in queuedRequests) {
      request.reject(error);
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) {
    return _dio.fetch<dynamic>(requestOptions);
  }
}

class _QueuedRequest {
  final RequestOptions options;
  final void Function(Response<dynamic>) resolve;
  final void Function(DioException) reject;

  _QueuedRequest({
    required this.options,
    required this.resolve,
    required this.reject,
  });
}
