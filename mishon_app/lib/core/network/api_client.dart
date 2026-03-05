import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logger/logger.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';
import 'exceptions.dart';

class ApiClient {
  final Dio _dio;
  final SecureStorage _storage;
  final _logger = Logger();
  final _connectivity = Connectivity();

  bool _isRefreshing = false;
  final _requestQueue = <_QueuedRequest>[];

  ApiClient({required SecureStorage storage})
      : _storage = storage,
        _dio = Dio(BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: ApiConstants.connectTimeout,
          receiveTimeout: ApiConstants.receiveTimeout,
          sendTimeout: ApiConstants.sendTimeout,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Пропускаем public endpoints без проверки токена
        final isPublicEndpoint = options.path.contains('/auth/register') ||
            options.path.contains('/auth/login') ||
            options.path.contains('/auth/refresh-token');
        
        if (isPublicEndpoint) {
          _logger.d('Public endpoint: ${options.method} ${options.path}');
          return handler.next(options);
        }
        
        // Проверка подключения
        try {
          final connectivityResults = await _connectivity.checkConnectivity();
          // connectivity_plus 5.x возвращает List<ConnectivityResult> на мобильных
          // и ConnectivityResult на web
          bool hasConnection = false;
          
          // Проверяем тип через runtimeType для web/mobile
          final isList = connectivityResults.runtimeType.toString().startsWith('List<');
          
          if (isList) {
            // Мобильные - список результатов
            final resultsList = connectivityResults as List;
            for (final result in resultsList) {
              if (result == ConnectivityResult.none) {
                continue;
              }
              hasConnection = true;
              break;
            }
          } else {
            // Web - одиночный результат
            hasConnection = connectivityResults != ConnectivityResult.none;
          }
          
          if (!hasConnection) {
            _logger.w('No internet connection');
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError,
                error: const OfflineException(),
              ),
            );
          }
        } catch (e) {
          _logger.e('Connectivity check failed', error: e);
          // Продолжаем запрос при ошибке проверки подключения
        }

        // Проверка истечения access токена
        final isExpired = await _storage.isAccessTokenExpired();
        if (isExpired) {
          _logger.w('Access token expired, attempting refresh');
          final refreshed = await _refreshToken();
          if (!refreshed) {
            await _storage.clear();
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.unknown,
                error: TokenExpiredException(),
              ),
            );
          }
        }

        // Добавляем токен
        final token = await _storage.readToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }

        // Не переопределяем Content-Type для multipart запросов
        // Dio автоматически установит правильный Content-Type с boundary
        if (options.data is FormData) {
          options.headers.remove('Content-Type');
        }

        _logger.d('Request: ${options.method} ${options.path}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        _logger.d('Response: ${response.statusCode} ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (error, handler) async {
        _logger.e('Error: ${error.type} - ${error.message}');

        // Обработка 401
        if (error.response?.statusCode == 401) {
          final tokenExpired = error.response?.headers.value('Token-Expired') == 'true';

          if (tokenExpired && !_isRefreshing) {
            _isRefreshing = true;
            try {
              final refreshed = await _refreshToken();
              if (refreshed) {
                // Повтор запроса
                final retryOptions = error.requestOptions;
                final newToken = await _storage.readToken();
                if (newToken != null) {
                  retryOptions.headers['Authorization'] = 'Bearer $newToken';
                }

                // Повторяем запросы из очереди
                for (var request in _requestQueue) {
                  request.resolve(await _retry(request.options));
                }
                _requestQueue.clear();

                return handler.resolve(await _retry(retryOptions));
              }
            } finally {
              _isRefreshing = false;
            }
          } else if (!_isRefreshing) {
            // Токен не обновился — очищаем и выбрасываем
            await _storage.clear();
          } else {
            // Добавляем в очередь
            _requestQueue.add(_QueuedRequest(
              options: error.requestOptions,
              resolve: handler.resolve,
              reject: handler.reject,
            ));
            return;
          }
        }

        // Преобразование ошибок
        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.sendTimeout) {
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              type: error.type,
              error: const OfflineException('Таймаут соединения'),
            ),
          );
        }

        if (error.type == DioExceptionType.connectionError) {
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              type: error.type,
              error: const OfflineException(),
            ),
          );
        }

        // Парсинг ответа сервера
        if (error.response?.data != null) {
          try {
            final apiError = ApiError.fromJson(error.response!.data);
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                type: error.type,
                error: ApiException(apiError, statusCode: error.response?.statusCode),
                response: error.response,
              ),
            );
          } catch (_) {
            // Не удалось распарсить
          }
        }

        return handler.next(error);
      },
    ));
  }

  Dio get dio => _dio;

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.readRefreshToken();
      if (refreshToken == null) {
        _logger.w('No refresh token available');
        return false;
      }

      // Проверяем не истёк ли refresh токен
      final isRefreshExpired = await _storage.isRefreshTokenExpired();
      if (isRefreshExpired) {
        _logger.w('Refresh token expired');
        return false;
      }

      final response = await _dio.post('/auth/refresh-token', data: {
        'refreshToken': refreshToken,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        await _storage.writeToken(data['token']);
        
        // Сохраняем refresh token если он обновился
        if (data['refreshToken'] != null) {
          await _storage.writeRefreshToken(data['refreshToken']);
        }
        
        // Сохраняем expiry refresh токена
        if (data['refreshTokenExpiry'] != null) {
          await _storage.writeRefreshTokenExpiry(DateTime.parse(data['refreshTokenExpiry']));
        }
        
        // Access token expires через 15 минут
        await _storage.writeAccessTokenExpiry(DateTime.now().add(const Duration(minutes: 15)));
        
        _logger.i('Token refreshed successfully');
        return true;
      }
      return false;
    } catch (e, st) {
      _logger.e('Token refresh failed', error: e, stackTrace: st);
      return false;
    }
  }

  Future<Response> _retry(RequestOptions requestOptions) async {
    return await _dio.fetch(requestOptions);
  }
}

class _QueuedRequest {
  final RequestOptions options;
  final void Function(Response) resolve;
  final void Function(DioException) reject;

  _QueuedRequest({
    required this.options,
    required this.resolve,
    required this.reject,
  });
}
