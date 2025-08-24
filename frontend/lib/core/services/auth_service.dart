import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart';

/// Сервис для управления аутентификацией и токенами
class AuthService {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';

  static AuthService? _instance;
  SharedPreferences? _prefs;

  AuthService._();

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
    await _prefs!.setString(_accessTokenKey, accessToken);
    await _prefs!.setString(_refreshTokenKey, refreshToken);
    await _prefs!.setString(_userIdKey, userId);
    await _prefs!.setString(_usernameKey, username);
    
    debugPrint('🔐 Auth data saved: user=$username, id=$userId');
  }

  /// Получить Access Token
  String? getAccessToken() {
    return _prefs!.getString(_accessTokenKey);
  }

  /// Получить Refresh Token
  String? getRefreshToken() {
    return _prefs!.getString(_refreshTokenKey);
  }

  /// Проверить, есть ли валидный Access Token
  bool hasValidAccessToken() {
    final token = getAccessToken();
    if (token == null) {
      debugPrint('🔐 No access token found');
      return false;
    }

    try {
      bool isExpired = JwtDecoder.isExpired(token);
      if (isExpired) {
        debugPrint('🔐 Access token expired');
        return false;
      }

      debugPrint('�� Valid access token found for user: ${getUsername()}');
      return true;
    } catch (e) {
      debugPrint('🔐 Invalid access token format: $e');
      return false;
    }
  }

  String? getUsername() {
    return _prefs!.getString(_usernameKey);
  }

  /// Проверить, есть ли валидный Refresh Token
  bool hasValidRefreshToken() {
    final token = getRefreshToken();
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
    await _prefs!.remove(_accessTokenKey);
    await _prefs!.remove(_refreshTokenKey);
    await _prefs!.remove(_userIdKey);
    await _prefs!.remove(_usernameKey);
    
    debugPrint('🔐 Auth data cleared');
  }

  /// Проверить, авторизован ли пользователь
  bool get isAuthenticated => hasValidAccessToken() || hasValidRefreshToken();

  /// Получить информацию о текущем пользователе
  Map<String, String?> getCurrentUser() {
    return {
      'id': getUserId(),
      'username': getUsername(),
      'access_token': getAccessToken(),
      'refresh_token': getRefreshToken(),
    };
  }

  String? getUserId() {
    return _prefs!.getString(_userIdKey);
  }

  /// Для отладки - показать текущее состояние
  void printCurrentState() {
    final user = getCurrentUser();
    debugPrint('🔐 Auth State:');
    debugPrint('  - Authenticated: $isAuthenticated');
    debugPrint('  - Username: ${user['username']}');
    debugPrint('  - User ID: ${user['id']}');
    debugPrint('  - Has Access Token: ${user['access_token'] != null}');
    debugPrint('  - Has Refresh Token: ${user['refresh_token'] != null}');
    debugPrint('  - Access Token Valid: ${hasValidAccessToken()}');
    debugPrint('  - Refresh Token Valid: ${hasValidRefreshToken()}');
  }
}
