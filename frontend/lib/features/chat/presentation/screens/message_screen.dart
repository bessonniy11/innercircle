import 'package:flutter/material.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/socket/socket_client.dart';
import 'package:frontend/features/chat/domain/models/message_model.dart'; // Import MessageModel

class MessageScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final ApiClient apiClient;
  final SocketClient socketClient;
  final String currentUserId;

  const MessageScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
    required this.apiClient,
    required this.socketClient,
    required this.currentUserId,
  }) : super(key: key);

  @override
  _MessageScreenState createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _fetchMessages() async {
    try {
      setState(() {
        _isLoading = true;
      });
      final response = await widget.apiClient.get('/messages/${widget.chatId}');
      final List<dynamic> fetchedMessages = response.data;
      setState(() {
        _messages.clear();
        _messages.addAll(fetchedMessages.map((msg) => Message.fromJson(msg)));
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      print('Failed to fetch messages: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить сообщения: $e')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupSocketListeners() {
    widget.socketClient.socket.on('messageReceived', (data) {
      print('Message received via socket: $data');
      // Ensure the message is for the current chat before adding
      if (data != null && data['chatId'] == widget.chatId) {
        setState(() {
          _messages.add(Message.fromJson(data));
        });
        _scrollToBottom();
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      final messageData = {
        'chatId': widget.chatId,
        'content': text,
        'senderId': widget.currentUserId, // Use the actual current user ID
      };
      widget.socketClient.socket.emit('sendMessage', messageData);
      _messageController.clear();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatName),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isCurrentUser = message.senderId == widget.currentUserId;
                      return Align(
                        alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(10.0),
                          decoration: BoxDecoration(
                            color: isCurrentUser ? Colors.blue[100] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Column(
                            crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.senderId.substring(0, 8), // Display first 8 chars of sender ID for now
                                style: const TextStyle(fontSize: 12.0, color: Colors.black54),
                              ),
                              Text(
                                message.content,
                                style: const TextStyle(fontSize: 16.0),
                              ),
                              Text(
                                '${message.createdAt.hour}:${message.createdAt.minute}',
                                style: const TextStyle(fontSize: 10.0, color: Colors.black45),
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
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Введите сообщение...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 