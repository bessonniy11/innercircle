import 'package:flutter/material.dart';
import 'package:zvonilka/core/services/auth_service.dart';
import 'package:zvonilka/core/api/api_client.dart';
import 'package:zvonilka/core/socket/socket_client.dart';
import 'package:zvonilka/features/auth/presentation/screens/login_screen.dart';
import 'package:zvonilka/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:zvonilka/core/widgets/app_logo.dart';
import 'package:provider/provider.dart';

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
    _checkAuthStatus();
  }

  /// Проверка состояния аутентификации при запуске
  Future<void> _checkAuthStatus() async {
    try {
      // Показываем splash screen минимум 1.5 секунды для лучшего UX
      await Future.delayed(const Duration(milliseconds: 1500));

      final authService = await AuthService.getInstance();
      authService.printCurrentState();

      if (!mounted) return;

      if (authService.isAuthenticated) {
        // Пользователь авторизован, настраиваем клиенты и переходим к чатам
        await _setupAuthenticatedUser(authService);
      } else {
        // Пользователь не авторизован, переходим к экрану входа
        _navigateToLogin();
      }
    } catch (e) {
      debugPrint('🔥 Error during auth check: $e');
      if (mounted) {
        _navigateToLogin();
      }
    }
  }

  /// Настройка для авторизованного пользователя
  Future<void> _setupAuthenticatedUser(AuthService authService) async {
    try {
      final apiClient = Provider.of<ApiClient>(context, listen: false);
      final socketClient = Provider.of<SocketClient>(context, listen: false);

      final token = authService.getToken()!;
      final userId = authService.getUserId()!;
      final username = authService.getUsername()!;

      // Настраиваем API клиент
      apiClient.setAuthToken(token);
      
      // Настраиваем Socket клиент
      socketClient.setToken(token);
      socketClient.connect();

      debugPrint('🎉 Auto-login successful for user: $username');

      if (mounted) {
        _navigateToChatList(userId, username);
      }
    } catch (e) {
      debugPrint('🔥 Error setting up authenticated user: $e');
      // При ошибке очищаем данные и переходим к логину
      await authService.clearAuthData();
      if (mounted) {
        _navigateToLogin();
      }
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
  void _navigateToChatList(String userId, String username) {
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
              'Проверка авторизации...',
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
