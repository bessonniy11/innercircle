import 'package:flutter/foundation.dart';

class ApiConfig {
  // Автоматическое определение режима
  static bool get isDevelopment {
    // Проверяем flutter run параметры
    const apiUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (apiUrl.isNotEmpty) {
      final isDev = apiUrl.contains('localhost') || apiUrl.contains('127.0.0.1');
      debugPrint('🌐 API Mode determined from API_URL: ${isDev ? "Development" : "Production"}');
      return isDev;
    }
    
    // Автоматически определяем по режиму Flutter
    final isDev = kDebugMode;
    debugPrint('🌐 API Mode determined from kDebugMode: ${isDev ? "Development" : "Production"}');
    return isDev;
  }
  
  // Текущий URL (полностью из .env файлов)
  static String get currentBackendUrl {
    // Проверяем переменную окружения API_URL
    const apiUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (apiUrl.isNotEmpty) {
      debugPrint('🌐 Using API_URL from environment: $apiUrl');
      return apiUrl;
    }
    
    // Если API_URL не задан, используем fallback
    if (isDevelopment) {
      const fallbackUrl = 'http://localhost:3000';
      debugPrint('🌐 Using fallback URL for development: $fallbackUrl');
      return fallbackUrl;
    } else {
      const fallbackUrl = 'http://5.8.76.33:3000'; // Временный fallback для production
      debugPrint('🌐 Using fallback URL for production: $fallbackUrl');
      debugPrint('⚠️ WARNING: Using fallback URL. Set API_URL in .env.production for production!');
      return fallbackUrl;
    }
  }
  
  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10); // Увеличиваем для production
  static const Duration receiveTimeout = Duration(seconds: 30); // Увеличиваем для production
  
  // Для отладки
  static void printCurrentConfig() {
    debugPrint('🌐 === API Configuration ===');
    debugPrint('🌐 Mode: ${isDevelopment ? "Development" : "Production"}');
    debugPrint('🔗 Backend URL: $currentBackendUrl');
    debugPrint('🛠️ Debug Mode: $kDebugMode');
    debugPrint('⏱️ Connect Timeout: $connectTimeout');
    debugPrint('⏱️ Receive Timeout: $receiveTimeout');
    
    // Проверяем .env переменные
    const apiUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (apiUrl.isNotEmpty) {
      debugPrint('✅ API_URL from environment: $apiUrl');
    } else {
      debugPrint('⚠️ API_URL not set, using fallback URLs');
    }
    
    debugPrint('🌐 ========================');
  }
}
