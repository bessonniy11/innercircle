import 'dart:async';
import 'package:flutter/material.dart'; // ВОТ ОН, РОДИМЫЙ!
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../socket/call_socket_client.dart';
import '../api/api_client.dart';
import '../../features/call/presentation/screens/call_screen.dart'; // НОВЫЙ ИМПОРТ
import '../../main.dart'; // НОВЫЙ ИМПОРТ для navigatorKey
import './auth_service.dart'; // ИСПРАВЛЕННЫЙ ИМПОРТ
import '../../features/call/domain/models/call_model.dart'; // ВОТ ЧТО НУЖНО!
import '../../features/call/presentation/screens/incoming_call_screen.dart'; // НОВЫЙ ИМПОРТ
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart'; // <-- НАШ НОВЫЙ ИМПОРТ

enum CallState {
  idle,
  calling,
  incoming,
  connected,
  ended,
  error,
}

class WebRTCService extends ChangeNotifier {
  final CallSocketClient _callSocketClient;
  final ApiClient _apiClient;
  final AuthService _authService; // НОВЫЙ ПОЛЕ
  
  // WebRTC объекты
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  // Состояние звонка
  CallState _callState = CallState.idle;
  CallType _callType = CallType.voice; // ИСПРАВЛЕНО
  String? _currentCallId;
  String? _remoteUserId;
  String? _remoteUsername; // Добавляем имя удаленного пользователя
  
  // Таймеры
  Timer? _callTimer;
  Timer? _iceGatheringTimer;
  
  // Очередь ICE кандидатов для добавления после установки remote description
  final List<RTCIceCandidate> _pendingIceCandidates = [];
  
  // Буфер для исходящих ICE кандидатов до получения callId
  final List<RTCIceCandidate> _outgoingIceCandidatesBuffer = [];

  // Буфер для SDP Offer, если он придет раньше incoming_call
  Map<String, dynamic>? _bufferedSdpOffer;

  // Флаг для предотвращения многократного сброса состояния
  bool _isResetting = false;
  
  // Конфигурация WebRTC (по умолчанию)
  Map<String, dynamic> _rtcConfiguration = {
    'iceServers': [
      // Оставляем только один STUN-сервер Google как самый базовый фолбэк.
      // Основная конфигурация будет загружена с нашего бэкенда.
      {'urls': 'stun:stun.l.google.com:19302'},
    ],
    'iceCandidatePoolSize': 10,
  };

  WebRTCService(this._callSocketClient, this._apiClient, this._authService) { // ОБНОВЛЕННЫЙ КОНСТРУКТОР
    _callSocketClient.addListener(_onSocketConnectionChange);
    _onSocketConnectionChange(); // Проверяем состояние сразу
    _loadWebRTCConfig();
  }

  void _onSocketConnectionChange() {
    if (_callSocketClient.isConnected) {
      _setupSocketListeners();
    } else {
      _removeSocketListeners();
    }
  }

  // Геттеры
  CallState get callState => _callState;
  CallType get callType => _callType;
  String? get currentCallId => _currentCallId;
  String? get remoteUserId => _remoteUserId;
  String? get remoteUsername => _remoteUsername;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  RTCPeerConnection? get peerConnection => _peerConnection;
  
  // Загрузка WebRTC конфигурации с сервера
  Future<void> _loadWebRTCConfig() async {
    try {
      final response = await _apiClient.get('/calls/webrtc-config');
      
      if (response.statusCode == 200) {
        final config = response.data;
        if (config['iceServers'] != null) {
          _rtcConfiguration = config;
        }
      }
    } catch (e) {
      // Игнорируем ошибку, используем локальную конфигурацию
    }
  }

  // Настройка слушателей сокетов
  void _setupSocketListeners() {
    // УНИВЕРСАЛЬНЫЙ СЛУШАТЕЛЬ ДЛЯ ОТЛАДКИ БОЛЬШЕ НЕ НУЖЕН
    // _callSocketClient.socket!.onAny((event, data) {
    //   debugPrint('🕵️‍♂️ [WS ALL] Event: $event, Data: $data');
    // });

    _callSocketClient.on('incoming_call', _handleIncomingCall);
    _callSocketClient.on('call_accepted', _handleCallAccepted);
    _callSocketClient.on('call_rejected', _handleCallRejected);
    _callSocketClient.on('call_ended', _handleCallEnded);
    _callSocketClient.on('ice_candidate', _handleIceCandidate);
    _callSocketClient.on('sdp_offer', _handleSdpOffer); // ВОЗВРАЩАЕМ НАЗАД
    _callSocketClient.on('sdp_answer', _handleSdpAnswer); // ИСПРАВЛЕНО
    _callSocketClient.on('call_initiated', _handleCallInitiated);
  }

  void _removeSocketListeners() {
    // УДАЛЯЕМ УНИВЕРСАЛЬНЫЙ СЛУШАТЕЛЬ
    // _callSocketClient.socket!.offAny();

    _callSocketClient.off('incoming_call');
    _callSocketClient.off('call_accepted');
    _callSocketClient.off('call_rejected');
    _callSocketClient.off('call_ended');
    _callSocketClient.off('ice_candidate');
    _callSocketClient.off('sdp_offer'); // ВОЗВРАЩАЕМ НАЗАД
    _callSocketClient.off('sdp_answer'); // ИСПРАВЛЕНО
    _callSocketClient.off('call_initiated');
  }

  // НОВЫЙ ПУБЛИЧНЫЙ МЕТОД
  /// Обрабатывает данные о входящем звонке, полученные из Push-уведомления,
  /// когда приложение находится в foreground.
  void handleIncomingCallFromPush(Map<String, dynamic> data) {
    debugPrint('📞 [PUSH] Получены данные для входящего звонка: $data');
    // Мы просто переиспользуем существующую логику для WebSocket
    _handleIncomingCall(data);
  }

  // Инициация звонка
  Future<bool> initiateCall(String targetUserId, CallType callType) async {
    if (_callState != CallState.idle) {
      debugPrint('⚠️ Попытка инициировать звонок, когда состояние не idle: $_callState');
      return false;
    }

    try {
      _setCallState(CallState.calling);
      _remoteUserId = targetUserId;
      _callType = callType;

      // 1. Создаем звонок через REST API для запуска Push-уведомления
      final response = await _apiClient.post(
        '/calls/initiate',
        data: {
          'targetUserId': targetUserId,
          'type': callType.name,
        },
      );

      if (response.statusCode != 201) {
        throw Exception('Не удалось создать звонок на сервере');
      }

      final callData = response.data;
      _currentCallId = callData['id'];
      debugPrint('✅ Звонок успешно создан на сервере, Call ID: $_currentCallId');

      if (!await _requestPermissions(callType)) {
        debugPrint('❌ Не удалось получить разрешения на медиа');
        await endCall(); // Завершаем звонок, если нет разрешений
        return false;
      }

      await _createLocalStream();
      await _createPeerConnection();

      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          await _peerConnection!.addTrack(track, _localStream!);
        }
      }

      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      // 2. Отправляем SDP Offer через WebSocket, используя полученный callId
      _callSocketClient.emit('sdp_offer', {
        'callId': _currentCallId,
        'sdp': offer.toMap(),
        'receiverId': _remoteUserId,
      });
      debugPrint('✅ SDP Offer отправлен через WebSocket');

      return true;
    } catch (e) {
      debugPrint('🚨 Ошибка при инициации звонка: $e');
      await _resetCall();
      return false;
    }
  }

  // Принятие входящего звонка
  Future<bool> acceptCall() async {
    if (_callState != CallState.incoming || _peerConnection == null) {
      debugPrint(
          '⚠️ Попытка принять звонок в неверном состоянии: $_callState или без peer connection');
      return false;
    }

    // Останавливаем рингтон при принятии
    FlutterRingtonePlayer().stop();

    try {
      // НОВОЕ: Отправляем событие о принятии звонка НА СЕРВЕР
      if (_currentCallId != null) {
        _callSocketClient.emit('accept_call', {
          'callId': _currentCallId,
          'callerId': _remoteUserId, // Указываем, чей звонок мы принимаем
        });
        debugPrint('✅ [WS] Отправлено событие accept_call');
      }

      // Запрос разрешений
      if (!await _requestPermissions(_callType)) {
        debugPrint('❌ Не удалось получить медиа-разрешения для ответа на звонок');
        await rejectCall(); // Отклоняем, если нет разрешений
        return false;
      }

      // Создание локального медиа потока
      await _createLocalStream();

      // Добавление локального потока
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          _peerConnection!.addTrack(track, _localStream!);
        }
      }

      // Создание и отправка SDP answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Отправка SDP answer через сокет
      _callSocketClient.emit('sdp_answer', {
        'callId': _currentCallId,
        'sdp': answer.toMap(),
        'callerId': _remoteUserId, // ВАЖНО: Указываем, кому адресован ответ
      });
      debugPrint('✅ SDP Answer отправлен на сервер');

      _setCallState(CallState.connected);
      return true;
    } catch (e) {
      debugPrint('🚨 Ошибка при принятии звонка: $e');
      _setCallState(CallState.error);
      await _resetCall();
      return false;
    }
  }

  // Отклонение входящего звонка
  Future<void> rejectCall() async {
    debugPrint('🚫 Отклонение звонка ID: $_currentCallId');

    // Останавливаем рингтон при отклонении
    FlutterRingtonePlayer().stop();

    if (_currentCallId != null) {
      _callSocketClient.emit('reject_call', {
        'callId': _currentCallId,
        'remoteUserId': _remoteUserId, // Добавляем ID другого участника
      });
    }
    await _resetCall();
  }

  // Завершение звонка
  Future<void> endCall() async {
    
    // Отправляем событие завершения через сокет
    if (_currentCallId != null) {
      _callSocketClient.emit('end_call', {
        'callId': _currentCallId,
        'remoteUserId': _remoteUserId, // Добавляем ID другого участника
      });
    }

    await _resetCall();
  }

  // Переключение камеры (для видео звонков)
  Future<void> switchCamera() async {
    if (_callType == CallType.video && _localStream != null) {
      try {
        final videoTrack = _localStream!.getVideoTracks().first;
        await Helper.switchCamera(videoTrack);
      } catch (e) {
        // Игнорируем
      }
    }
  }

  /// Включает или выключает микрофон.
  ///
  /// [mute] - `true` чтобы выключить микрофон, `false` чтобы включить.
  void setMicrophoneMute(bool mute) {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !mute;
        // Уведомляем слушателей, если нужно обновить UI, 
        // хотя в данном случае UI обновляется на самом экране.
        // notifyListeners(); 
    }
  }

  /// Переключает вывод звука на динамик громкой связи.
  ///
  /// [enabled] - `true` чтобы включить громкую связь, `false` чтобы выключить.
  Future<void> setSpeakerphoneOn(bool enabled) async {
    // Helper.setSpeakerphoneOn() работает только на мобильных устройствах
    if (!kIsWeb) {
      try {
        await Helper.setSpeakerphoneOn(enabled);
      } catch (e) {
        // Игнорируем ошибку, если платформа не поддерживает эту функцию
      }
    }
  }

  // Включение/выключение камеры
  void toggleCamera() {
    if (_callType == CallType.video && _localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      videoTrack.enabled = !videoTrack.enabled;
        notifyListeners();
    }
  }

  // Запрос разрешений
  Future<bool> _requestPermissions(CallType callType) async {
    try {
      // Микрофон всегда нужен
      var micPermission = await Permission.microphone.request();
      if (micPermission != PermissionStatus.granted) {
        return false;
      }

      // Камера нужна только для видео
      if (callType == CallType.video) {
        var cameraPermission = await Permission.camera.request();
        if (cameraPermission != PermissionStatus.granted) {
          return false;
        }
      }

      return true;
      
    } catch (e) {
      return false;
    }
  }

  // Создание локального медиа потока
  Future<void> _createLocalStream() async {
    try {
      
      // Создаём поток с микрофона используя Flutter WebRTC API
      final constraints = {
        'audio': true,
        'video': _callType == CallType.video,
      };
      
      // Используем getUserMedia для получения реального аудио потока
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      
      
    } catch (e) {
      rethrow;
    }
  }

  // Создание peer connection
  Future<void> _createPeerConnection() async {
    try {
      
      _peerConnection = await createPeerConnection(_rtcConfiguration);
      
      // Настройка обработчиков событий
      _peerConnection!.onIceCandidate = (candidate) {
        if (candidate != null) {
          
          // ИСПРАВЛЕНИЕ: Буферизируем кандидаты, если callId еще не получен
          if (_currentCallId == null) {
            _outgoingIceCandidatesBuffer.add(candidate);
          } else {
            _sendIceCandidate(candidate);
          }
        }
      };

      _peerConnection!.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          // Соединение установлено
        }
      };

      _peerConnection!.onIceConnectionState = (state) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          // ICE соединение установлено
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          // Ошибка ICE
        }
      };

      _peerConnection!.onIceGatheringState = (state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          // После завершения сбора кандидатов, добавляем ожидающие
          for (final candidate in _pendingIceCandidates) {
            _peerConnection!.addCandidate(candidate);
          }
          _pendingIceCandidates.clear();
        }
      };

      _peerConnection!.onTrack = (event) {
        debugPrint('✅ [WebRTC] Получен remote track от пользователя: ${event.receiver?.track?.id}');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          notifyListeners();
        }
      };

      
    } catch (e) {
      rethrow;
    }
  }

  // Обработка входящего звонка
  void _handleIncomingCall(dynamic data) async {
    debugPrint('📞 [WS] Получен входящий звонок: $data');
    try {
      final callId = data['callId'];
      final remoteUserId = data['remoteUserId'];
      final callType = data['callType'];
      final remoteUsername = data['callerName'] ?? 'Unknown';
      
      
      // ИСПРАВЛЕНИЕ: Проверяем, что мы не в активном звонке
      if (_callState != CallState.idle) {
        debugPrint('⚠️ [WS] Звонок проигнорирован, состояние не idle: $_callState');
        return;
      }
      
      // Запускаем рингтон
      FlutterRingtonePlayer().playRingtone();

      // ИСПРАВЛЕНИЕ: Устанавливаем callId и remoteUserId для входящего звонка
      if (callId != null) {
        _currentCallId = callId;
      }
      
      if (remoteUserId != null) {
        _remoteUserId = remoteUserId;
      }
      
      // Устанавливаем тип звонка
      _callType = callType == 'video' ? CallType.video : CallType.voice;
      
      // Устанавливаем имя удаленного пользователя
      _remoteUsername = remoteUsername;
      
      // Переходим в статус incoming
      _setCallState(CallState.incoming);

      // Создаем peer connection для входящего звонка
      await _createPeerConnection();

      // После создания PC, проверяем наличие буферизованного оффера
      if (_bufferedSdpOffer != null &&
          _bufferedSdpOffer!['callId'] == _currentCallId) {
        debugPrint('⚡️ Обработка буферизованного SDP offer...');
        await _processSdpOffer(_bufferedSdpOffer!);
        _bufferedSdpOffer = null; // Очищаем буфер после обработки
      }

      final context = navigatorKey.currentContext;
      if (context != null) {
        final currentUserId = await _authService.getUserId();
        if (currentUserId == null) {
          debugPrint(
              '❌ [UI] Не удалось получить currentUserId, навигация отменена.');
          return;
        }

        // СОЗДАЕМ ЭКЗЕМПЛЯР CallModel ИЗ СЫРЫХ ДАННЫХ
        final callModel = CallModel(
          id: data['callId'],
          callerId: data['remoteUserId'],
          callerUsername: data['callerName'],
          receiverId: currentUserId, // Мы - получатель
          receiverUsername: '', // Имя получателя нам пока не нужно на этом экране
          status: CallStatus.ringing,
          type: data['callType'] == 'video' ? CallType.video : CallType.voice,
          createdAt: DateTime.now(),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
              callId: callModel.id, // ПЕРЕДАЕМ ПРАВИЛЬНЫЙ ОБЪЕКТ
              remoteUserId: callModel.callerId,
              callType: callModel.type,
              remoteUsername: callModel.callerUsername ?? 'Unknown',
            ),
          ),
        );
      } else {
        debugPrint('❌ [UI] navigatorKey.currentContext is null, навигация невозможна.');
      }
    } catch (e) {
      debugPrint('🚨 [WS] Ошибка в _handleIncomingCall: $e');
      // В случае ошибки сбрасываем состояние
      _resetCall();
    }
  }

  // Обработка принятия звонка
  void _handleCallAccepted(dynamic data) async {
    try {
      final callId = data['callId'];

      if (_currentCallId == callId) {
        _setCallState(CallState.connected);
        _startCallTimer();
      }
    } catch (e) {
      debugPrint('🚨 Ошибка в _handleCallAccepted: $e');
    }
  }

  // Обработка отклонения звонка
  void _handleCallRejected(dynamic data) async {
    try {
      final callId = data['callId'];
      if (_currentCallId == callId) {
        debugPrint('🚫 Звонок был отклонен удаленно.');
        await _resetCall();
      }
    } catch (e) {
      debugPrint('🚨 Ошибка в _handleCallRejected: $e');
    }
  }

  // Обработка завершения звонка
  void _handleCallEnded(dynamic data) async {
    try {
      final callId = data['callId'];
      
      bool shouldEndCall = false;
      
      if (_currentCallId != null && _currentCallId == callId) {
        shouldEndCall = true;
      } else if (_callState == CallState.incoming || _callState == CallState.connected) {
        shouldEndCall = true;
      }
      
      if (shouldEndCall) {
        // Останавливаем рингтон, если звонок был завершен удаленно
        FlutterRingtonePlayer().stop();
        debugPrint('🔚 Звонок был завершен удаленно.');
        await _resetCall();
      }
    } catch (e) {
      debugPrint('🚨 Ошибка в _handleCallEnded: $e');
      await _resetCall();
    }
  }

  // Обработка SDP offer
  void _handleSdpOffer(dynamic data) async {
    final callId = data['callId']?.toString();

    if (_peerConnection == null) {
      debugPrint('🚦 PeerConnection is NULL. Buffering SDP offer for call $callId.');
      _bufferedSdpOffer = data;
      return;
    }

    await _processSdpOffer(data);
  }

  // НОВЫЙ приватный метод для фактической обработки SDP
  Future<void> _processSdpOffer(dynamic data) async {
    try {
      final sdpData = data['sdp'];
      if (sdpData == null) {
        debugPrint('🚨 SDP data is null in offer!');
        return;
      }

      final sdpString = sdpData['sdp']?.toString();
      final sdpType = sdpData['type']?.toString();

      if (sdpString == null || sdpType == null) {
        debugPrint('🚨 SDP string or type is null in offer!');
        return;
      }

      final sdp = RTCSessionDescription(
        sdpString,
        sdpType,
      );

      if (_peerConnection != null) {
        await _peerConnection!.setRemoteDescription(sdp);
        debugPrint('✅ Remote Description (Offer) set successfully.');

        // Добавляем ожидающие ICE кандидаты после установки remote description
        if (_pendingIceCandidates.isNotEmpty) {
          for (final candidate in _pendingIceCandidates) {
            try {
              await _peerConnection!.addCandidate(candidate);
            } catch (e) {
              debugPrint('⚠️ Ошибка при добавлении ожидающего кандидата: $e');
            }
          }
          _pendingIceCandidates.clear();
        }
      }
    } catch (e) {
      debugPrint('🚨 Ошибка при обработке SDP Offer: $e');
    }
  }

  // Обработка SDP answer
  void _handleSdpAnswer(dynamic data) async {
    try {
      final sdpData = data['sdp'];
      final sdp = RTCSessionDescription(
        sdpData['sdp'],
        sdpData['type'],
      );

      if (_peerConnection != null) {
        await _peerConnection!.setRemoteDescription(sdp);
        debugPrint('✅ Remote Description (Answer) установлен успешно.');
        
        // Добавляем ожидающие ICE кандидаты после установки remote description
        if (_pendingIceCandidates.isNotEmpty) {
          for (final candidate in _pendingIceCandidates) {
            try {
              await _peerConnection!.addCandidate(candidate);
            } catch (e) {
              // Игнорируем
            }
          }
          _pendingIceCandidates.clear();
        }
      }
      
    } catch (e) {
      // Игнорируем
    }
  }

  // Обработка ICE кандидата
  void _handleIceCandidate(dynamic data) async {
    if (data['candidate'] == null || _peerConnection == null) {
      return;
    }

    try {
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );

      // Проверяем, установлен ли remote description
      if (_peerConnection?.getRemoteDescription() != null) {
        await _peerConnection!.addCandidate(candidate);
      } else {
        // Добавляем в очередь для последующего добавления
        _pendingIceCandidates.add(candidate);
      }
    } catch (e) {
      debugPrint('🚨 Ошибка при добавлении ICE кандидата: $e');
    }
  }

  // Обработка события call_initiated
  void _handleCallInitiated(dynamic data) async {
    try {
      final callId = data['callId'];

      if (callId != null) {
        _currentCallId = callId;

        // Отправляем всех кандидатов из буфера
        if (_outgoingIceCandidatesBuffer.isNotEmpty) {
          debugPrint('✈️ Отправка ${_outgoingIceCandidatesBuffer.length} буферизованных ICE кандидатов...');
          for (final candidate in _outgoingIceCandidatesBuffer) {
            _sendIceCandidate(candidate);
          }
          _outgoingIceCandidatesBuffer.clear();
        }
      }
    } catch (e) {
      // Игнорируем
    }
  }

  // Отправка ICE кандидата на сервер
  void _sendIceCandidate(RTCIceCandidate candidate) {
    if (_currentCallId != null) {
      _callSocketClient.emit('ice_candidate', {
        'callId': _currentCallId,
        'candidate': candidate.toMap(),
        'targetId': _remoteUserId, // И ЭТО ТОЖЕ ЗАБЫЛИ!
      });
    }
  }

  // Запуск таймера звонка
  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Логика таймера звонка
    });
  }

  // Остановка таймера звонка
  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  // Сброс состояния звонка
  Future<void> _resetCall() async {
    // ИСПРАВЛЕНИЕ: Проверяем, не выполняется ли уже сброс
    if (_isResetting) {
      return;
    }
    _isResetting = true;
    
    try {
      
      // ИСПРАВЛЕНИЕ: Сначала обнуляем ID, чтобы предотвратить гонку состояний
      _currentCallId = null;
      _remoteUserId = null;
      _remoteUsername = null;
      _pendingIceCandidates.clear();
      _outgoingIceCandidatesBuffer.clear();
      _bufferedSdpOffer = null; // Очищаем буфер SDP
      
      // Устанавливаем состояние 'ended', чтобы UI мог среагировать до полного сброса
      _setCallState(CallState.ended);
      
      // Останавливаем таймеры
      _stopCallTimer();
      _iceGatheringTimer?.cancel();
      
      

      // Принудительно закрываем peer connection
      if (_peerConnection != null) {
        try {
          await _peerConnection!.close();
        } catch (e) {
          // Игнорируем
        }
        _peerConnection = null;
      }
      
      // Останавливаем и освобождаем локальный стрим
      if (_localStream != null) {
        try {
          // Останавливаем все треки
          for (var track in _localStream!.getTracks()) {
            await track.stop();
          }
          await _localStream!.dispose();
        } catch (e) {
          // Игнорируем
        }
        _localStream = null;
      }
      
      // Сбрасываем удаленный стрим
      _remoteStream = null;
      
      // Устанавливаем состояние 'idle' после полного сброса
      _setCallState(CallState.idle);
      
      

    } catch (e) {
      _setCallState(CallState.error);
    } finally {
      // Сбрасываем флаг в любом случае
      _isResetting = false;
    }
  }

  // Установка состояния звонка
  void _setCallState(CallState state) {
    // ИСПРАВЛЕНИЕ: Уведомляем только если состояние изменилось
    if (_callState != state) {
      _callState = state;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _callSocketClient.removeListener(_onSocketConnectionChange);
    _resetCall();
    super.dispose();
  }
}
