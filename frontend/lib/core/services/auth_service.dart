import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:zvonilka/core/config/api_config.dart';

/// Сервис для управления аутентификацией и токенами
class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';

  static AuthService? _instance;
  SharedPreferences? _prefs;
  final Dio _dio = Dio();

  AuthService._();

  /// Синхронный конструктор для Provider
  AuthService() {
    _initPrefs();
  }

  /// Инициализация SharedPreferences
  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Singleton instance
  static Future<AuthService> getInstance() async {
    _instance ??= AuthService._();
    _instance!._prefs ??= await SharedPreferences.getInstance();
    return _instance!;
  }

  /// Сохранить токены и данные пользователя
  Future<void> saveAuthData({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String username,
  }) async {
    await _initPrefs();
    await _prefs!.setString(_accessTokenKey, accessToken);
    await _prefs!.setString(_refreshTokenKey, refreshToken);
    await _prefs!.setString(_userIdKey, userId);
    await _prefs!.setString(_usernameKey, username);
    
    debugPrint('🔐 Auth data saved: user=$username, id=$userId');
  }

  /// Получить Access Token
  Future<String?> getAccessToken() async {
    await _initPrefs();
    return _prefs!.getString(_accessTokenKey);
  }

  /// Получить Refresh Token
  Future<String?> getRefreshToken() async {
    await _initPrefs();
    return _prefs!.getString(_refreshTokenKey);
  }

  /// Обновить Access Token через Refresh Token
  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        debugPrint('🔐 No refresh token available');
        return false;
      }

      debugPrint('🔐 Attempting to refresh access token...');
      
      // Используем ApiConfig вместо захардкоженного URL
      final refreshUrl = '${ApiConfig.currentBackendUrl}/auth/refresh';
      debugPrint('🔐 Refresh URL: $refreshUrl');
      
      final response = await _dio.post(
        refreshUrl,
        data: {
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access_token'];
        final userId = response.data['user']['id'];
        final username = response.data['user']['username'];
        
        // Сохраняем новый access token
        await _prefs!.setString(_accessTokenKey, newAccessToken);
        
        debugPrint('🔐 Access token refreshed successfully for user: $username');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('🔐 Failed to refresh access token: $e');
      return false;
    }
  }

  /// Проверить, есть ли валидный Access Token
  Future<bool> hasValidAccessToken() async {
    final token = await getAccessToken();
    if (token == null) {
      debugPrint('🔐 No access token found');
      return false;
    }

    try {
      bool isExpired = JwtDecoder.isExpired(token);
      if (isExpired) {
        debugPrint('🔐 Access token expired, attempting to refresh...');
        
        // Пытаемся обновить токен
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          debugPrint('🔐 Token refreshed successfully');
          return true;
        } else {
          debugPrint('🔐 Failed to refresh token');
          return false;
        }
      }

      debugPrint('🔐 Valid access token found for user: ${await getUsername()}');
      return true;
    } catch (e) {
      debugPrint('🔐 Invalid access token format: $e');
      return false;
    }
  }

  Future<String?> getUsername() async {
    await _initPrefs();
    return _prefs!.getString(_usernameKey);
  }

  /// Проверить, есть ли валидный Refresh Token
  Future<bool> hasValidRefreshToken() async {
    final token = await getRefreshToken();
    if (token == null) {
      debugPrint('🔐 No refresh token found');
      return false;
    }

    try {
      bool isExpired = JwtDecoder.isExpired(token);
      if (isExpired) {
        debugPrint('🔐 Refresh token expired');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('🔐 Invalid refresh token format: $e');
      return false;
    }
  }

  /// Очистить все данные аутентификации
  Future<void> clearAuthData() async {
    await _initPrefs();
    await _prefs!.remove(_accessTokenKey);
    await _prefs!.remove(_refreshTokenKey);
    await _prefs!.remove(_userIdKey);
    await _prefs!.remove(_usernameKey);
    
    debugPrint('🔐 Auth data cleared');
  }

  /// Проверить, авторизован ли пользователь
  Future<bool> get isAuthenticated async {
    final hasAccess = await hasValidAccessToken();
    final hasRefresh = await hasValidRefreshToken();
    return hasAccess || hasRefresh;
  }

  /// Получить информацию о текущем пользователе
  Future<Map<String, String?>> getCurrentUser() async {
    await _initPrefs();
    return {
      'id': _prefs!.getString(_userIdKey),
      'username': _prefs!.getString(_usernameKey),
      'access_token': _prefs!.getString(_accessTokenKey),
      'refresh_token': _prefs!.getString(_refreshTokenKey),
    };
  }

  Future<String?> getUserId() async {
    await _initPrefs();
    return _prefs!.getString(_userIdKey);
  }

  /// Для отладки - показать текущее состояние
  Future<void> printCurrentState() async {
    final user = await getCurrentUser();
    final isAuth = await isAuthenticated;
    debugPrint('🔐 Auth State:');
    debugPrint('  - Authenticated: $isAuth');
    debugPrint('  - Username: ${user['username']}');
    debugPrint('  - User ID: ${user['id']}');
    debugPrint('  - Has Access Token: ${user['access_token'] != null}');
    debugPrint('  - Has Refresh Token: ${user['refresh_token'] != null}');
    debugPrint('  - Access Token Valid: ${await hasValidAccessToken()}');
    debugPrint('  - Refresh Token Valid: ${await hasValidRefreshToken()}');
  }
}
