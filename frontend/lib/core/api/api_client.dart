import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:zvonilka/core/config/api_config.dart';
import 'package:zvonilka/core/services/auth_service.dart';

// Приватный хелпер-класс для хранения "зависших" запросов
class _RequestToRetry {
  final DioException error;
  final ErrorInterceptorHandler handler;

  _RequestToRetry({required this.error, required this.handler});
}

class ApiClient {
  late Dio _dio;
  final AuthService _authService;
  bool _isRefreshing = false;
  final List<_RequestToRetry> _subscribers = [];

  ApiClient(this._authService) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.currentBackendUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _authService.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode == 401) {
            _subscribers.add(_RequestToRetry(error: error, handler: handler));

            if (!_isRefreshing) {
              _isRefreshing = true;
              
              final refreshed = await _authService.refreshAccessToken();
              final newToken = await _authService.getAccessToken();
              _isRefreshing = false;

              if (refreshed && newToken != null) {
                _retryAllSubscribers(newToken);
              } else {
                _rejectAllSubscribers(error);
                _authService.logout();
              }
              _subscribers.clear();
            }
          } else {
            return handler.next(error);
          }
        },
      ),
    );
  }

  void _retryAllSubscribers(String newAccessToken) {
    for (var subscriber in _subscribers) {
      final options = subscriber.error.requestOptions;
      options.headers['Authorization'] = 'Bearer $newAccessToken';
      _dio.fetch(options).then(
        (response) => subscriber.handler.resolve(response),
        onError: (e) => subscriber.handler.reject(e as DioException),
      );
    }
  }

  void _rejectAllSubscribers(DioException error) {
    for (var subscriber in _subscribers) {
      subscriber.handler.reject(error);
    }
  }

  Dio get dio => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _dio.post(path, data: data);
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void removeAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  Map<String, dynamic> decodeJwtToken(String token) {
    return JwtDecoder.decode(token);
  }
} 