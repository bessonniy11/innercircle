import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../socket/call_socket_client.dart';
import '../api/api_client.dart';

enum CallState {
  idle,
  calling,
  incoming,
  connected,
  ended,
  error,
}

enum CallType {
  audio,
  video,
}

class WebRTCService extends ChangeNotifier {
  final CallSocketClient _callSocketClient;
  final ApiClient _apiClient;
  
  // WebRTC объекты
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  
  // Состояние звонка
  CallState _callState = CallState.idle;
  CallType _callType = CallType.audio;
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

  // Флаг для предотвращения многократного сброса состояния
  bool _isResetting = false;
  
  // Callback для UI
  Function(Map<String, dynamic>)? _onIncomingCall;
  
  // Конфигурация WebRTC (по умолчанию)
  Map<String, dynamic> _rtcConfiguration = {
    'iceServers': [
      // Default STUN servers - быстрый способ найти прямой путь
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},

      // Public TURN servers for NAT traversal
      // Добавляем несколько серверов для надежности.
      // Используем порты 80, 443, 3478, чтобы повысить шансы на обход файрволов.
      {
        'urls': [
          'turn:openrelay.metered.ca:80',
          'turn:openrelay.metered.ca:443'
        ],
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': [
          "turn:stun.nextcloud.com:443",
          "turn:turn.nextcloud.com:443"
        ],
        'username': "",
        'credential': ""
      },
      {
        'urls': "turn:global.turn.twilio.com:3478?transport=udp",
        'username': "YOUR_TWILIO_ACCOUNT_SID", // Placeholder
        'credential': "YOUR_TWILIO_AUTH_TOKEN" // Placeholder
      }
    ],
    'iceCandidatePoolSize': 10,
  };

  WebRTCService(this._callSocketClient, this._apiClient) {
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
  
  // Установка callback для UI
  void setIncomingCallCallback(Function(Map<String, dynamic>) callback) {
    _onIncomingCall = callback;
  }

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
    _callSocketClient.on('incoming_call', _handleIncomingCall);
    _callSocketClient.on('call_accepted', _handleCallAccepted);
    _callSocketClient.on('call_rejected', _handleCallRejected);
    _callSocketClient.on('call_ended', _handleCallEnded);
    _callSocketClient.on('ice_candidate', _handleIceCandidate);
    _callSocketClient.on('sdp_offer', _handleSdpOffer);
    _callSocketClient.on('sdp_answer', _handleSdpAnswer);
    _callSocketClient.on('call_initiated', _handleCallInitiated);
  }

  void _removeSocketListeners() {
    // Здесь мы должны были бы отписаться, но текущая реализация 
    // _callSocketClient.on() не предоставляет метода для отписки.
    // При пересоздании сокета в CallSocketClient старые слушатели удаляются,
    // так что текущая архитектура это прощает. Оставляем для будущих улучшений.
  }

  // Инициация звонка
  Future<bool> initiateCall(String remoteUserId, CallType callType, {String? callerUsername}) async {
    try {
      
      if (_callState != CallState.idle) {
        return false;
      }

      // Запрос разрешений
      if (!await _requestPermissions(callType)) {
        return false;
      }

      _callType = callType;
      _remoteUserId = remoteUserId;
      
      // callId будет получен от сервера в событии call_initiated
      _currentCallId = null;
      
      _setCallState(CallState.calling);

      // Создание локального медиа потока
      await _createLocalStream();
      
      // Создание peer connection
      await _createPeerConnection();
      
      // Добавление локального потока
      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          _peerConnection!.addTrack(track, _localStream!);
        }
      }

      // Создание и отправка SDP offer
      final offer = await _peerConnection!.createOffer();
      
      await _peerConnection!.setLocalDescription(offer);
      
      // Отправка запроса на звонок через сокет
      _callSocketClient.emit('initiate_call', {
        'remoteUserId': remoteUserId,
        'callType': callType.name,
        'sdp': offer.sdp,
        'type': offer.type,
        'callerUsername': callerUsername, // Добавляем имя звонящего
      });

      // НЕ запускаем таймер сразу - только когда звонок принят!
      // _startCallTimer(); // УБИРАЕМ ЭТУ СТРОКУ!
      
      return true;
      
    } catch (e) {
      _setCallState(CallState.error);
      return false;
    }
  }

  // Принятие входящего звонка
  Future<bool> acceptCall(String callId, CallType callType) async {
    try {
      
      if (_callState != CallState.incoming) {
        return false;
      }

      // Запрос разрешений
      if (!await _requestPermissions(callType)) {
        return false;
      }

      _setCallState(CallState.connected);

      // Создание локального медиа потока
      await _createLocalStream();
      
      // Peer connection уже создан в _handleIncomingCall, добавляем локальный поток
      
      // Добавление локального потока
      if (_localStream != null && _peerConnection != null) {
        for (final track in _localStream!.getTracks()) {
          _peerConnection!.addTrack(track, _localStream!);
        }
      } else {
        return false;
      }

      // Создание и отправка SDP answer
      final answer = await _peerConnection!.createAnswer();
      
      await _peerConnection!.setLocalDescription(answer);
      
      // Отправка SDP answer через сокет
      _callSocketClient.emit('sdp_answer', {
        'callId': callId,
        'sdp': answer.sdp,
        'type': answer.type,
      });
      
      // Отправка подтверждения через сокет
      _callSocketClient.emit('accept_call', {
        'callId': callId,
      });
      
      return true;
      
    } catch (e) {
      _setCallState(CallState.error);
      return false;
    }
  }

  // Отклонение входящего звонка
  Future<void> rejectCall(String callId) async {
    
    _callSocketClient.emit('reject_call', {
      'callId': callId,
    });
    
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
        if (videoTrack != null) {
          await Helper.switchCamera(videoTrack);
        }
      } catch (e) {
        // Игнорируем
      }
    }
  }

  // Включение/выключение микрофона
  void toggleMicrophone() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      if (audioTrack != null) {
        audioTrack.enabled = !audioTrack.enabled;
        notifyListeners();
      }
    }
  }

  // Включение/выключение камеры
  void toggleCamera() {
    if (_callType == CallType.video && _localStream != null) {
      final videoTrack = _localStream!.getVideoTracks().first;
      if (videoTrack != null) {
        videoTrack.enabled = !videoTrack.enabled;
        notifyListeners();
      }
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
    try {
      final callId = data['callId'];
      final remoteUserId = data['remoteUserId'];
      final callType = data['callType'];
      final remoteUsername = data['callerUsername'] ?? 'Unknown';
      
      
      // ИСПРАВЛЕНИЕ: Проверяем, что мы не в активном звонке
      if (_callState != CallState.idle) {
        return;
      }
      
      // ИСПРАВЛЕНИЕ: Устанавливаем callId и remoteUserId для входящего звонка
      if (callId != null) {
        _currentCallId = callId;
      }
      
      if (remoteUserId != null) {
        _remoteUserId = remoteUserId;
      }
      
      // Устанавливаем тип звонка
      _callType = callType == 'video' ? CallType.video : CallType.audio;
      
      // Устанавливаем имя удаленного пользователя
      _remoteUsername = remoteUsername;
      
      // Переходим в статус incoming
      _setCallState(CallState.incoming);
      
      // Создаем peer connection для входящего звонка
      await _createPeerConnection();
      
      // Устанавливаем SDP offer от звонящего
      if (data['sdp'] != null) {
        final offer = RTCSessionDescription(data['sdp'], data['type']);
        await _peerConnection!.setRemoteDescription(offer);
        
        // Уведомляем UI о входящем звонке
        if (_onIncomingCall != null) {
          _onIncomingCall!({
            'callId': callId,
            'remoteUserId': remoteUserId,
            'callType': callType,
            'remoteUsername': remoteUsername,
          });
        }
      }
      
    } catch (e) {
      // В случае ошибки сбрасываем состояние
      _resetCall();
    }
  }

  // Обработка принятия звонка
  void _handleCallAccepted(dynamic data) async {
    try {
      final callId = data['callId'];
      
      
      // ИСПРАВЛЕНИЕ: Обновляем _currentCallId на реальный callId от сервера
      if (callId != null && callId != _currentCallId) {
        _currentCallId = callId;
      }

      // Проверяем, что это наш звонок
      if (_currentCallId == callId || _remoteUserId != null) {

        // ИСПРАВЛЕНИЕ: Проверяем что мы действительно в правильном статусе
        if (_callState == CallState.calling) {
          _setCallState(CallState.connected);
          // Запускаем таймер только когда звонок принят!
          _startCallTimer();
        } else if (_callState == CallState.incoming) {
          // ИСПРАВЛЕНИЕ: У принимающего тоже переходим в connected
          _setCallState(CallState.connected);
          _startCallTimer();
        }
        
        // ИСПРАВЛЕНИЕ: Уведомляем UI о том, что звонок подключен
        notifyListeners();
      }
      
    } catch (e) {
      // Игнорируем
    }
  }

  // Обработка отклонения звонка
  void _handleCallRejected(dynamic data) async {
    try {
      final callId = data['callId'];
      
      
      // Обновляем _currentCallId на реальный callId от сервера
      if (callId != null && callId != _currentCallId) {
        _currentCallId = callId;
      }
      
      // Проверяем, что это наш звонок (либо как звонящий, либо как принимающий)
      if (_currentCallId == callId || _remoteUserId != null) {
        
        // Принудительно закрываем WebRTC соединение
        if (_peerConnection != null) {
          try {
            await _peerConnection!.close();
          } catch (e) {
            // Игнорируем
          }
        }
        
        // Останавливаем все медиа потоки
        if (_localStream != null) {
          try {
            _localStream!.getTracks().forEach((track) => track.stop());
          } catch (e) {
            // Игнорируем
          }
        }
        
        await _resetCall();
      }
      
    } catch (e) {
      // Игнорируем
    }
  }

  // Обработка завершения звонка
  void _handleCallEnded(dynamic data) async {
    try {
      final callId = data['callId'];
      
      
      // ИСПРАВЛЕНИЕ: Более строгая проверка - завершаем звонок только если:
      // 1. Это наш текущий callId, ИЛИ
      // 2. Мы в статусе incoming/connected (активный звонок)
      bool shouldEndCall = false;
      
      if (_currentCallId != null && _currentCallId == callId) {
        shouldEndCall = true;
      } else if (_callState == CallState.incoming || _callState == CallState.connected) {
        shouldEndCall = true;
      }
      
      if (shouldEndCall) {
        // Устанавливаем состояние ended, чтобы UI мог отреагировать немедленно
        _setCallState(CallState.ended);
        // Асинхронно сбрасываем состояние
        await _resetCall();
      }
      
    } catch (e) {
      // В случае ошибки все равно сбрасываем состояние
      await _resetCall();
    }
  }

  // Обработка SDP offer
  void _handleSdpOffer(dynamic data) async {
    try {
      final sdp = RTCSessionDescription(
        data['sdp'],
        data['type'],
      );

      if (_peerConnection != null) {
        await _peerConnection!.setRemoteDescription(sdp);
        
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
        
        final answer = await _peerConnection!.createAnswer();
        
        await _peerConnection!.setLocalDescription(answer);
        
        _callSocketClient.emit('sdp_answer', {
          'callId': _currentCallId,
          'sdp': answer.sdp,
          'type': answer.type,
        });
        
      }
      
    } catch (e) {
      // Игнорируем
    }
  }

  // Обработка SDP answer
  void _handleSdpAnswer(dynamic data) async {
    try {
      final sdp = RTCSessionDescription(
        data['sdp'],
        data['type'],
      );

      if (_peerConnection != null) {
        await _peerConnection!.setRemoteDescription(sdp);
        
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
    try {
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );

      if (_peerConnection != null) {
        // Проверяем, установлен ли remote description
        try {
          await _peerConnection!.addCandidate(candidate);
        } catch (e) {
          if (e.toString().contains('remote description was null')) {
            // Добавляем в очередь для последующего добавления
            _pendingIceCandidates.add(candidate);
          }
        }
      }
      
    } catch (e) {
      // Игнорируем
    }
  }

  // Обработка события call_initiated
  void _handleCallInitiated(dynamic data) async {
    try {
      final callId = data['callId'];

      // Обновляем _currentCallId на реальный callId от сервера
      if (callId != null) {
        _currentCallId = callId;

        // Отправляем всех кандидатов из буфера
        if (_outgoingIceCandidatesBuffer.isNotEmpty) {
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
      final oldCallId = _currentCallId;
      _currentCallId = null;
      _remoteUserId = null;
      _remoteUsername = null;
      _pendingIceCandidates.clear();
      _outgoingIceCandidatesBuffer.clear();
      
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
