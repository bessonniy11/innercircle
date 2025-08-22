import 'package:flutter/material.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/socket/socket_client.dart';
import 'package:frontend/features/chat/presentation/screens/message_screen.dart';
import 'package:collection/collection.dart'; // Import for firstWhereOrNull
import 'package:frontend/features/chat/presentation/screens/user_list_screen.dart'; // Импорт UserListScreen
import 'package:provider/provider.dart'; // Corrected import for Provider

class ChatListScreen extends StatefulWidget {
  final String currentUserId;
  final String currentUsername;

  const ChatListScreen({
    super.key,
    required this.currentUserId,
    required this.currentUsername,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _chats = []; // Переменная для хранения загруженных чатов
  bool _isLoading = true;
  String? _familyChatId;
  String? _familyChatName;

  @override
  void initState() {
    super.initState();
    _fetchChats();
  }

  Future<void> _fetchChats() async {
    try {
      final apiClient = Provider.of<ApiClient>(context, listen: false);
      final response = await apiClient.dio.get('/chats');
      final List<dynamic> fetchedChats = response.data;
      setState(() {
        _chats = fetchedChats.map((e) => e as Map<String, dynamic>).toList(); // Преобразуем к List<Map<String, dynamic>>
        final familyChat = _chats.firstWhereOrNull(
            (chat) => chat['name'] == 'Семейный Чат');
        if (familyChat != null) {
          _familyChatId = familyChat['id'];
          _familyChatName = familyChat['name'];
        }
        _isLoading = false;
      });
    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить чаты: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои Чаты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Implement chat creation logic
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? const Center(child: Text('Нет доступных чатов'))
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text(chat['name'] ?? 'Без имени'),
                        subtitle: Text(chat['description'] ?? ''),
                        onTap: () {
                          if (chat['name'] == 'Семейный Чат' &&
                              _familyChatId != null &&
                              _familyChatName != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MessageScreen(
                                  chatId: _familyChatId!,
                                  chatName: _familyChatName!,
                                  apiClient: Provider.of<ApiClient>(context, listen: false),
                                  socketClient: Provider.of<SocketClient>(context, listen: false),
                                  currentUserId: widget.currentUserId,
                                  currentUsername: widget.currentUsername, // Передача currentUsername
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Этот чат пока не поддерживается')),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => UserListScreen(currentUserId: widget.currentUserId, currentUsername: widget.currentUsername)));
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
} 