import 'package:flutter/material.dart';
import 'package:zvonilka/core/api/api_client.dart';
import 'package:zvonilka/core/socket/socket_client.dart';
import 'package:zvonilka/features/chat/domain/models/message_model.dart'; // Import MessageModel

class MessageScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final ApiClient apiClient;
  final SocketClient socketClient;
  final String currentUserId;
  final String currentUsername;

  const MessageScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.apiClient,
    required this.socketClient,
    required this.currentUserId,
    required this.currentUsername,
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
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
      final response = await widget.apiClient.dio.get(
        '/messages/${widget.chatId}',
      );
      final List<dynamic> messageData = response.data; // Ожидаем массив сообщений напрямую
      setState(() {
        _messages.clear();
        _messages.addAll(messageData.map((json) => Message.fromJson(json)).toList());
        _isLoading = false;
      });
      
      // Отмечаем сообщения как прочитанные после загрузки
      _markMessagesAsRead();
      
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load messages: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Отмечает сообщения в текущем чате как прочитанные
  void _markMessagesAsRead() {
    widget.socketClient.socket.emit('markAsRead', {
      'chatId': widget.chatId,
    });
  }

  void _setupSocketListeners() {
    widget.socketClient.socket.on('messageReceived', (data) {
      // Parse message directly from data, as backend sends full message object
      final receivedMessage = Message.fromJson(data);

      // Check if the widget is still mounted before calling setState
      if (!mounted) {
        return;
      }

      // Prevent duplicating sender's own messages that were optimistically added
      if (receivedMessage.senderId == widget.currentUserId) {
        return;
      }

      if (receivedMessage.chatId == widget.chatId) {
        setState(() {
          _messages.add(receivedMessage);
        });
        
        // Отмечаем как прочитанные новые сообщения
        _markMessagesAsRead();
        
        _scrollToBottom();
      }
    });
  }

  void _sendMessage() {
    final String messageContent = _messageController.text.trim();
    if (messageContent.isNotEmpty) {
      // Optimistic update: add message to the list immediately
      final optimisticMessage = Message(
        id: DateTime.now().toIso8601String(), // Temporary ID
        content: messageContent,
        senderId: widget.currentUserId,
        senderUsername: widget.currentUsername,
        chatId: widget.chatId,
        createdAt: DateTime.now(),
      );
      setState(() {
        _messages.add(optimisticMessage);
      });
      _scrollToBottom();

      // Emit message to the backend
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
                                message.senderUsername, // Display full username
                                style: const TextStyle(fontSize: 12.0, color: Colors.black54),
                              ),
                              Text(
                                message.content,
                                style: const TextStyle(fontSize: 16.0),
                              ),
                              Text(
                                '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
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