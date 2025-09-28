import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:zvonilka/core/config/api_config.dart';
import 'package:zvonilka/core/services/auth_service.dart';
import 'dart:async';

/// WebSocket клиент для WebRTC сигналинга звонков
/// Подключается к отдельному namespace /calls
/// Использует ChangeNotifier для уведомления о статусе подключения
class CallSocketClient with ChangeNotifier {
  IO.Socket? _socket;
  String? _token;
  bool _isConnected = false;
  final AuthService _authService;

  // НОВЫЕ ПОЛЯ ДЛЯ УПРАВЛЕНИЯ ПОДКЛЮЧЕНИЕМ
  Completer<void>? _connectionCompleter;
  bool _isConnecting = false;

  bool get isConnected => _isConnected;
  IO.Socket? get socket => _socket;

  CallSocketClient(this._authService) {
    _authService.addListener(_handleAuthChange);
    _token = _authService.accessToken; // Инициализируем с текущим токеном
    _initializeSocket(); // Создаем сокет, но не подключаемся

    // Если токен уже есть при запуске, пытаемся подключиться
    if (_token != null && _token!.isNotEmpty) {
      connect();
    }
  }

  void _initializeSocket() {
    if (_socket != null) return; // Уже инициализирован

    final String backendUrl = ApiConfig.currentBackendUrl;
    
    _socket = IO.io('$backendUrl/calls', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false, // ВАЖНО: подключаемся вручную через connect()
      'auth': {'token': _token},
    });

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

    _socket!.onError((error) => print('🔥 CallSocket: Ошибка: $error'));
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

  void _handleAuthChange() {
    final newAccessToken = _authService.accessToken;

    // Проверяем, действительно ли токен изменился
    if (newAccessToken == _token && _socket?.connected == true) {
      return;
    }

    _token = newAccessToken;

    if (_token != null && _token!.isNotEmpty) {
      if (_socket == null) {
        _initializeSocket();
      }
      _socket!.auth = {'token': _token};
      
      // "Мягкий" реконнект: отключаемся и сразу подключаемся, чтобы применить новый токен
      if (_socket!.connected) {
        _socket!.disconnect();
      }
      connect(); // ИЗМЕНЕНО

    } else {
      disconnect();
    }
  }

  /// Отправка события через сокет
  void emit(String event, [dynamic data]) {
    if (_socket?.connected == true) {
      _socket!.emit(event, data);
      // Убираем избыточное логгирование, WebRTCService логирует подробнее
      // debugPrint('🔔 CallSocket: Отправлено событие: $event');
    } else {
      print('🔥 CallSocket: Не удалось отправить $event - не подключен');
    }
  }
  
  /// Подписка на событие
  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, (data) {
      // Добавляем логгирование входящих событий
      handler(data);
    });
  }

  /// Отписка от события
  void off(String event) {
    _socket?.off(event);
  }

  @override
  void dispose() {
    _authService.removeListener(_handleAuthChange);
    _socket?.dispose();
    super.dispose();
  }
}
