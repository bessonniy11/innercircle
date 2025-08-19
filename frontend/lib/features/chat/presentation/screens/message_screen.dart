import 'package:flutter/material.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/socket/socket_client.dart';
import 'package:frontend/features/chat/domain/models/message_model.dart';

class MessageScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final ApiClient apiClient;
  final SocketClient socketClient;
  final String currentUserId;

  const MessageScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.apiClient,
    required this.socketClient,
    required this.currentUserId,
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Message> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

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
    widget.socketClient.socket.off('messageReceived');
    // TODO: Dispose socketClient and apiClient if they are not singleton or managed globally
    super.dispose();
  }

  Future<void> _fetchMessages() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final response = await widget.apiClient.dio.get(
        '/messages/${widget.chatId}',
      );
      final List<dynamic> messageData = response.data;
      setState(() {
        _messages.addAll(messageData.map((json) => Message.fromJson(json)).toList());
        _scrollToBottom();
      });
    } catch (e) {
      debugPrint('Failed to fetch messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось загрузить сообщения: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupSocketListeners() {
    widget.socketClient.socket.on('messageReceived', (data) {
      debugPrint('Message received: $data');
      final receivedMessage = Message.fromJson(data);
      if (receivedMessage.chatId == widget.chatId) {
        setState(() {
          _messages.add(receivedMessage);
        });
        _scrollToBottom();
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                final message = _messages[_messages.length - 1 - index]; // Display in reverse order
                final isMe = message.senderId == widget.currentUserId; // Corrected: Use actual current user ID
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
} 