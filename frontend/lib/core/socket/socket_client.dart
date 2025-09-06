import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:zvonilka/core/config/api_config.dart';
import 'package:zvonilka/core/services/auth_service.dart';

class SocketClient with ChangeNotifier {
  IO.Socket? _socket;
  String? _token;
  bool _isConnected = false;
  final AuthService _authService;

  bool get isConnected => _isConnected;

  SocketClient(this._authService) {
    _authService.addListener(_handleAuthChange);
    _token = _authService.accessToken; // Инициализируем с текущим токеном
    _initializeSocket(); // Создаем сокет, но не подключаемся

    // Если токен уже есть при запуске, пытаемся подключиться
    if (_token != null && _token!.isNotEmpty) {
      connect();
    }
  }

  void _initializeSocket() {
    if (_socket != null) return;

    _socket = IO.io(
      ApiConfig.currentBackendUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect() // Важно: не подключаемся автоматически
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      notifyListeners();
    });
    _socket!.onDisconnect((_) {
      _isConnected = false;
      notifyListeners();
    });
    _socket!.onError((error) => print('🔥 SocketClient: Ошибка: $error'));
  }

  void _handleAuthChange() {
    final newAccessToken = _authService.accessToken;

    if (newAccessToken == _token && _socket?.connected == true) {
      return;
    }

    _token = newAccessToken;

    if (_token != null && _token!.isNotEmpty) {
      if (_socket == null) {
        _initializeSocket();
      }
      _socket!.auth = {'token': _token};
      if (_socket!.connected) {
        _socket!.disconnect();
      }
      _socket!.connect();
    } else {
      disconnect();
    }
  }

  void connect() {
    if (_token == null || _token!.isEmpty) {
      return;
    }
    if (_socket?.connected == false) {
      _socket!.auth = {'token': _token};
      _socket!.connect();
    }
  }

  void disconnect() {
    _socket?.disconnect();
  }
  
  void dispose() {
    _authService.removeListener(_handleAuthChange);
    _socket?.dispose();
    super.dispose();
  }

  IO.Socket? get socket => _socket;
} 