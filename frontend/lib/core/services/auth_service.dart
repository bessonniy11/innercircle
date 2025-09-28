import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:dio/dio.dart';
import 'package:zvonilka/core/config/api_config.dart';
import 'package:zvonilka/core/services/push_notification_service.dart';

/// Сервис для управления аутентификацией и токенами
/// Использует ChangeNotifier для уведомления подписчиков об изменениях состояния
class AuthService with ChangeNotifier {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _usernameKey = 'username';

  String? accessToken;
  PushNotificationService? _pushNotificationService;

  static AuthService? _instance;
  SharedPreferences? _prefs;
  // Используем отдельный экземпляр Dio, чтобы избежать циклических interceptors
  final Dio _dio = Dio(BaseOptions(baseUrl: ApiConfig.currentBackendUrl));

  AuthService._();

  /// Синхронный конструктор для Provider
  AuthService() {
    _initPrefs();
  }

  /// Внедрение зависимости от PushNotificationService
  void setPushNotificationService(PushNotificationService service) {
    _pushNotificationService = service;
  }

  /// Инициализация SharedPreferences
  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    accessToken = _prefs?.getString(_accessTokenKey); // Загружаем токен при инициализации
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
    this.accessToken = accessToken; // Обновляем токен в памяти
    
    // Инициализируем push-уведомления после успешного входа
    await _pushNotificationService?.initialize();
    
    notifyListeners(); // Уведомляем слушателей
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
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      return false;
    }

    // Проверяем, не истек ли сам refresh token
    if (JwtDecoder.isExpired(refreshToken)) {
      await logout();
      return false;
    }

    try {
      final refreshUrl = '/auth/refresh';

      final response = await _dio.post(
        refreshUrl,
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final newAccessToken = response.data['access_token'];
        await _prefs!.setString(_accessTokenKey, newAccessToken);
        this.accessToken = newAccessToken; // Обновляем токен в памяти
        
        // Опционально: обновить refresh token, если бэкенд возвращает новый
        if (response.data.containsKey('refresh_token')) {
          final newRefreshToken = response.data['refresh_token'];
          await _prefs!.setString(_refreshTokenKey, newRefreshToken);
        }
        
        notifyListeners(); // Уведомляем слушателей о новом токене
        return true;
      }
      
      return false;
    } on DioException catch (e) {
      // Если refresh token тоже невалиден (401), выходим из системы
      if (e.response?.statusCode == 401) {
        await logout();
      } else {
        print('🔐 DioException while refreshing token: $e');
      }
      return false;
    } catch (e) {
      print('🔐 Unknown error while refreshing token: $e');
      return false;
    }
  }

  /// Проверить, есть ли валидный Access Token
  Future<bool> hasValidAccessToken() async {
    final token = await getAccessToken();
    if (token == null) {
      return false;
    }

    try {
      if (JwtDecoder.isExpired(token)) {
        return false; // Считаем его невалидным, interceptor должен сработать
      }
      return true;
    } catch (e) {
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
      return false;
    }

    try {
      if (JwtDecoder.isExpired(token)) {
        return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Очистить все данные аутентификации и сокеты
  Future<void> logout() async {
    await clearAuthData();
  }

  /// Очистить все данные аутентификации
  Future<void> clearAuthData() async {
    await _initPrefs();
    await _prefs!.remove(_accessTokenKey);
    await _prefs!.remove(_refreshTokenKey);
    await _prefs!.remove(_userIdKey);
    await _prefs!.remove(_usernameKey);
    accessToken = null; // Очищаем токен в памяти
    
    notifyListeners(); // Уведомляем слушателей, что пользователь вышел
  }

  /// Проверить, авторизован ли пользователь
  Future<bool> get isAuthenticated async {
    // Пользователь считается авторизованным, если у него есть валидный refresh token
    return await hasValidRefreshToken();
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
    print('🔐 Auth State:');
    print('  - Authenticated: $isAuth');
    print('  - Username: ${user['username']}');
    print('  - User ID: ${user['id']}');
    print('  - Has Access Token: ${user['access_token'] != null}');
    print('  - Has Refresh Token: ${user['refresh_token'] != null}');
    
    final accessToken = user['access_token'];
    if (accessToken != null) {
      try {
        final isExpired = JwtDecoder.isExpired(accessToken);
        final expiryDate = JwtDecoder.getExpirationDate(accessToken);
        print('  - Access Token Expired: $isExpired (Expires at: $expiryDate)');
      } catch (e) {
        print('  - Access Token Invalid');
      }
    }
    
    final refreshToken = user['refresh_token'];
    if (refreshToken != null) {
      try {
        final isExpired = JwtDecoder.isExpired(refreshToken);
        final expiryDate = JwtDecoder.getExpirationDate(refreshToken);
        print('  - Refresh Token Expired: $isExpired (Expires at: $expiryDate)');
      } catch (e) {
        print('  - Refresh Token Invalid');
      }
    }
  }
}
