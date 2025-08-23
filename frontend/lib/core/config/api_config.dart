import 'package:flutter/foundation.dart';

class ApiConfig {
  // URLs для разных режимов
  static const String localBackendUrl = 'http://localhost:3000';
  static const String productionBackendUrl = 'http://5.8.76.33'; // Или zvonilka.ibessonniy.ru когда будет готов
  
  // Автоматическое определение режима
  static bool get isDevelopment {
    // Проверяем flutter run параметры
    const apiUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (apiUrl.isNotEmpty) {
      return apiUrl.contains('localhost');
    }
    
    // Автоматически определяем по режиму Flutter
    return kDebugMode;
  }
  
  // Текущий URL (автоматически выбирается)
  static String get currentBackendUrl {
    // Сначала проверяем переменную окружения
    const apiUrl = String.fromEnvironment('API_URL', defaultValue: '');
    if (apiUrl.isNotEmpty) {
      return apiUrl;
    }
    
    // Иначе по режиму разработки
    return isDevelopment ? localBackendUrl : productionBackendUrl;
  }
  
  // Timeouts
  static const Duration connectTimeout = Duration(milliseconds: 5000);
  static const Duration receiveTimeout = Duration(milliseconds: 3000);
  
  // Для отладки
  static void printCurrentConfig() {
    print('🌐 API Mode: ${isDevelopment ? "Development" : "Production"}');
    print('🔗 Backend URL: $currentBackendUrl');
    print('🛠️ Debug Mode: $kDebugMode');
  }
}
