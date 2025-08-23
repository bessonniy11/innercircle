import 'package:flutter/material.dart';
import 'package:zvonilka/core/api/api_client.dart';
import 'package:zvonilka/features/auth/presentation/screens/login_screen.dart';
import 'package:zvonilka/core/widgets/app_logo.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _invitationCodeController = TextEditingController();
  final ApiClient _apiClient = ApiClient();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _invitationCodeController.dispose();
    super.dispose();
  }

  void _register() async {
    final String username = _usernameController.text;
    final String password = _passwordController.text;
    final String invitationCode = _invitationCodeController.text;

    try {
      final response = await _apiClient.dio.post('/users/register', data: {
        'username': username,
        'password': password,
        'invitationCode': invitationCode,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful! Please login.')),
      );
      Navigator.pop(context); // Go back to login screen
    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Регистрация в Звонилке'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Логотип приложения
            const AppLogo(
              size: 100,
              showTitle: true,
            ),
            const SizedBox(height: 32.0),
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
            const SizedBox(height: 16.0),
            TextField(
              controller: _invitationCodeController,
              decoration: const InputDecoration(
                labelText: 'Пригласительный код',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24.0),
            ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50), // full width button
              ),
              child: const Text('Зарегистрироваться'),
            ),
            const SizedBox(height: 16.0),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Go back to login screen
              },
              child: const Text('Уже есть аккаунт? Войти'),
            ),
          ],
        ),
      ),
    );
  }
} 