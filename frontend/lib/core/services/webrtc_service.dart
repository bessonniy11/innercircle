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
  
  // Флаг для предотвращения многократного сброса состояния
  bool _isResetting = false;
  
  // Callback для UI
  Function(Map<String, dynamic>)? _onIncomingCall;
  
  // Конфигурация WebRTC (по умолчанию)
  Map<String, dynamic> _rtcConfiguration = {
    'iceServers': [
      {'urls': 'stun:5.8.76.33:3478'}, // НАШ STUN сервер (приоритетный)
      {'urls': 'stun:stun.l.google.com:19302'}, // Fallback Google STUN
      {'urls': 'stun:stun1.l.google.com:19302'}, // Fallback Google STUN
    ],
    'iceCandidatePoolSize': 10,
  };

  WebRTCService(this._callSocketClient, this._apiClient) {
    _setupSocketListeners();
    _loadWebRTCConfig();
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
      debugPrint('🔔 WebRTC: Загрузка конфигурации с сервера...');
      final response = await _apiClient.get('/calls/webrtc-config');
      
      if (response.statusCode == 200) {
        final config = response.data;
        if (config['iceServers'] != null) {
          _rtcConfiguration = config;
          debugPrint('🔔 WebRTC: Конфигурация загружена с сервера: ${config['iceServers']}');
        }
      }
    } catch (e) {
      debugPrint('⚠️ WebRTC: Не удалось загрузить конфигурацию с сервера, используем локальную: $e');
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
      
      // callId будет получен от сервера в событии call_initiated
      _currentCallId = null;
      debugPrint('🔔 WebRTC: Ожидаем callId от сервера...');
      
      _setCallState(CallState.calling);

      // Создание локального медиа потока
      await _createLocalStream();
      
      // Создание peer connection
      await _createPeerConnection();
      debugPrint('🔔 WebRTC: Peer connection создан, добавляем локальный поток...');
      
      // Добавление локального потока
      if (_localStream != null) {
        debugPrint('🔔 WebRTC: Добавляем ${_localStream!.getTracks().length} треков в peer connection');
        for (final track in _localStream!.getTracks()) {
          debugPrint('🔔 WebRTC: Добавляем трек: ${track.kind}');
          _peerConnection!.addTrack(track, _localStream!);
        }
        debugPrint('🔔 WebRTC: Все треки добавлены в peer connection');
      } else {
        debugPrint('⚠️ WebRTC: Локальный поток null!');
      }

      // Создание и отправка SDP offer
      debugPrint('🔔 WebRTC: Создание SDP offer...');
      final offer = await _peerConnection!.createOffer();
      debugPrint('🔔 WebRTC: SDP offer создан: ${offer.type}');
      
      debugPrint('🔔 WebRTC: Установка локального описания...');
      await _peerConnection!.setLocalDescription(offer);
      debugPrint('🔔 WebRTC: Локальное описание установлено');
      
      // Отправка запроса на звонок через сокет
      debugPrint('🔔 WebRTC: Отправка initiate_call через сокет...');
      _callSocketClient.emit('initiate_call', {
        'remoteUserId': remoteUserId,
        'callType': callType.name,
        'sdp': offer.sdp,
        'type': offer.type,
        'callerUsername': callerUsername, // Добавляем имя звонящего
      });
      debugPrint('🔔 WebRTC: initiate_call отправлен через сокет');

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

      _setCallState(CallState.connected);

      // Создание локального медиа потока
      await _createLocalStream();
      
      // Peer connection уже создан в _handleIncomingCall, добавляем локальный поток
      debugPrint('🔔 WebRTC: Peer connection уже создан, добавляем локальный поток...');
      
      // Добавление локального потока
      if (_localStream != null && _peerConnection != null) {
        debugPrint('🔔 WebRTC: Добавляем ${_localStream!.getTracks().length} треков в peer connection');
        for (final track in _localStream!.getTracks()) {
          debugPrint('🔔 WebRTC: Добавляем трек: ${track.kind}');
          _peerConnection!.addTrack(track, _localStream!);
        }
        debugPrint('🔔 WebRTC: Все треки добавлены в peer connection');
      } else {
        debugPrint('⚠️ WebRTC: Локальный поток или peer connection null!');
        return false;
      }

      // Создание и отправка SDP answer
      debugPrint('🔔 WebRTC: Создание SDP answer...');
      final answer = await _peerConnection!.createAnswer();
      debugPrint('🔔 WebRTC: SDP answer создан: ${answer.type}');
      
      debugPrint('🔔 WebRTC: Установка локального описания...');
      await _peerConnection!.setLocalDescription(answer);
      debugPrint('🔔 WebRTC: Локальное описание установлено');
      
      // Отправка SDP answer через сокет
      debugPrint('🔔 WebRTC: Отправка SDP answer через сокет...');
      _callSocketClient.emit('sdp_answer', {
        'callId': callId,
        'sdp': answer.sdp,
        'type': answer.type,
      });
      debugPrint('🔔 WebRTC: SDP answer отправлен через сокет');
      
      // Отправка подтверждения через сокет
      _callSocketClient.emit('accept_call', {
        'callId': callId,
      });
      debugPrint('🔔 WebRTC: accept_call отправлен через сокет');
      
      debugPrint('🔔 WebRTC: Входящий звонок принят');
      return true;
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка принятия звонка: $e');
      _setCallState(CallState.error);
      return false;
    }
  }

  // Отклонение входящего звонка
  Future<void> rejectCall(String callId) async {
    debugPrint('🔔 WebRTC: Отклонение входящего звонка $callId');
    
    _callSocketClient.emit('reject_call', {
      'callId': callId,
    });
    
    await _resetCall();
  }

  // Завершение звонка
  Future<void> endCall() async {
    debugPrint('🔔 WebRTC: Завершение звонка');
    
    // Отправляем событие завершения через сокет
    if (_currentCallId != null) {
      _callSocketClient.emit('end_call', {
        'callId': _currentCallId,
      });
    } else {
      debugPrint('⚠️ WebRTC: Попытка завершить звонок без callId');
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
      debugPrint('🔔 WebRTC: Создание локального потока...');
      
      // Создаём поток с микрофона используя Flutter WebRTC API
      final constraints = {
        'audio': true,
        'video': _callType == CallType.video,
      };
      
      debugPrint('🔔 WebRTC: Constraints для getUserMedia: $constraints');
      
      // Используем getUserMedia для получения реального аудио потока
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      
      debugPrint('🔔 WebRTC: Локальный медиа поток создан');
      
      // Добавляем логирование треков
      final tracks = _localStream!.getTracks();
      debugPrint('🔔 WebRTC: Количество треков в локальном потоке: ${tracks.length}');
      
      for (final track in tracks) {
        debugPrint('🔔 WebRTC: Трек: ${track.kind}, enabled: ${track.enabled}, muted: ${track.muted}');
      }
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка создания локального потока: $e');
      rethrow;
    }
  }

  // Создание peer connection
  Future<void> _createPeerConnection() async {
    try {
      debugPrint('🔔 WebRTC: Создание peer connection с конфигурацией: $_rtcConfiguration');
      
      _peerConnection = await createPeerConnection(_rtcConfiguration);
      debugPrint('🔔 WebRTC: Peer connection объект создан: $_peerConnection');
      
      // Настройка обработчиков событий
      _peerConnection!.onIceCandidate = (candidate) {
        debugPrint('🔔 WebRTC: onIceCandidate вызван!');
        if (candidate != null) {
          debugPrint('🔔 WebRTC: ICE кандидат: ${candidate.candidate}');
          debugPrint('🔔 WebRTC: ICE sdpMid: ${candidate.sdpMid}');
          debugPrint('🔔 WebRTC: ICE sdpMLineIndex: ${candidate.sdpMLineIndex}');
          
          _callSocketClient.emit('ice_candidate', {
            'callId': _currentCallId,
            'candidate': candidate.toMap(),
          });
        } else {
          debugPrint('⚠️ WebRTC: ICE кандидат null!');
        }
      };

      _peerConnection!.onConnectionState = (state) {
        debugPrint('🔔 WebRTC: Состояние соединения: $state');
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          debugPrint('🔔 WebRTC: WebRTC соединение установлено');
        }
      };

      _peerConnection!.onIceConnectionState = (state) {
        debugPrint('🔔 WebRTC: ICE состояние соединения: $state');
        if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
          debugPrint('🔔 WebRTC: ICE соединение установлено - аудио должно работать!');
        } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
          debugPrint('🔥 WebRTC: ICE соединение не удалось - проверьте STUN сервер!');
        }
      };

      _peerConnection!.onIceGatheringState = (state) {
        debugPrint('🔔 WebRTC: ICE состояние сбора кандидатов: $state');
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
          debugPrint('🔔 WebRTC: Сбор ICE кандидатов завершен');
          // После завершения сбора кандидатов, добавляем ожидающие
          for (final candidate in _pendingIceCandidates) {
            _peerConnection!.addCandidate(candidate);
            debugPrint('🔔 WebRTC: Добавлен ожидающий ICE кандидат');
          }
          _pendingIceCandidates.clear();
        }
      };

      _peerConnection!.onTrack = (event) {
        debugPrint('🔔 WebRTC: onTrack вызван!');
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          debugPrint('🔔 WebRTC: Удаленный поток получен');
          notifyListeners();
        }
      };

      debugPrint('🔔 WebRTC: Peer connection создан и настроен');
      
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
      final callType = data['callType'];
      final remoteUsername = data['callerUsername'] ?? 'Unknown';
      
      debugPrint('🔔 WebRTC: Входящий звонок от $remoteUserId ($callType)');
      debugPrint('🔔 WebRTC: Текущий статус: ${_callState.name}');
      debugPrint('🔔 WebRTC: Текущий callId: $_currentCallId');
      debugPrint('🔔 WebRTC: Текущий remoteUserId: $_remoteUserId');
      
      // ИСПРАВЛЕНИЕ: Проверяем, что мы не в активном звонке
      if (_callState != CallState.idle) {
        debugPrint('⚠️ WebRTC: Игнорируем входящий звонок - уже в звонке: ${_callState.name}');
        return;
      }
      
      // ИСПРАВЛЕНИЕ: Устанавливаем callId и remoteUserId для входящего звонка
      if (callId != null) {
        _currentCallId = callId;
        debugPrint('🔔 WebRTC: Установлен callId для входящего звонка: $callId');
      }
      
      if (remoteUserId != null) {
        _remoteUserId = remoteUserId;
        debugPrint('🔔 WebRTC: Установлен remoteUserId для входящего звонка: $remoteUserId');
      }
      
      // Устанавливаем тип звонка
      _callType = callType == 'video' ? CallType.video : CallType.audio;
      
      // Устанавливаем имя удаленного пользователя
      _remoteUsername = remoteUsername;
      
      // Переходим в статус incoming
      _setCallState(CallState.incoming);
      
      // Создаем peer connection для входящего звонка
      debugPrint('🔔 WebRTC: Создание peer connection для входящего звонка...');
      await _createPeerConnection();
      
      // Устанавливаем SDP offer от звонящего
      if (data['sdp'] != null) {
        debugPrint('🔔 WebRTC: Установка SDP offer от звонящего...');
        final offer = RTCSessionDescription(data['sdp'], data['type']);
        await _peerConnection!.setRemoteDescription(offer);
        debugPrint('🔔 WebRTC: SDP offer установлен');
        
        // Уведомляем UI о входящем звонке
        if (_onIncomingCall != null) {
          _onIncomingCall!({
            'callId': callId,
            'remoteUserId': remoteUserId,
            'callType': callType,
            'remoteUsername': remoteUsername,
          });
        }
        debugPrint('🔔 WebRTC: Уведомляем UI о входящем звонке');
      }
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка обработки входящего звонка: $e');
      // В случае ошибки сбрасываем состояние
      _resetCall();
    }
  }

  // Обработка принятия звонка
  void _handleCallAccepted(dynamic data) async {
    try {
      final callId = data['callId'];
      
      debugPrint('🔔 WebRTC: Получено принятие звонка: $callId');
      debugPrint('🔔 WebRTC: Текущий статус: ${_callState.name}');
      debugPrint('🔔 WebRTC: Текущий callId: $_currentCallId');
      debugPrint('🔔 WebRTC: Текущий remoteUserId: $_remoteUserId');
      
      // ИСПРАВЛЕНИЕ: Обновляем _currentCallId на реальный callId от сервера
      if (callId != null && callId != _currentCallId) {
        debugPrint('🔔 WebRTC: Обновляем callId с $_currentCallId на $callId');
        _currentCallId = callId;
      }

      // Проверяем, что это наш звонок
      if (_currentCallId == callId || _remoteUserId != null) {
        debugPrint('🔔 WebRTC: Звонок принят удаленным пользователем');

        // ИСПРАВЛЕНИЕ: Проверяем что мы действительно в правильном статусе
        if (_callState == CallState.calling) {
          debugPrint('🔔 WebRTC: Звонящий: переход в статус connected');
          _setCallState(CallState.connected);
          // Запускаем таймер только когда звонок принят!
          _startCallTimer();
        } else if (_callState == CallState.incoming) {
          debugPrint('🔔 WebRTC: Принимающий: уже в статусе connected');
          // ИСПРАВЛЕНИЕ: У принимающего тоже переходим в connected
          _setCallState(CallState.connected);
          _startCallTimer();
        } else {
          debugPrint('⚠️ WebRTC: Неожиданный статус при принятии звонка: ${_callState.name}');
        }
        
        // ИСПРАВЛЕНИЕ: Уведомляем UI о том, что звонок подключен
        debugPrint('🔔 WebRTC: Звонок подключен - нужно показать ActiveCallScreen');
        notifyListeners();
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
      
      // Обновляем _currentCallId на реальный callId от сервера
      if (callId != null && callId != _currentCallId) {
        debugPrint('🔔 WebRTC: Обновляем callId с $_currentCallId на $callId');
        _currentCallId = callId;
      }
      
      // Проверяем, что это наш звонок (либо как звонящий, либо как принимающий)
      if (_currentCallId == callId || _remoteUserId != null) {
        debugPrint('🔔 WebRTC: Звонок отклонен удаленным пользователем');
        
        // Принудительно закрываем WebRTC соединение
        if (_peerConnection != null) {
          try {
            await _peerConnection!.close();
            debugPrint('🔔 WebRTC: Peer connection закрыт при отклонении');
          } catch (e) {
            debugPrint('⚠️ WebRTC: Ошибка при закрытии peer connection: $e');
          }
        }
        
        // Останавливаем все медиа потоки
        if (_localStream != null) {
          try {
            _localStream!.getTracks().forEach((track) => track.stop());
            debugPrint('🔔 WebRTC: Локальные треки остановлены при отклонении');
          } catch (e) {
            debugPrint('⚠️ WebRTC: Ошибка при остановке локальных треков: $e');
          }
        }
        
        await _resetCall();
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
      debugPrint('🔥 WebRTC: Ошибка обработки завершения звонка: $e');
      // В случае ошибки все равно сбрасываем состояние
      await _resetCall();
    }
  }

  // Обработка SDP offer
  void _handleSdpOffer(dynamic data) async {
    try {
      debugPrint('🔔 WebRTC: Обработка SDP offer...');
      final sdp = RTCSessionDescription(
        data['sdp'],
        data['type'],
      );
      debugPrint('🔔 WebRTC: SDP offer получен: ${sdp.type}');

      if (_peerConnection != null) {
        debugPrint('🔔 WebRTC: Установка удаленного описания...');
        await _peerConnection!.setRemoteDescription(sdp);
        debugPrint('🔔 WebRTC: Удаленное описание установлено');
        
        // Добавляем ожидающие ICE кандидаты после установки remote description
        if (_pendingIceCandidates.isNotEmpty) {
          debugPrint('🔔 WebRTC: Добавляем ${_pendingIceCandidates.length} ожидающих ICE кандидатов...');
          for (final candidate in _pendingIceCandidates) {
            try {
              await _peerConnection!.addCandidate(candidate);
              debugPrint('🔔 WebRTC: Добавлен ожидающий ICE кандидат: ${candidate.candidate}');
            } catch (e) {
              debugPrint('⚠️ WebRTC: Ошибка при добавлении ожидающего ICE кандидата: $e');
            }
          }
          _pendingIceCandidates.clear();
          debugPrint('🔔 WebRTC: Все ожидающие ICE кандидаты добавлены');
        }
        
        debugPrint('🔔 WebRTC: Создание SDP answer...');
        final answer = await _peerConnection!.createAnswer();
        debugPrint('🔔 WebRTC: SDP answer создан: ${answer.type}');
        
        debugPrint('🔔 WebRTC: Установка локального описания...');
        await _peerConnection!.setLocalDescription(answer);
        debugPrint('🔔 WebRTC: Локальное описание установлено');
        
        debugPrint('🔔 WebRTC: Отправка SDP answer через сокет...');
        _callSocketClient.emit('sdp_answer', {
          'callId': _currentCallId,
          'sdp': answer.sdp,
          'type': answer.type,
        });
        
        debugPrint('🔔 WebRTC: SDP answer отправлен');
      } else {
        debugPrint('⚠️ WebRTC: Peer connection null при обработке SDP offer');
      }
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка обработки SDP offer: $e');
    }
  }

  // Обработка SDP answer
  void _handleSdpAnswer(dynamic data) async {
    try {
      debugPrint('🔔 WebRTC: Обработка SDP answer...');
      final sdp = RTCSessionDescription(
        data['sdp'],
        data['type'],
      );
      debugPrint('🔔 WebRTC: SDP answer получен: ${sdp.type}');

      if (_peerConnection != null) {
        debugPrint('🔔 WebRTC: Установка удаленного описания...');
        await _peerConnection!.setRemoteDescription(sdp);
        debugPrint('🔔 WebRTC: SDP answer получен и установлен');
        
        // Добавляем ожидающие ICE кандидаты после установки remote description
        if (_pendingIceCandidates.isNotEmpty) {
          debugPrint('🔔 WebRTC: Добавляем ${_pendingIceCandidates.length} ожидающих ICE кандидатов...');
          for (final candidate in _pendingIceCandidates) {
            try {
              await _peerConnection!.addCandidate(candidate);
              debugPrint('🔔 WebRTC: Добавлен ожидающий ICE кандидат: ${candidate.candidate}');
            } catch (e) {
              debugPrint('⚠️ WebRTC: Ошибка при добавлении ожидающего ICE кандидата: $e');
            }
          }
          _pendingIceCandidates.clear();
          debugPrint('🔔 WebRTC: Все ожидающие ICE кандидаты добавлены');
        }
      } else {
        debugPrint('⚠️ WebRTC: Peer connection null при обработке SDP answer');
      }
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка обработки SDP answer: $e');
    }
  }

  // Обработка ICE кандидата
  void _handleIceCandidate(dynamic data) async {
    try {
      debugPrint('🔔 WebRTC: Обработка ICE кандидата...');
      final candidate = RTCIceCandidate(
        data['candidate']['candidate'],
        data['candidate']['sdpMid'],
        data['candidate']['sdpMLineIndex'],
      );
      debugPrint('🔔 WebRTC: ICE кандидат получен: ${candidate.candidate}');

      if (_peerConnection != null) {
        // Проверяем, установлен ли remote description
        try {
          debugPrint('🔔 WebRTC: Добавление ICE кандидата в peer connection...');
          await _peerConnection!.addCandidate(candidate);
          debugPrint('🔔 WebRTC: ICE кандидат добавлен');
        } catch (e) {
          if (e.toString().contains('remote description was null')) {
            debugPrint('⏳ WebRTC: Remote description не установлен, добавляем ICE кандидат в очередь...');
            // Добавляем в очередь для последующего добавления
            _pendingIceCandidates.add(candidate);
          } else {
            debugPrint('🔥 WebRTC: Ошибка при добавлении ICE кандидата: $e');
          }
        }
      } else {
        debugPrint('⚠️ WebRTC: Peer connection null при обработке ICE кандидата');
      }
      
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка обработки ICE кандидата: $e');
    }
  }

  // Обработка события call_initiated
  void _handleCallInitiated(dynamic data) async {
    try {
      final callId = data['callId'];
      debugPrint('🔔 WebRTC: Получено событие call_initiated для callId: $callId');

      // Обновляем _currentCallId на реальный callId от сервера
      if (callId != null && callId != _currentCallId) {
        debugPrint('🔔 WebRTC: Обновляем callId с $_currentCallId на $callId');
        _currentCallId = callId;
      }
    } catch (e) {
      debugPrint('🔥 WebRTC: Ошибка обработки события call_initiated: $e');
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
      debugPrint('🔔 WebRTC: Сброс состояния звонка');
      
      // ИСПРАВЛЕНИЕ: Сначала обнуляем ID, чтобы предотвратить гонку состояний
      _currentCallId = null;
      _remoteUserId = null;
      _remoteUsername = null;
      _pendingIceCandidates.clear();
      
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
          debugPrint('⚠️ WebRTC: Ошибка при закрытии peer connection при сбросе: $e');
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
          debugPrint('⚠️ WebRTC: Ошибка при освобождении локального стрима: $e');
        }
        _localStream = null;
      }
      
      // Сбрасываем удаленный стрим
      _remoteStream = null;
      
      // Устанавливаем состояние 'idle' после полного сброса
      _setCallState(CallState.idle);
      
      debugPrint('🔔 WebRTC: Состояние звонка успешно сброшено');

    } catch (e) {
      debugPrint('🔥 WebRTC: Критическая ошибка при сбросе состояния: $e');
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
    _resetCall();
    super.dispose();
  }
}
