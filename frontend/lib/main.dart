import 'package:flutter/material.dart';
import 'package:zvonilka/features/auth/presentation/screens/login_screen.dart';
import 'package:provider/provider.dart'; // Импортируем Provider
import 'package:zvonilka/core/api/api_client.dart'; // Импортируем ApiClient
import 'package:zvonilka/core/socket/socket_client.dart'; // Импортируем SocketClient
import 'package:zvonilka/core/config/api_config.dart';

void main() {
  // Показываем текущую конфигурацию API
  ApiConfig.printCurrentConfig();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(
          create: (_) => ApiClient(),
        ),
        Provider<SocketClient>(
          create: (_) => SocketClient(),
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
        home: const LoginScreen(),
      ),
    );
  }
}
