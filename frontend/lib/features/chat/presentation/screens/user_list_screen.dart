import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/api/api_client.dart'; // Предполагаем, что ApiClient находится здесь
import 'package:frontend/features/auth/domain/models/user_public_model.dart'; // Импортируем новый UserPublicDto
import 'package:frontend/features/chat/presentation/screens/message_screen.dart'; // Импортируем MessageScreen
import 'package:frontend/core/socket/socket_client.dart'; // Импортируем SocketClient

/**
 * Экран списка пользователей.
 *
 * Отображает список всех зарегистрированных пользователей в системе,
 * исключая текущего аутентифицированного пользователя.
 * Позволяет пользователю просматривать других членов семьи.
 *
 * В MVP версии, это просто список имен. В будущем здесь может быть
 * функциональность для инициирования личных чатов, отображения статуса онлайн/оффлайн.
 *
 * @author ИИ-Ассистент + Bessonniy
 * @since 1.0.0
 */
class UserListScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUsername;

  const UserListScreen({super.key, required this.currentUserId, required this.currentUsername});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  late Future<List<UserPublicDto>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
  }

  /**
   * Асинхронно получает список пользователей с бэкенда.
   *
   * Исключает текущего аутентифицированного пользователя, что контролируется бэкендом.
   * @returns Future<List<UserPublicDto>> Список публичных данных пользователей.
   * @throws Exception В случае ошибки при получении данных.
   */
  Future<List<UserPublicDto>> _fetchUsers() async {
    try {
      final apiClient = Provider.of<ApiClient>(context, listen: false);
      final response = await apiClient.get('/users');
      if (response.statusCode == 200) {
        final List<dynamic> userData = response.data;
        return userData.map((json) => UserPublicDto.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load users: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching users: $e');
      throw Exception('Failed to load users: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Участники Семьи'),
      ),
      body: FutureBuilder<List<UserPublicDto>>(
        future: _usersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Пользователи не найдены.'));
          } else {
            return ListView.builder(
              itemCount: snapshot.data!.length,
              itemBuilder: (context, index) {
                final user = snapshot.data![index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).secondaryHeaderColor,
                      child: Text(user.username[0].toUpperCase()),
                    ),
                    title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                    // В будущем здесь можно добавить статус онлайн/оффлайн
                    // subtitle: Text(user.isOnline ? 'Онлайн' : 'Оффлайн'),
                    onTap: () async {
                      // TODO: Implement navigation to private chat with this user
                      print('Tapped on user: ${user.username}');
                      try {
                        final apiClient = Provider.of<ApiClient>(context, listen: false);
                        final socketClient = Provider.of<SocketClient>(context, listen: false);
                        final response = await apiClient.post('/chats/private', data: { 'targetUserId': user.id });

                        if (response.statusCode == 201 || response.statusCode == 200) {
                          final chatData = response.data;
                          final String chatId = chatData['id'];
                          final String chatName = chatData['name'];

                          if (!mounted) return; // Проверка на mounted перед навигацией
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MessageScreen(
                                chatId: chatId,
                                chatName: chatName,
                                apiClient: apiClient,
                                socketClient: socketClient,
                                currentUserId: widget.currentUserId,
                                currentUsername: widget.currentUsername,
                              ),
                            ),
                          );
                        } else {
                          if (!mounted) return; // Проверка на mounted перед показом SnackBar
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Не удалось создать/найти чат: ${response.statusCode}')),
                          );
                        }
                      } catch (e) {
                        print('Error creating/finding chat: $e');
                        if (!mounted) return; // Проверка на mounted перед показом SnackBar
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка при создании/поиске чата: ${e.toString()}')),
                        );
                      }
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
