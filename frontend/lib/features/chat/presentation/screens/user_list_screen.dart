import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zvonilka/core/api/api_client.dart';
import 'package:zvonilka/features/auth/domain/models/user_public_model.dart';
import 'package:zvonilka/features/chat/presentation/screens/message_screen.dart';
import 'package:zvonilka/core/socket/socket_client.dart';
import 'package:zvonilka/features/call/domain/models/call_model.dart';
import 'package:zvonilka/features/call/presentation/screens/call_screen.dart';

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

  /// Начать звонок с пользователем
  void _startCall(UserPublicDto user) {
    // Создаем модель звонка
    final call = CallModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // Временный ID
      callerId: widget.currentUserId,
      callerUsername: widget.currentUsername,
      receiverId: user.id,
      receiverUsername: user.username,
      status: CallStatus.created,
      type: CallType.voice,
      createdAt: DateTime.now(),
    );

    // Переходим на экран звонка
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          call: call,
          currentUserId: widget.currentUserId,
          isIncoming: false,
        ),
      ),
    );
  }

  /// Открыть чат с пользователем
  Future<void> _openChat(UserPublicDto user) async {
    try {
      final apiClient = Provider.of<ApiClient>(context, listen: false);
      final socketClient = Provider.of<SocketClient>(context, listen: false);
      final response = await apiClient.post('/chats/private', data: { 'targetUserId': user.id });

      if (response.statusCode == 201 || response.statusCode == 200) {
        final chatData = response.data;
        final String chatId = chatData['id'];
        final String chatName = chatData['name'];

        if (!mounted) return;
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
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось создать/найти чат: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error creating/finding chat: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при создании/поиске чата: ${e.toString()}')),
      );
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
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Кнопка звонка
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => _startCall(user),
                          tooltip: 'Позвонить',
                        ),
                        // Кнопка чата
                        IconButton(
                          icon: const Icon(Icons.chat, color: Colors.blue),
                          onPressed: () => _openChat(user),
                          tooltip: 'Написать сообщение',
                        ),
                      ],
                    ),
                    onTap: () => _openChat(user),
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
