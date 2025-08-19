import 'package:flutter/material.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/socket/socket_client.dart';
import 'package:frontend/features/chat/presentation/screens/message_screen.dart';

class ChatListScreen extends StatefulWidget {
  final ApiClient apiClient;
  final SocketClient socketClient;
  final String currentUserId;

  const ChatListScreen({
    Key? key,
    required this.apiClient,
    required this.socketClient,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _chats = [];
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
      final response = await widget.apiClient.get('/chats');
      final List<dynamic> fetchedChats = response.data;
      setState(() {
        _chats = fetchedChats.cast<Map<String, dynamic>>();
        _familyChatId = _chats.firstWhere(
            (chat) => chat['name'] == 'Семейный Чат',
            orElse: () => {})
            ['id'];
        _familyChatName = _chats.firstWhere(
            (chat) => chat['name'] == 'Семейный Чат',
            orElse: () => {})
            ['name'];
        _isLoading = false;
      });
    } catch (e) {
      print('Failed to fetch chats: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить чаты: $e')),
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
                                  apiClient: widget.apiClient,
                                  socketClient: widget.socketClient,
                                  currentUserId: widget.currentUserId,
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
    );
  }
} 