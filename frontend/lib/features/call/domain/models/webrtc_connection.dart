import 'package:flutter/foundation.dart';

/// Модель WebRTC соединения для звонков
class WebRTCConnection {
  final String callId;
  final bool isConnected;
  final bool isMuted;
  final bool isSpeakerOn;
  final DateTime createdAt;

  const WebRTCConnection({
    required this.callId,
    this.isConnected = false,
    this.isMuted = false,
    this.isSpeakerOn = true,
    required this.createdAt,
  });

  /// Создание нового соединения
  factory WebRTCConnection.create(String callId) {
    return WebRTCConnection(
      callId: callId,
      createdAt: DateTime.now(),
    );
  }

  /// Копирование с изменениями
  WebRTCConnection copyWith({
    String? callId,
    bool? isConnected,
    bool? isMuted,
    bool? isSpeakerOn,
    DateTime? createdAt,
  }) {
    return WebRTCConnection(
      callId: callId ?? this.callId,
      isConnected: isConnected ?? this.isConnected,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Переключение микрофона
  WebRTCConnection toggleMute() {
    return copyWith(isMuted: !isMuted);
  }

  /// Переключение динамика
  WebRTCConnection toggleSpeaker() {
    return copyWith(isSpeakerOn: !isSpeakerOn);
  }

  /// Установка статуса подключения
  WebRTCConnection setConnected(bool connected) {
    return copyWith(isConnected: connected);
  }

  /// Проверка, готово ли соединение для установки
  bool get isReadyForConnection => false;

  /// Проверка, можно ли завершить соединение
  bool get canDisconnect => false;

  /// Получение длительности соединения
  Duration get duration {
    return DateTime.now().difference(createdAt);
  }

  /// Очистка ресурсов
  Future<void> dispose() async {
    // Заглушка для базовой реализации
  }

  /// Инициализация WebRTC с учетом платформы
  Future<void> initializeWebRTC() async {
    if (kIsWeb) {
      debugPrint('🌐 WebRTC не поддерживается на вебе в текущей версии');
      // На вебе показываем сообщение о том, что звонки не поддерживаются
    } else {
      debugPrint('📱 WebRTC инициализация на мобильном устройстве');
      // TODO: Реализовать полноценную инициализацию для мобильных устройств
    }
  }

  /// Начало звонка с учетом платформы
  Future<void> startCall() async {
    if (kIsWeb) {
      debugPrint('🌐 Звонки не поддерживаются на вебе');
      // TODO: Показать уведомление пользователю
    } else {
      debugPrint('📱 Начало звонка на мобильном устройстве');
      // TODO: Реализовать полноценное начало звонка для мобильных устройств
    }
  }

  /// Ответ на звонок с учетом платформы
  Future<void> answerCall() async {
    if (kIsWeb) {
      debugPrint('🌐 Звонки не поддерживаются на вебе');
      // TODO: Показать уведомление пользователю
    } else {
      debugPrint('📱 Ответ на звонок на мобильном устройстве');
      // TODO: Реализовать полноценный ответ на звонок для мобильных устройств
    }
  }

  @override
  String toString() {
    return 'WebRTCConnection(callId: $callId, connected: $isConnected, muted: $isMuted, duration: ${duration.inSeconds}s)';
  }
}

/// Конфигурация WebRTC для звонков
class WebRTCConfig {
  /// STUN серверы для NAT traversal
  static const List<Map<String, dynamic>> iceServers = [
    {
      'urls': [
        'stun:stun.l.google.com:19302',
        'stun:stun1.l.google.com:19302',
        'stun:stun2.l.google.com:19302',
      ],
    },
    // В будущем добавим TURN серверы для сложных сетей
    // {'urls': 'turn:your-turn-server.com:3478', 'username': 'username', 'credential': 'password'},
  ];

  /// Конфигурация peer connection
  static const Map<String, dynamic> peerConnectionConfig = {
    'iceServers': iceServers,
    'iceCandidatePoolSize': 10,
    'bundlePolicy': 'balanced',
    'rtcpMuxPolicy': 'require',
    'iceTransportPolicy': 'all',
    'sdpSemantics': 'unifiedPlan',
  };

  /// Ограничения для медиа потоков
  static const Map<String, dynamic> mediaConstraints = {
    'audio': true,
    'video': false, // Пока только голосовые звонки
  };

  /// Ограничения для создания offer
  static const Map<String, dynamic> offerOptions = {
    'offerToReceiveAudio': true,
    'offerToReceiveVideo': false,
    'voiceActivityDetection': true,
    'iceRestart': false,
  };

  /// Ограничения для создания answer
  static const Map<String, dynamic> answerOptions = {
    'voiceActivityDetection': true,
  };
}
