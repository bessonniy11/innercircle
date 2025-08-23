import 'package:flutter/material.dart';
import 'package:zvonilka/features/auth/presentation/screens/registration_screen.dart';
import 'package:zvonilka/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:zvonilka/core/api/api_client.dart';
import 'package:zvonilka/core/socket/socket_client.dart';
import 'package:zvonilka/core/widgets/app_logo.dart';

import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    // TODO: Dispose _socketClient if it has a dispose method or close connection
    super.dispose();
  }

  void _login() async {
    final String username = _usernameController.text;
    final String password = _passwordController.text;

    try {
      final apiClient = Provider.of<ApiClient>(context, listen: false);
      final socketClient = Provider.of<SocketClient>(context, listen: false);
      final response = await apiClient.dio.post('/auth/login', data: {'username': username, 'password': password});
      final String accessToken = response.data['access_token'];
      apiClient.setAuthToken(accessToken);
      socketClient.setToken(accessToken);
      socketClient.connect();
      
      // Decode JWT to get user ID
      final Map<String, dynamic> decodedToken = apiClient.decodeJwtToken(accessToken);
      final String currentUserId = decodedToken['sub']; // 'sub' is typically the user ID
      final String currentUsername = decodedToken['username']; // 'username' is typically the username


      // Navigate to chat list screen after successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatListScreen(
            currentUserId: currentUserId, // Pass the extracted user ID
            currentUsername: currentUsername, // Pass the extracted username
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка входа. Проверьте данные и подключение к серверу.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход в Звонилку'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Логотип приложения
            const AppLogo(
              size: 120,
              showTitle: true,
            ),
            const SizedBox(height: 48.0),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Имя пользователя',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16.0),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Пароль',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50), // full width button
              ),
              child: const Text('Войти'),
            ),
            const SizedBox(height: 16.0),
            TextButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const RegistrationScreen()));
              },
              child: const Text('У меня нет аккаунта? Зарегистрироваться'),
            ),
          ],
        ),
      ),
    );
  }
} 