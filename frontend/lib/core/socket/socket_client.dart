import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:zvonilka/core/config/api_config.dart';
import 'package:zvonilka/core/services/auth_service.dart';
import 'dart:async';

class SocketClient with ChangeNotifier {
  IO.Socket? _socket;
  String? _token;
  bool _isConnected = false;
  final AuthService _authService;

  // НОВЫЕ ПОЛЯ ДЛЯ УПРАВЛЕНИЯ ПОДКЛЮЧЕНИЕМ
  Completer<void>? _connectionCompleter;
  bool _isConnecting = false;

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
      _isConnecting = false;
      _connectionCompleter?.complete();
      notifyListeners();
    });
    _socket!.onDisconnect((_) {
      _isConnected = false;
      _isConnecting = false;
      // Если было активное ожидание, завершаем его с ошибкой
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(Exception('Socket Disconnected'));
      }
      notifyListeners();
    });
    _socket!.onConnectError((error) {
      _isConnected = false;
      _isConnecting = false;
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(Exception('Socket Connect Error: $error'));
      }
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
      connect(); // ИЗМЕНЕНО
    } else {
      disconnect();
    }
  }

  void connect() {
    if (_isConnected || _isConnecting) {
      return; // Уже подключены или в процессе
    }
    if (_token == null || _token!.isEmpty) {
      return;
    }

    _isConnecting = true;
    _connectionCompleter = Completer<void>();
    
    if (_socket?.connected == false) {
      _socket!.auth = {'token': _token};
      _socket!.connect();
    }
  }

  /// НОВЫЙ МЕТОД: Гарантирует, что сокет подключен.
  /// Возвращает Future, который завершается при успешном подключении.
  Future<void> ensureConnected() {
    if (_isConnected) {
      return Future.value();
    }
    
    // Если подключение уже идет, возвращаем его Future
    if (_isConnecting && _connectionCompleter != null) {
      return _connectionCompleter!.future;
    }
    
    // Если не подключены и не в процессе, запускаем подключение
    connect();
    return _connectionCompleter?.future ?? Future.error(Exception("Socket client not initialized"));
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