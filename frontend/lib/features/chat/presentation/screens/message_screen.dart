import 'package:flutter/material.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/socket/socket_client.dart';
import 'package:frontend/features/chat/domain/models/message_model.dart';

class MessageScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final ApiClient apiClient;
  final SocketClient socketClient;

  const MessageScreen({super.key, required this.chatId, required this.chatName, required this.apiClient, required this.socketClient});

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _messageController.dispose();
    widget.socketClient.socket.off('messageReceived'); // Remove listener
    // TODO: Dispose socketClient and apiClient if they are not singleton or managed globally
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    try {
      final response = await widget.apiClient.dio.get(
        '/messages/${widget.chatId}',
      );
      final List<dynamic> messageData = response.data['data']; // Assuming 'data' field in response
      setState(() {
        _messages.addAll(messageData.map((json) => Message.fromJson(json)).toList());
      });
    } catch (e) {
      debugPrint('Failed to fetch messages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load messages: ${e.toString()}')),
      );
    }
  }

  void _setupSocketListeners() {
    widget.socketClient.socket.on('messageReceived', (data) {
      debugPrint('Message received: $data');
      final receivedMessage = Message.fromJson(data['data']); // Assuming 'data' field in response
      if (receivedMessage.chatId == widget.chatId) {
        setState(() {
          _messages.add(receivedMessage);
        });
      }
    });
  }

  void _sendMessage() {
    final String messageContent = _messageController.text;
    if (messageContent.isNotEmpty) {
      widget.socketClient.socket.emit('sendMessage', {
        'chatId': widget.chatId,
        'content': messageContent,
      });
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatName),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              reverse: true, // Show latest messages at the bottom
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index]; // Display in reverse order
                final isMe = message.senderId == 'CURRENT_USER_ID'; // TODO: Replace with actual current user ID
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue[100] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(message.senderUsername, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 4.0),
                        Text(message.content),
                        const SizedBox(height: 4.0),
                        Text(
                          '${message.createdAt.hour}:${message.createdAt.minute}',
                          style: TextStyle(fontSize: 10, color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Введите сообщение...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 