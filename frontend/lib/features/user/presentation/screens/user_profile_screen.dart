import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:zvonilka/core/services/auth_service.dart';

/// Экран профиля пользователя
class UserProfileScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUsername;

  const UserProfileScreen({
    super.key,
    required this.currentUserId,
    required this.currentUsername,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
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
      debugPrint('🔥 Error initializing user profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Получить дату создания аккаунта из токена
  String _getAccountCreatedDate() {
    if (_tokenData == null) return 'Неизвестно';
    
    try {
      final iat = _tokenData!['iat'] as int?;
      if (iat != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(iat * 1000);
        return '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}';
      }
    } catch (e) {
      debugPrint('Error parsing token date: $e');
    }
    
    return 'Неизвестно';
  }

  /// Получить срок действия токена
  String _getTokenExpiry() {
    if (_tokenData == null) return 'Неизвестно';
    
    try {
      final exp = _tokenData!['exp'] as int?;
      if (exp != null) {
        final date = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        final now = DateTime.now();
        
        if (date.isBefore(now)) {
          return 'Истёк';
        }
        
        final difference = date.difference(now);
        if (difference.inDays > 0) {
          return 'Через ${difference.inDays} дн.';
        } else if (difference.inHours > 0) {
          return 'Через ${difference.inHours} ч.';
        } else if (difference.inMinutes > 0) {
          return 'Через ${difference.inMinutes} мин.';
        } else {
          return 'Скоро истечёт';
        }
      }
    } catch (e) {
      debugPrint('Error parsing token expiry: $e');
    }
    
    return 'Неизвестно';
  }

  /// Построить информационную строку
  Widget _buildInfoRow(String label, String value, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: Colors.grey[600]),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.end,
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
        title: const Text('Мой профиль'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Редактирование профиля (в разработке)')),
              );
            },
            tooltip: 'Редактировать профиль',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Аватар и основная информация
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Аватар
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: Text(
                            widget.currentUsername.isNotEmpty 
                                ? widget.currentUsername[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Смена аватара (в разработке)')),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Имя пользователя
                    Text(
                      widget.currentUsername,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Статус онлайн
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, color: Colors.green, size: 8),
                          SizedBox(width: 6),
                          Text(
                            'Онлайн',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Основная информация
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Основная информация',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow('Имя пользователя', widget.currentUsername, icon: Icons.person),
                    const Divider(),
                    _buildInfoRow('ID пользователя', widget.currentUserId, icon: Icons.fingerprint),
                    const Divider(),
                    _buildInfoRow('Дата регистрации', _getAccountCreatedDate(), icon: Icons.calendar_today),
                    const Divider(),
                    _buildInfoRow('Токен действует', _getTokenExpiry(), icon: Icons.access_time),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Настройки конфиденциальности
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Конфиденциальность',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.visibility_outlined),
                      title: const Text('Кто может видеть мой профиль'),
                      subtitle: const Text('Все пользователи'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Настройки конфиденциальности (в разработке)')),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.message_outlined),
                      title: const Text('Кто может писать сообщения'),
                      subtitle: const Text('Все пользователи'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Настройки сообщений (в разработке)')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Действия с аккаунтом
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Управление аккаунтом',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Изменить пароль'),
                      subtitle: const Text('Обновить пароль для входа'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Изменение пароля (в разработке)')),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.security_outlined),
                      title: const Text('Безопасность'),
                      subtitle: const Text('Двухфакторная аутентификация'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Настройки безопасности (в разработке)')),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.delete_outline, color: Colors.red),
                      title: const Text('Удалить аккаунт', style: TextStyle(color: Colors.red)),
                      subtitle: const Text('Безвозвратно удалить профиль'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Удаление аккаунта (в разработке)')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
