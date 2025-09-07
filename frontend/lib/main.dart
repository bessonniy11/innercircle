import 'package:flutter/material.dart';
import 'package:zvonilka/core/widgets/responsive_layout.dart';
import 'package:zvonilka/features/auth/presentation/screens/splash_screen.dart';
import 'package:provider/provider.dart'; // Импортируем Provider
import 'package:zvonilka/core/api/api_client.dart'; // Импортируем ApiClient
import 'package:zvonilka/core/socket/socket_client.dart'; // Импортируем SocketClient
import 'package:zvonilka/core/socket/call_socket_client.dart'; // Импортируем CallSocketClient
import 'package:zvonilka/core/config/api_config.dart';
import 'package:zvonilka/core/services/auth_service.dart';
import 'package:zvonilka/core/services/webrtc_service.dart';
import 'package:zvonilka/core/services/call_notification_service.dart';
import 'package:permission_handler/permission_handler.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  // Запрашиваем разрешения для микрофона и камеры
  await requestMicrophonePermissions();
  // Показываем текущую конфигурацию API
  ApiConfig.printCurrentConfig();
  runApp(const MyApp());
}

/// Запрос разрешений для микрофона и камеры
Future<void> requestMicrophonePermissions() async {
  try {
    debugPrint('🔐 Запрашиваем разрешения для микрофона и камеры...');
    
    // Запрашиваем разрешения
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.camera,
    ].request();
    
    // Проверяем статус микрофона
    if (statuses[Permission.microphone] == PermissionStatus.granted) {
      debugPrint('✅ Разрешение на микрофон получено');
    } else {
      debugPrint('❌ Разрешение на микрофон НЕ получено: ${statuses[Permission.microphone]}');
    }
    
    // Проверяем статус камеры
    if (statuses[Permission.camera] == PermissionStatus.granted) {
      debugPrint('✅ Разрешение на камеру получено');
    } else {
      debugPrint('❌ Разрешение на камеру НЕ получено: ${statuses[Permission.camera]}');
    }
    
    // Если микрофон не разрешен, показываем предупреждение
    if (statuses[Permission.microphone] != PermissionStatus.granted) {
      debugPrint('⚠️ ВНИМАНИЕ: Без разрешения на микрофон звонки НЕ будут работать!');
    }
    
  } catch (e) {
    debugPrint('🚨 Ошибка при запросе разрешений: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthService теперь ChangeNotifierProvider
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        // ApiClient зависит от AuthService
        Provider<ApiClient>(
          create: (context) => ApiClient(
            Provider.of<AuthService>(context, listen: false),
          ),
        ),
        // SocketClient зависит от AuthService
        Provider<SocketClient>(
          create: (context) => SocketClient(
            Provider.of<AuthService>(context, listen: false),
          ),
        ),
        // CallSocketClient зависит от AuthService и теперь тоже ChangeNotifierProvider
        ChangeNotifierProvider<CallSocketClient>(
          create: (context) => CallSocketClient(
            Provider.of<AuthService>(context, listen: false),
          ),
        ),
        ChangeNotifierProvider<WebRTCService>(
          create: (context) => WebRTCService(
            Provider.of<CallSocketClient>(context, listen: false),
            Provider.of<ApiClient>(context, listen: false),
          ),
        ),
        Provider<CallNotificationService>(
          create: (_) => CallNotificationService(),
        ),
      ],
      child: MaterialApp(
        title: 'Звонилка',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4CAF50), // Зеленый цвет логотипа
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            elevation: 2,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
          ),
        ),
        home: const SplashScreen(),
        builder: (context, child) {
          // Оборачиваем все экраны в ResponsiveLayout для адаптивности
          return ResponsiveLayout(
            child: child!,
          );
        },
      ),
    );
  }
}
