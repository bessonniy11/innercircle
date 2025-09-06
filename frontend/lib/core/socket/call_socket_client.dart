import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';
import 'package:zvonilka/core/config/api_config.dart';

/// WebSocket клиент для WebRTC сигналинга звонков
/// Подключается к отдельному namespace /calls
class CallSocketClient {
  IO.Socket? _socket;
  String? _token;
  bool _isConnected = false;

  /// Подключение к namespace звонков
  void connect(String token) {
    final backendUrl = ApiConfig.currentBackendUrl;
    debugPrint('🔔 CallSocket: Попытка подключения к namespace /calls');
    debugPrint('🔔 CallSocket: Backend URL: $backendUrl');
    debugPrint('🔔 CallSocket: Токен: ${token.substring(0, 10)}...');
    
    if (_isConnected) {
      debugPrint('🔔 CallSocket: Уже подключен к namespace /calls');
      return;
    }

    if (token.isEmpty) {
      debugPrint('🔥 CallSocket: Ошибка: пустой токен');
      return;
    }

    _token = token;
    
    try {
      final backendUrl = ApiConfig.currentBackendUrl;
      debugPrint('🔔 CallSocket: Создаю Socket.IO соединение к $backendUrl/calls');
      
      _socket = IO.io('$backendUrl/calls', <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'auth': {
          'token': token,
        },
        'forceNew': true, // Принудительно создаем новое соединение
        'reconnection': true,
        'reconnectionAttempts': 5,
        'reconnectionDelay': 1000,
      });

      debugPrint('🔔 CallSocket: Socket.IO объект создан, настраиваю слушатели событий');
      _setupEventListeners();
      
      // Проверяем статус подключения
      if (_socket!.connected) {
        _isConnected = true;
        debugPrint('🔔 CallSocket: Подключение к namespace /calls установлено (немедленно)');
      } else {
        debugPrint('🔔 CallSocket: Socket.IO создан, ожидаю события подключения...');
      }
      
    } catch (e) {
      debugPrint('🔥 CallSocket: Ошибка подключения: $e');
      _isConnected = false;
    }
  }

  /// Настройка слушателей событий
  void _setupEventListeners() {
    if (_socket == null) {
      debugPrint('🔥 CallSocket: Не удалось настроить слушатели - socket == null');
      return;
    }

    debugPrint('🔔 CallSocket: Настраиваю слушатели событий Socket.IO');

    // Подключение
    _socket!.onConnect((_) {
      debugPrint('🔔 CallSocket: ✅ Подключен к namespace /calls');
      _isConnected = true;
    });

    // Отключение
    _socket!.onDisconnect((_) {
      debugPrint('🔔 CallSocket: ❌ Отключен от namespace /calls');
      _isConnected = false;
    });

    // Ошибки
    _socket!.onError((error) {
      debugPrint('🔥 CallSocket: Ошибка Socket.IO: $error');
    });

    // Событие connect_error
    _socket!.onConnectError((error) {
      debugPrint('🔥 CallSocket: Ошибка подключения: $error');
    });

    // Событие reconnect
    _socket!.onReconnect((_) {
      debugPrint('🔔 CallSocket: Переподключение к namespace /calls');
      _isConnected = true;
    });

    // Событие reconnect_error
    _socket!.onReconnectError((error) {
      debugPrint('🔥 CallSocket: Ошибка переподключения: $error');
    });

    // Входящий звонок
    _socket!.on('incoming_call', (data) {
      debugPrint('🔔 CallSocket: Входящий звонок: $data');
      // TODO: Обработка входящего звонка
    });

    // Изменение статуса звонка
    _socket!.on('call_status_changed', (data) {
      debugPrint('🔔 CallSocket: Статус звонка изменился: $data');
      // TODO: Обработка изменения статуса
    });

    // Завершение звонка
    _socket!.on('call_ended', (data) {
      debugPrint('🔔 CallSocket: Звонок завершен: $data');
      // TODO: Обработка завершения звонка
    });

    // Подтверждение подключения к комнате звонка
    _socket!.on('joined_call_room', (data) {
      debugPrint('🔔 CallSocket: Подключен к комнате звонка: $data');
    });

    // Подтверждение выхода из комнаты звонка
    _socket!.on('left_call_room', (data) {
      debugPrint('🔔 CallSocket: Покинул комнату звонка: $data');
    });

    debugPrint('🔔 CallSocket: Все слушатели событий настроены');
  }

  /// Подключение к комнате конкретного звонка
  void joinCallRoom(String callId) {
    if (!_isConnected || _socket == null) {
      debugPrint('🔥 CallSocket: Не подключен к namespace /calls');
      return;
    }

    debugPrint('🔔 CallSocket: Подключаюсь к комнате звонка: $callId');
    _socket!.emit('join_call_room', {'callId': callId});
  }

  /// Выход из комнаты звонка
  void leaveCallRoom(String callId) {
    if (!_isConnected || _socket == null) {
      debugPrint('🔥 CallSocket: Не подключен к namespace /calls');
      return;
    }

    debugPrint('🔔 CallSocket: Покидаю комнату звонка: $callId');
    _socket!.emit('leave_call_room', {'callId': callId});
  }

  /// Отправка SDP Offer
  void sendSdpOffer(String callId, String sdp) {
    if (!_isConnected || _socket == null) {
      debugPrint('🔥 CallSocket: Не подключен к namespace /calls');
      return;
    }

    debugPrint('🔔 CallSocket: Отправляю SDP Offer для звонка: $callId');
    _socket!.emit('sdp_offer', {
      'callId': callId,
      'sdp': sdp,
    });
  }

  /// Отправка SDP Answer
  void sendSdpAnswer(String callId, String sdp) {
    if (!_isConnected || _socket == null) {
      debugPrint('🔥 CallSocket: Не подключен к namespace /calls');
      return;
    }

    debugPrint('🔔 CallSocket: Отправляю SDP Answer для звонка: $callId');
    _socket!.emit('sdp_answer', {
      'callId': callId,
      'sdp': sdp,
    });
  }

  /// Отправка ICE Candidate
  void sendIceCandidate(String callId, String candidate) {
    if (!_isConnected || _socket == null) {
      debugPrint('🔥 CallSocket: Не подключен к namespace /calls');
      return;
    }

    debugPrint('🔔 CallSocket: Отправляю ICE Candidate для звонка: $callId');
    _socket!.emit('ice_candidate', {
      'callId': callId,
      'candidate': candidate,
    });
  }

  /// Отключение от namespace звонков
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
      _isConnected = false;
      _token = null;
      debugPrint('🔔 CallSocket: Отключен от namespace /calls');
    }
  }

  /// Проверка статуса подключения
  bool get isConnected => _isConnected;

  /// Получение текущего токена
  String? get token => _token;

  /// Очистка токена (при logout)
  void clearToken() {
    _token = null;
    debugPrint('🔔 CallSocket: Токен очищен');
  }

  /// Подписка на события (для WebRTC сервиса)
  void on(String event, Function(dynamic) handler) {
    if (_socket != null) {
      _socket!.on(event, handler);
    } else {
      debugPrint('🔥 CallSocket: Не удалось подписаться на $event - socket == null');
    }
  }

  /// Отправка событий (для WebRTC сервиса)
  void emit(String event, [dynamic data]) {
    if (_isConnected && _socket != null) {
      _socket!.emit(event, data);
      debugPrint('🔔 CallSocket: Отправлено событие: $event с данными: $data');
    } else {
      debugPrint('🔥 CallSocket: Не удалось отправить $event - не подключен');
    }
  }
}
