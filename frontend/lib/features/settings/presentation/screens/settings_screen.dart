import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:zvonilka/core/services/auth_service.dart';
import 'package:zvonilka/core/config/api_config.dart';
import 'package:zvonilka/core/api/api_client.dart';
import 'package:zvonilka/core/socket/socket_client.dart';
import 'package:zvonilka/core/socket/call_socket_client.dart';
import 'package:zvonilka/features/auth/presentation/screens/login_screen.dart';
import 'package:zvonilka/features/user/presentation/screens/user_profile_screen.dart';
import 'package:zvonilka/core/widgets/app_logo.dart';
import 'package:provider/provider.dart';

/// Экран настроек приложения
class SettingsScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUsername;

  const SettingsScreen({
    super.key,
    required this.currentUserId,
    required this.currentUsername,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AuthService _authService;
  Map<String, dynamic>? _tokenData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  /// Инициализация данных пользователя
  Future<void> _initializeData() async {
    try {
      _authService = await AuthService.getInstance();
      _tokenData = await _authService.getCurrentUser();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('🔥 Error initializing settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Logout функциональность
  Future<void> _logout() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);

      // Просто вызываем logout. AuthService уведомит всех слушателей (сокеты)
      // и очистит данные.
      await authService.logout();
      
      debugPrint('🚪 Logout from settings successful');

      if (mounted) {
        // Переходим на экран входа
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false, // Удаляем все предыдущие экраны
        );
      }
    } catch (e) {
      debugPrint('🔥 Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при выходе из системы')),
        );
      }
    }
  }

  /// Показать диалог подтверждения logout
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Выйти из аккаунта?'),
          content: Text('Вы уверены, что хотите выйти из аккаунта "${widget.currentUsername}"?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрываем диалог
              },
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрываем диалог
                _logout(); // Выходим
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );
  }

  /// Показать информацию о приложении
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'Звонилка',
      applicationVersion: '1.0.0',
      applicationIcon: const AppLogo(size: 60),
      children: [
        const Text('Семейный мессенджер для простого и удобного общения с близкими.'),
        const SizedBox(height: 16),
        Text('Backend: ${ApiConfig.currentBackendUrl}'),
        Text('Режим: ${ApiConfig.isDevelopment ? "Разработка" : "Продакшн"}'),
      ],
    );
  }

  /// Показать техническую информацию
  void _showTechnicalInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Техническая информация'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInfoRow('Пользователь', widget.currentUsername),
                _buildInfoRow('ID пользователя', widget.currentUserId),
                _buildInfoRow('Backend URL', ApiConfig.currentBackendUrl),
                _buildInfoRow('Режим', ApiConfig.isDevelopment ? "Разработка" : "Продакшн"),
                _buildInfoRow('Debug Mode', kDebugMode.toString()),
                const Divider(),
                if (_tokenData != null) ...[
                  const Text('Данные токена:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ..._tokenData!.entries.map((entry) => 
                    _buildInfoRow(entry.key, entry.value.toString())
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  /// Виджет для отображения информационной строки
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Профиль пользователя
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: Text(
                      widget.currentUsername.isNotEmpty 
                          ? widget.currentUsername[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.currentUsername,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ID: ${widget.currentUserId}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Секция: Аккаунт
          const Text(
            'Аккаунт',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          
          Card(
            elevation: 1,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Профиль пользователя'),
                  subtitle: const Text('Изменить информацию о себе'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfileScreen(
                          currentUserId: widget.currentUserId,
                          currentUsername: widget.currentUsername,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Изменить пароль'),
                  subtitle: const Text('Обновить пароль аккаунта'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Изменение пароля (в разработке)')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Секция: Приложение
          const Text(
            'Приложение',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          
          Card(
            elevation: 1,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Уведомления'),
                  subtitle: const Text('Настроить push-уведомления'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Настройки уведомлений (в разработке)')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.color_lens_outlined),
                  title: const Text('Тема приложения'),
                  subtitle: const Text('Светлая, тёмная или системная'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Смена темы (в разработке)')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language_outlined),
                  title: const Text('Язык'),
                  subtitle: const Text('Русский'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Смена языка (в разработке)')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Секция: Информация
          const Text(
            'Информация',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          
          Card(
            elevation: 1,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('О приложении'),
                  subtitle: const Text('Версия, лицензия, разработчики'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showAboutDialog,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report_outlined),
                  title: const Text('Техническая информация'),
                  subtitle: const Text('Для диагностики и отладки'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showTechnicalInfo,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Помощь и поддержка'),
                  subtitle: const Text('FAQ, обратная связь'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Раздел помощи (в разработке)')),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Кнопка выхода
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showLogoutDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Выйти из аккаунта',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Версия приложения
          Center(
            child: Text(
              'Звонилка v1.0.0\n${ApiConfig.isDevelopment ? "Development Mode" : "Production Mode"}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
