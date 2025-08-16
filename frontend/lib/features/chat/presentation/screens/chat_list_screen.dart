import 'package:flutter/material.dart';
import 'package:frontend/features/chat/presentation/screens/message_screen.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/socket/socket_client.dart';

class ChatListScreen extends StatefulWidget {
  final ApiClient apiClient;
  final SocketClient socketClient;

  const ChatListScreen({super.key, required this.apiClient, required this.socketClient});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // TODO: Implement fetching chat list logic

  final List<Map<String, String>> _dummyChats = [
    {'id': 'chat1', 'name': 'Семейный Чат'},
    {'id': 'chat2', 'name': 'Друзья'},
    {'id': 'chat3', 'name': 'Работа'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои Чаты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment),
            onPressed: () {
              // TODO: Implement create new chat logic
              debugPrint('Create new chat');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // TODO: Implement logout logic
              debugPrint('Logout');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _dummyChats.length,
              itemBuilder: (context, index) {
                final chat = _dummyChats[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.group),
                    ),
                    title: Text(chat['name']!),
                    subtitle: const Text('Последнее сообщение...'), // TODO: Display last message
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MessageScreen(
                            chatId: chat['id']!,
                            chatName: chat['name']!,
                            apiClient: widget.apiClient, // Pass apiClient
                            socketClient: widget.socketClient, // Pass socketClient
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 