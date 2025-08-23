import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart';

/// Сервис для управления аутентификацией и токенами
class AuthService {
  static const String _tokenKey = 'auth_token';
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

  /// Сохранить токен и данные пользователя после успешного входа
  Future<void> saveAuthData({
    required String token,
    required String userId,
    required String username,
  }) async {
    await _prefs!.setString(_tokenKey, token);
    await _prefs!.setString(_userIdKey, userId);
    await _prefs!.setString(_usernameKey, username);
    
    debugPrint('🔐 Auth data saved: user=$username, id=$userId');
  }

  /// Получить сохраненный токен
  String? getToken() {
    return _prefs!.getString(_tokenKey);
  }

  /// Получить ID текущего пользователя
  String? getUserId() {
    return _prefs!.getString(_userIdKey);
  }

  /// Получить username текущего пользователя
  String? getUsername() {
    return _prefs!.getString(_usernameKey);
  }

  /// Проверить, есть ли валидный токен
  bool hasValidToken() {
    final token = getToken();
    if (token == null) {
      debugPrint('🔐 No token found');
      return false;
    }

    try {
      // Проверяем, что токен не истек
      bool isExpired = JwtDecoder.isExpired(token);
      if (isExpired) {
        debugPrint('🔐 Token expired, clearing auth data');
        clearAuthData();
        return false;
      }

      debugPrint('🔐 Valid token found for user: ${getUsername()}');
      return true;
    } catch (e) {
      debugPrint('🔐 Invalid token format: $e');
      clearAuthData();
      return false;
    }
  }

  /// Получить данные пользователя из токена
  Map<String, dynamic>? getTokenData() {
    final token = getToken();
    if (token == null) return null;

    try {
      return JwtDecoder.decode(token);
    } catch (e) {
      debugPrint('🔐 Failed to decode token: $e');
      return null;
    }
  }

  /// Очистить все данные аутентификации (logout)
  Future<void> clearAuthData() async {
    await _prefs!.remove(_tokenKey);
    await _prefs!.remove(_userIdKey);
    await _prefs!.remove(_usernameKey);
    
    debugPrint('🔐 Auth data cleared');
  }

  /// Проверить, авторизован ли пользователь
  bool get isAuthenticated => hasValidToken();

  /// Получить информацию о текущем пользователе
  Map<String, String?> getCurrentUser() {
    return {
      'id': getUserId(),
      'username': getUsername(),
      'token': getToken(),
    };
  }

  /// Для отладки - показать текущее состояние
  void printCurrentState() {
    final user = getCurrentUser();
    debugPrint('🔐 Auth State:');
    debugPrint('  - Authenticated: $isAuthenticated');
    debugPrint('  - Username: ${user['username']}');
    debugPrint('  - User ID: ${user['id']}');
    debugPrint('  - Has Token: ${user['token'] != null}');
  }
}
