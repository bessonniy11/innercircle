import 'package:flutter/material.dart';
import 'package:zvonilka/core/services/auth_service.dart';
import 'package:zvonilka/core/api/api_client.dart';
import 'package:zvonilka/core/socket/socket_client.dart';
import 'package:zvonilka/core/socket/call_socket_client.dart';
import 'package:zvonilka/features/auth/presentation/screens/login_screen.dart';
import 'package:zvonilka/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:zvonilka/core/widgets/app_logo.dart';
import 'package:provider/provider.dart';
import 'package:zvonilka/core/services/push_notification_service.dart';

/// Экран загрузки для проверки состояния аутентификации
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Небольшая задержка, чтобы UI успел отрисоваться
    Future.delayed(const Duration(milliseconds: 50), _checkAuthStatus);
  }

  /// Проверка состояния аутентификации при запуске
  Future<void> _checkAuthStatus() async {
    // Показываем splash screen минимум 1.5 секунды для лучшего UX
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    
    // НОВОЕ: Передаем PushNotificationService в AuthService
    final pushService = Provider.of<PushNotificationService>(context, listen: false);
    authService.setPushNotificationService(pushService);
    
    // Проверяем, есть ли валидный refresh token
    final hasRefreshToken = await authService.hasValidRefreshToken();

    if (hasRefreshToken) {
      // Если есть, сразу пытаемся обновить токен доступа
      final refreshed = await authService.refreshAccessToken();
      if (refreshed) {
        // Если успешно, сокеты подключатся автоматически через слушателей
        _navigateToChatList();
      } else {
        _navigateToLogin();
      }
    } else {
      _navigateToLogin();
    }
  }

  /// Переход к экрану входа
  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  /// Переход к списку чатов
  void _navigateToChatList() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = await authService.getUserId();
    final username = await authService.getUsername();

    if (userId == null || username == null) {
      _navigateToLogin();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatListScreen(
          currentUserId: userId,
          currentUsername: username,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50), // Фирменный зеленый фон
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Логотип приложения
            const AppLogo(size: 120),
            
            const SizedBox(height: 40),
            
            // Название приложения
            const Text(
              'Звонилка',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Подзаголовок
            const Text(
              'Семейный мессенджер',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w300,
              ),
            ),
            
            const SizedBox(height: 60),
            
            // Индикатор загрузки
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Текст загрузки
            const Text(
              'Подключение...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
