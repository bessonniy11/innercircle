import 'package:flutter/material.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/socket/socket_client.dart';
import 'package:frontend/features/chat/presentation/screens/message_screen.dart';
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
        _chats = fetchedChats.map((e) => e as Map<String, dynamic>).toList(); // Преобразуем к List<Map<String, dynamic>>
        // Логика familyChatId и familyChatName больше не нужна здесь
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching chats: $e'); // Для отладки
      if (!mounted) return; // Проверяем mounted перед показом SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить чаты: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToMessageScreen(String chatId, String chatName) {
    final apiClient = Provider.of<ApiClient>(context, listen: false);
    final socketClient = Provider.of<SocketClient>(context, listen: false);

    Navigator.push(context, MaterialPageRoute(builder: (context) => MessageScreen(
      chatId: chatId,
      chatName: chatName,
      apiClient: apiClient,
      socketClient: socketClient,
      currentUserId: widget.currentUserId,
      currentUsername: widget.currentUsername,
    )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои Чаты'),
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
                    final chat = _chats[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(chat['name'] != null && chat['name'].isNotEmpty ? chat['name'][0].toUpperCase() : '?'),
                        ),
                        title: Text(chat['name'] ?? 'Без имени', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(chat['isPrivate'] == true ? 'Личный чат' : 'Групповой чат'), // Отображаем тип чата
                        onTap: () {
                          // Теперь мы просто переходим в MessageScreen для любого чата
                          _navigateToMessageScreen(chat['id'], chat['name']);
                        },
                      ),
                    );
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