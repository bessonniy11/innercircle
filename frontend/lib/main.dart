import 'package:flutter/material.dart';
import 'package:frontend/features/auth/presentation/screens/login_screen.dart';
import 'package:provider/provider.dart'; // Импортируем Provider
import 'package:frontend/core/api/api_client.dart'; // Импортируем ApiClient
import 'package:frontend/core/socket/socket_client.dart'; // Импортируем SocketClient

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(
          create: (_) => ApiClient(),
        ),
        Provider<SocketClient>(
          create: (_) => SocketClient(),
        ),
      ],
      child: MaterialApp(
        title: 'Messenger App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
