import 'package:flutter/material.dart';
import 'package:frontend/features/auth/presentation/screens/registration_screen.dart';
import 'package:frontend/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/socket/socket_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ApiClient _apiClient = ApiClient();
  final SocketClient _socketClient = SocketClient();

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
      final response = await _apiClient.dio.post('/auth/login', data: {'username': username, 'password': password});
      final String accessToken = response.data['access_token'];
      _apiClient.setAuthToken(accessToken);
      _socketClient.setToken(accessToken);
      _socketClient.connect();
      debugPrint('Login successful! Token: $accessToken');
      // Navigate to chat list screen after successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatListScreen(apiClient: _apiClient, socketClient: _socketClient),
        ),
      );
    } catch (e) {
      debugPrint('Login failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login failed. Please check your credentials.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Вход в Мессенджер'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
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