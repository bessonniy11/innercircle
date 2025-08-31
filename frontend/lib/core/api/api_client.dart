import 'package:dio/dio.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:zvonilka/core/config/api_config.dart';
import 'package:zvonilka/core/services/auth_service.dart';

class ApiClient {
  late Dio _dio;
  late AuthService _authService;

  ApiClient() {
    _authService = AuthService();
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

    // Добавляем interceptor для автоматического обновления токенов
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Добавляем токен к каждому запросу
          final token = await _authService.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // Если получили 401, пытаемся обновить токен
          if (error.response?.statusCode == 401) {
            debugPrint('🔐 401 error, attempting to refresh token...');
            
            final refreshed = await _authService.refreshAccessToken();
            if (refreshed) {
              // Повторяем запрос с новым токеном
              final newToken = await _authService.getAccessToken();
              if (newToken != null) {
                error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
                
                // Повторяем оригинальный запрос
                try {
                  final response = await _dio.fetch(error.requestOptions);
                  handler.resolve(response);
                  return;
                } catch (e) {
                  handler.reject(error);
                  return;
                }
              }
            }
          }
          
          handler.reject(error);
        },
      ),
    );
  }

  Dio get dio => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void removeAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  // Helper to decode JWT token and extract payload
  Map<String, dynamic> decodeJwtToken(String token) {
    return JwtDecoder.decode(token);
  }
} 