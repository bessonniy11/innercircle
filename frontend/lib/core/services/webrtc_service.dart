import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../socket/call_socket_client.dart';

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
  
  // Callback для UI
  Function(Map<String, dynamic>)? _onIncomingCall;
  
  // Конфигурация WebRTC
  final Map<String, dynamic> _rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
    'iceCandidatePoolSize': 10,
  };

  WebRTCService(this._callSocketClient) {
    _setupSocketListeners();
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

  // Настройка слушателей сокетов
  void _setupSocketListeners() {
    _callSocketClient.on('incoming_call', _handleIncomingCall);
    _callSocketClient.on('call_accepted', _handleCallAccepted);
    _callSocketClient.on('call_rejected', _handleCallRejected);
    _callSocketClient.on('call_ended', _handleCallEnded);
    _callSocketClient.on('ice_candidate', _handleIceCandidate);
    _callSocketClient.on('sdp_offer', _handleSdpOffer);
    _callSocketClient.on('sdp_answer', _handleSdpAnswer);
  }

  // Инициация звонка
  Future<bool> initiateCall(String remoteUserId, CallType callType, {String? callerUsername}) async {
    try {
      debugPrint('🔔 WebRTC: Инициация звонка к $remoteUserId (${callType.name})');
      
      if (_callState != CallState.idle) {
        debugPrint('🔥 WebRTC: Ошибка - уже в звонке');
        return false;
      }

      // Запрос разрешений
      if (!await _requestPermissions(callType)) {
        debugPrint('🔥 WebRTC: Ошибка - не получены разрешения');
        return false;
      }

      _callType = callType;
      _remoteUserId = remoteUserId;
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
      
      debugPrint('🔔 WebRTC: Звонок инициирован успешно (статус: calling)');
      return true;
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка инициации звонка: $e');
      _setCallState(CallState.error);
      return false;
    }
  }

  // Принятие входящего звонка
  Future<bool> acceptCall(String callId, CallType callType) async {
    try {
      debugPrint('🔔 WebRTC: Принятие входящего звонка $callId');
      debugPrint('🔔 WebRTC: Текущий статус: ${_callState.name}');
      debugPrint('🔔 WebRTC: Текущий callId: $_currentCallId');
      debugPrint('🔔 WebRTC: Удаленный пользователь: $_remoteUserId');
      
      if (_callState != CallState.incoming) {
        debugPrint('🔥 WebRTC: Ошибка - не входящий звонок. Статус: ${_callState.name}');
        return false;
      }

      // Запрос разрешений
      if (!await _requestPermissions(callType)) {
        debugPrint('🔥 WebRTC: Ошибка - не получены разрешения');
        return false;
      }

      _callType = callType;
      _currentCallId = callId;
      _setCallState(CallState.connected);

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

      // Отправка подтверждения через сокет
      _callSocketClient.emit('accept_call', {
        'callId': callId,
      });

      debugPrint('🔔 WebRTC: Входящий звонок принят');
      return true;
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка принятия звонка: $e');
      _setCallState(CallState.error);
      return false;
    }
  }

  // Отклонение входящего звонка
  void rejectCall(String callId) {
    debugPrint('🔔 WebRTC: Отклонение входящего звонка $callId');
    
    _callSocketClient.emit('reject_call', {
      'callId': callId,
    });
    
    _resetCall();
  }

  // Завершение звонка
  void endCall() {
    debugPrint('🔔 WebRTC: Завершение звонка');
    
    if (_currentCallId != null) {
      _callSocketClient.emit('end_call', {
        'callId': _currentCallId,
      });
    }
    
    _resetCall();
  }

  // Переключение камеры (для видео звонков)
  Future<void> switchCamera() async {
    if (_callType == CallType.video && _localStream != null) {
      try {
        final videoTrack = _localStream!.getVideoTracks().first;
        if (videoTrack != null) {
          await Helper.switchCamera(videoTrack);
          debugPrint('🔔 WebRTC: Камера переключена');
        }
      } catch (e) {
        debugPrint('🔥 WebRTC: Ошибка переключения камеры: $e');
      }
    }
  }

  // Включение/выключение микрофона
  void toggleMicrophone() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      if (audioTrack != null) {
        audioTrack.enabled = !audioTrack.enabled;
        debugPrint('🔔 WebRTC: Микрофон ${audioTrack.enabled ? "включен" : "выключен"}');
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
        debugPrint('🔔 WebRTC: Камера ${videoTrack.enabled ? "включена" : "выключена"}');
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
        debugPrint('🔥 WebRTC: Нет разрешения на микрофон');
        return false;
      }

      // Камера нужна только для видео
      if (callType == CallType.video) {
        var cameraPermission = await Permission.camera.request();
        if (cameraPermission != PermissionStatus.granted) {
          debugPrint('🔥 WebRTC: Нет разрешения на камеру');
          return false;
        }
      }

      debugPrint('🔔 WebRTC: Все разрешения получены');
      return true;
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка запроса разрешений: $e');
      return false;
    }
  }

  // Создание локального медиа потока
  Future<void> _createLocalStream() async {
    try {
      _localStream = await createLocalMediaStream('local_stream');
      debugPrint('🔔 WebRTC: Локальный медиа поток создан');
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка создания локального потока: $e');
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
          debugPrint('🔔 WebRTC: ICE кандидат: ${candidate.candidate}');
          _callSocketClient.emit('ice_candidate', {
            'callId': _currentCallId,
            'candidate': candidate.toMap(),
          });
        }
      };

      _peerConnection!.onConnectionState = (state) {
        debugPrint('🔔 WebRTC: Состояние соединения: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          debugPrint('🔔 WebRTC: WebRTC соединение установлено');
        }
      };

      _peerConnection!.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          debugPrint('🔔 WebRTC: Удаленный поток получен');
          notifyListeners();
        }
      };

      debugPrint('🔔 WebRTC: Peer connection создан');
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка создания peer connection: $e');
      rethrow;
    }
  }

  // Обработка входящего звонка
  void _handleIncomingCall(dynamic data) async {
    try {
      final callId = data['callId'];
      final remoteUserId = data['remoteUserId'];
      final callType = CallType.values.firstWhere(
        (e) => e.name == data['callType'],
        orElse: () => CallType.audio,
      );
      final remoteUsername = data['callerUsername'] ?? 'Unknown User'; // Получаем имя звонящего

      debugPrint('🔔 WebRTC: Входящий звонок от $remoteUserId (${callType.name})');
      debugPrint('🔔 WebRTC: Текущий статус: ${_callState.name}');
      
      _currentCallId = callId;
      _remoteUserId = remoteUserId;
      _callType = callType;
      _remoteUsername = remoteUsername; // Сохраняем имя
      _setCallState(CallState.incoming);
      
      debugPrint('🔔 WebRTC: Статус изменен на: ${_callState.name}');
      
      // Уведомляем UI о необходимости показать экран входящего звонка
      if (_onIncomingCall != null) {
        debugPrint('🔔 WebRTC: Уведомляем UI о входящем звонке');
        _onIncomingCall!({
          'callId': callId,
          'remoteUserId': remoteUserId,
          'callType': callType.name,
          'remoteUsername': remoteUsername,
        });
      } else {
        debugPrint('⚠️ WebRTC: Callback для UI не установлен');
      }
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка обработки входящего звонка: $e');
    }
  }

  // Обработка принятия звонка
  void _handleCallAccepted(dynamic data) async {
    try {
      final callId = data['callId'];
      
      debugPrint('🔔 WebRTC: Получено принятие звонка: $callId');
      debugPrint('🔔 WebRTC: Текущий статус: ${_callState.name}');
      debugPrint('🔔 WebRTC: Текущий callId: $_currentCallId');
      
      // Проверяем, что это наш звонок (либо как звонящий, либо как принимающий)
      if (_currentCallId == callId || _remoteUserId != null) {
        debugPrint('🔔 WebRTC: Звонок принят удаленным пользователем');
        _setCallState(CallState.connected);
        // Запускаем таймер только когда звонок принят!
        _startCallTimer();
        
        // TODO: Показать ActiveCallScreen для обоих пользователей
        // Это нужно будет реализовать через Callback или Stream
        debugPrint('🔔 WebRTC: Звонок подключен - нужно показать ActiveCallScreen');
      } else {
        debugPrint('⚠️ WebRTC: Принятие звонка не относится к текущему звонку');
      }
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка обработки принятия звонка: $e');
    }
  }

  // Обработка отклонения звонка
  void _handleCallRejected(dynamic data) async {
    try {
      final callId = data['callId'];
      
      debugPrint('🔔 WebRTC: Получено отклонение звонка: $callId');
      debugPrint('🔔 WebRTC: Текущий статус: ${_callState.name}');
      debugPrint('🔔 WebRTC: Текущий callId: $_currentCallId');
      
      // Проверяем, что это наш звонок (либо как звонящий, либо как принимающий)
      if (_currentCallId == callId || _remoteUserId != null) {
        debugPrint('🔔 WebRTC: Звонок отклонен удаленным пользователем');
        _resetCall();
      } else {
        debugPrint('⚠️ WebRTC: Отклонение звонка не относится к текущему звонку');
      }
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка обработки отклонения звонка: $e');
    }
  }

  // Обработка завершения звонка
  void _handleCallEnded(dynamic data) async {
    try {
      final callId = data['callId'];
      
      debugPrint('🔔 WebRTC: Получено завершение звонка: $callId');
      debugPrint('🔔 WebRTC: Текущий статус: ${_callState.name}');
      debugPrint('🔔 WebRTC: Текущий callId: $_currentCallId');
      
      // Проверяем, что это наш звонок (либо как звонящий, либо как принимающий)
      if (_currentCallId == callId || _remoteUserId != null) {
        debugPrint('🔔 WebRTC: Звонок завершен удаленным пользователем');
        _resetCall();
      } else {
        debugPrint('⚠️ WebRTC: Завершение звонка не относится к текущему звонку');
      }
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка обработки завершения звонка: $e');
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
        
        final answer = await _peerConnection!.createAnswer();
        await _peerConnection!.setLocalDescription(answer);
        
        _callSocketClient.emit('sdp_answer', {
          'callId': _currentCallId,
          'sdp': answer.sdp,
          'type': answer.type,
        });
        
        debugPrint('🔔 WebRTC: SDP answer отправлен');
      }
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка обработки SDP offer: $e');
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
        debugPrint('🔔 WebRTC: SDP answer получен и установлен');
      }
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка обработки SDP answer: $e');
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
        await _peerConnection!.addCandidate(candidate);
        debugPrint('🔔 WebRTC: ICE кандидат добавлен');
      }
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка обработки ICE кандидата: $e');
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
  void _resetCall() {
    _stopCallTimer();
    _iceGatheringTimer?.cancel();
    
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.dispose();
    
    _localStream = null;
    _remoteStream = null;
    _peerConnection = null;
    _currentCallId = null;
    _remoteUserId = null;
    _remoteUsername = null; // Сбрасываем имя удаленного пользователя
    
    _setCallState(CallState.idle);
  }

  // Установка состояния звонка
  void _setCallState(CallState state) {
    _callState = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _resetCall();
    super.dispose();
  }
}
