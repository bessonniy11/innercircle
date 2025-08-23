import 'package:flutter/material.dart';
import 'package:zvonilka/core/api/api_client.dart';
import 'package:zvonilka/core/socket/socket_client.dart';
import 'package:zvonilka/features/chat/presentation/screens/message_screen.dart';
import 'package:zvonilka/features/chat/presentation/screens/user_list_screen.dart'; // Импорт UserListScreen
import 'package:zvonilka/core/widgets/app_logo.dart';
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

class _ChatListScreenState extends State<ChatListScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _chats = []; // Переменная для хранения загруженных чатов
  bool _isLoading = true;
  // Удаляем _familyChatId и _familyChatName, так как теперь чаты будут обрабатываться универсально

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchChats();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Если приложение возвращается из фона или предыдущий экран закрыт
      _fetchChats();
    }
  }

  Future<void> _fetchChats() async {
    if (!mounted) return; // Проверяем, что виджет еще смонтирован
    setState(() {
      _isLoading = true;
    });
    try {
      final apiClient = Provider.of<ApiClient>(context, listen: false);
      final response = await apiClient.dio.get('/chats');
      final List<dynamic> fetchedChats = response.data;
      
      if (!mounted) return; // Проверяем mounted снова после async операции
      setState(() {
        _chats = fetchedChats.map((e) {
          if (e is Map<String, dynamic>) {
            return e;
          } else {
            debugPrint('Invalid chat format: $e');
            return <String, dynamic>{};
          }
        }).where((chat) => chat.isNotEmpty).toList();
        
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching chats: $e'); // Для отладки
      if (!mounted) return; // Проверяем mounted перед показом SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить чаты: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToMessageScreen(String chatId, String chatName) async {
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    final socketClient = Provider.of<SocketClient>(context, listen: false);

    // Ждем пока пользователь вернется из MessageScreen
    await Navigator.push(context, MaterialPageRoute(builder: (context) => MessageScreen(
      chatId: chatId,
      chatName: chatName,
      apiClient: apiClient,
      socketClient: socketClient,
      currentUserId: widget.currentUserId,
      currentUsername: widget.currentUsername,
    )));
    
    // После возвращения обновляем список чатов
    if (mounted) {
      _fetchChats();
    }
  }

  /**
   * Создает подзаголовок для чата с последним сообщением
   */
  Widget _buildChatSubtitle(Map<String, dynamic> chat) {
    try {
      final lastMessage = chat['lastMessage'];
      final chatType = chat['isPrivate'] == true ? 'Личный чат' : 'Групповой чат';
      
      if (lastMessage != null && lastMessage is Map<String, dynamic>) {
        final senderName = lastMessage['sender']?['username']?.toString() ?? 'Неизвестно';
        final content = lastMessage['content']?.toString() ?? '';
        final senderId = lastMessage['senderId']?.toString() ?? '';
        final isMyMessage = senderId == widget.currentUserId;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(chatType, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(
              isMyMessage ? 'Вы: $content' : '$senderName: $content',
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      } else {
        return Text(chatType, style: TextStyle(fontSize: 14, color: Colors.grey[600]));
      }
    } catch (e) {
      debugPrint('Error in _buildChatSubtitle: $e');
      return Text('Групповой чат', style: TextStyle(fontSize: 14, color: Colors.grey[600]));
    }
  }

  /**
   * Создает правую часть элемента чата (время, непрочитанные)
   */
  Widget _buildChatTrailing(Map<String, dynamic> chat) {
    try {
      final lastMessage = chat['lastMessage'];
      final unreadCount = (chat['unreadCount'] as num?)?.toInt() ?? 0;
      
      if (lastMessage != null && lastMessage is Map<String, dynamic>) {
        final createdAtString = lastMessage['createdAt']?.toString();
        if (createdAtString == null) {
          return const SizedBox.shrink();
        }
        
        final createdAt = DateTime.parse(createdAtString).toLocal();
        final timeString = _formatMessageTime(createdAt);
        
        return SizedBox(
          width: 60, // Ограничиваем ширину trailing элемента
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                timeString,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (unreadCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                    maxWidth: 50, // Ограничиваем максимальную ширину бейджа
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
      
      return const SizedBox.shrink();
    } catch (e) {
      debugPrint('Error in _buildChatTrailing: $e');
      return const SizedBox.shrink();
    }
  }

  /**
   * Форматирует время сообщения для отображения
   */
  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      // Сегодня - показываем время
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Вчера
      return 'Вчера';
    } else if (now.difference(dateTime).inDays < 7) {
      // На этой неделе - показываем день недели
      const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      return weekdays[dateTime.weekday - 1];
    } else {
      // Давно - показываем дату
      return '${dateTime.day.toString().padLeft(2, '0')}.${dateTime.month.toString().padLeft(2, '0')}';
    }
  }

  /**
   * Показывает диалог подтверждения удаления чата
   */
  void _showDeleteChatDialog(String chatId, String chatName) {
    // Запрещаем удаление семейного чата
    if (chatName == 'Семейный Чат') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нельзя удалить семейный чат'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Удалить чат?'),
          content: Text('Вы уверены, что хотите удалить чат "$chatName"?\n\nВсе сообщения будут потеряны безвозвратно.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрываем диалог
              },
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрываем диалог
                _deleteChat(chatId, chatName); // Удаляем чат
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );
  }

  /**
   * Удаляет чат через API
   */
  Future<void> _deleteChat(String chatId, String chatName) async {
    try {
      final apiClient = Provider.of<ApiClient>(context, listen: false);
      
      await apiClient.dio.delete('/chats/$chatId');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Чат "$chatName" удален'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Обновляем список чатов
        _fetchChats();
      }
    } catch (e) {
      debugPrint('Error deleting chat: $e');
      if (mounted) {
        String errorMessage = 'Не удалось удалить чат';
        
        // Проверяем тип ошибки для более понятного сообщения
        if (e.toString().contains('403')) {
          errorMessage = 'Нет прав на удаление этого чата';
        } else if (e.toString().contains('404')) {
          errorMessage = 'Чат не найден';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBarLogo(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), // Добавляем кнопку обновления
            onPressed: _fetchChats,
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
                    try {
                      final chat = _chats[index];
                      final chatName = chat['name']?.toString() ?? 'Без имени';
                      final chatId = chat['id']?.toString();
                      
                      if (chatId == null) {
                        debugPrint('Chat without ID at index $index: $chat');
                        return const SizedBox.shrink();
                      }
                      
                      return Card(
                        margin: const EdgeInsets.all(8.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(chatName.isNotEmpty ? chatName[0].toUpperCase() : '?'),
                          ),
                          title: Text(chatName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: _buildChatSubtitle(chat),
                          trailing: _buildChatTrailing(chat),
                          onTap: () {
                            _navigateToMessageScreen(chatId, chatName);
                          },
                          onLongPress: () {
                            _showDeleteChatDialog(chatId, chatName);
                          },
                        ),
                      );
                    } catch (e) {
                      debugPrint('Error building chat item at index $index: $e');
                      return const SizedBox.shrink();
                    }
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Ждем, пока UserListScreen вернет результат (если пользователь выбрал юзера)
          await Navigator.push(context, MaterialPageRoute(builder: (context) => UserListScreen(currentUserId: widget.currentUserId, currentUsername: widget.currentUsername)));
          // После возвращения из UserListScreen, обновляем список чатов
          _fetchChats();
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
} 