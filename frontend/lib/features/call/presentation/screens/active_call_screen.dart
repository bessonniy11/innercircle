import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:provider/provider.dart';
import '../../../../core/services/webrtc_service.dart' as webrtc;

// ИСПРАВЛЕНИЕ: Импортируем foundation для kIsWeb
import 'package:flutter/foundation.dart' show kIsWeb;

// ИСПРАВЛЕНИЕ: Импортируем наш новый менеджер с условным экспортом
import '../utils/web_audio_manager.dart';

/// Экран для отображения активного звонка
class ActiveCallScreen extends StatefulWidget {
  final String remoteUserId;
  final String remoteUsername;
  final webrtc.CallType callType;

  const ActiveCallScreen({
    super.key,
    required this.remoteUserId,
    required this.remoteUsername,
    required this.callType,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  late webrtc.WebRTCService _webrtcService;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  final RTCVideoRenderer _remoteVideoRenderer = RTCVideoRenderer();
  bool _isClosing = false; // ИСПРАВЛЕНИЕ: Флаг для предотвращения множественного закрытия экрана
  
  // ИСПРАВЛЕНИЕ: Используем наш WebAudioManager
  late final WebAudioManager _audioManager;

  @override
  void initState() {
    super.initState();
    _webrtcService = Provider.of<webrtc.WebRTCService>(context, listen: false);
    
    // ИСПРАВЛЕНИЕ: Инициализируем аудио-менеджер для веба СИНХРОННО
    if (kIsWeb) {
      _audioManager = WebAudioManager();
      _audioManager.createAudioElement();
    }

    // Вызываем асинхронную инициализацию видео-рендерера
    _initializeRenderer();
    
    // Слушаем изменения состояния звонка
    _webrtcService.addListener(_onCallStateChanged);
    
    // Проверяем текущее состояние для таймера
    if (_webrtcService.callState == webrtc.CallState.connected) {
      _startDurationTimer();
    }
  }

  @override
  void dispose() {
    // Останавливаем таймер длительности
    _durationTimer?.cancel();
    _durationTimer = null;
    
    // ИСПРАВЛЕНИЕ: Безопасно освобождаем ресурсы рендерера
    _remoteVideoRenderer.srcObject = null;
    _remoteVideoRenderer.dispose();
    
    // Убираем слушатель WebRTCService
    try {
      _webrtcService.removeListener(_onCallStateChanged);
    } catch (e) {
      // Игнорируем
    }
    
    // ИСПРАВЛЕНИЕ: Удаляем аудио-элемент через менеджер
    if (kIsWeb) {
      _audioManager.dispose();
    }
    
    super.dispose();
  }
  
  // ИСПРАВЛЕНИЕ: Выносим логику подключения потока в отдельный метод
  /// Подключение удаленного потока к RTCVideoRenderer
  void _attachRemoteStream() {
    if (_webrtcService.remoteStream != null && _remoteVideoRenderer.srcObject != _webrtcService.remoteStream) {
      final remoteStream = _webrtcService.remoteStream;
      _remoteVideoRenderer.srcObject = remoteStream;
      
      // ИСПРАВЛЕНИЕ: Подключаем поток через менеджер в вебе
      if (kIsWeb) {
        _audioManager.attachStream(remoteStream!);
      }

      if (mounted) {
        setState(() {}); // Обновляем UI
      }
    }
  }

  // ИСПРАВЛЕНИЕ: Новый асинхронный метод для инициализации
  Future<void> _initializeRenderer() async {
    await _remoteVideoRenderer.initialize();
    
    // ИСПРАВЛЕНИЕ: Немедленно проверяем и подключаем поток, если он уже доступен
    // Это нужно делать только после initialize()
    if (mounted) {
       _attachRemoteStream();
    }
  }

  /// Обработчик изменения состояния звонка
  void _onCallStateChanged() {
    if (mounted) {
      
      final newRemoteStream = _webrtcService.remoteStream;
      
      if (_webrtcService.callState == webrtc.CallState.connected) {
        // Звонок подключен - запускаем таймер
        if (_durationTimer == null) {
          _startDurationTimer();
        }
        
        // Настраиваем RTCVideoRenderer для удаленного потока
        _attachRemoteStream();

      } else if (_webrtcService.callState == webrtc.CallState.ended || 
                 _webrtcService.callState == webrtc.CallState.error ||
                 _webrtcService.callState == webrtc.CallState.idle) {
        if (!_isClosing) {
          _isClosing = true; // Устанавливаем флаг
          
          _durationTimer?.cancel();
          
          // Используем addPostFrameCallback, чтобы избежать "click-through".
          // Это гарантирует, что Navigator.pop() будет вызван после завершения текущего кадра
          // и обработки всех событий ввода.
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                try {
                  Navigator.of(context).pop();
                } catch (e) {
                  try {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  } catch (e2) {
                    // Игнорируем
                  }
                }
              }
            });
          }
        }
      }
    }
  }

  /// Запуск таймера длительности звонка
  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  /// Форматирование времени для отображения
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  /// Переключение микрофона
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    _webrtcService.toggleMicrophone();
  }

  /// Переключение динамика
  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    // TODO: Реализовать переключение динамика
  }

  /// Завершение звонка
  void _endCall() async {

    // Только инициируем завершение звонка. 
    // Экран будет закрыт автоматически в `_onCallStateChanged`, когда изменится состояние.
    // Это предотвращает "призрачные нажатия" на экран, который находится ниже.
    if (!_isClosing) {
      await _webrtcService.endCall();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      body: SafeArea(
        child: Column(
          children: [
            // Верхняя часть с информацией о звонке
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // RTCVideoView для удаленного потока (аудио)
                    if (_webrtcService.remoteStream != null)
                      Container(
                        width: 200,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          // ИСПРАВЛЕНИЕ: Возвращаем RTCVideoView
                          child: RTCVideoView(
                            _remoteVideoRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                        ),
                      )
                    else
                      // Аватар собеседника (если поток не готов)
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        child: Text(
                          widget.remoteUsername[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    // Имя собеседника
                    Text(
                      widget.remoteUsername,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Длительность звонка
                    Text(
                      _formatDuration(_callDuration),
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Нижняя часть с кнопками управления
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.all(32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Кнопка микрофона
                    _buildControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      color: _isMuted ? Colors.red : Colors.white,
                      onPressed: _toggleMute,
                      label: _isMuted ? 'Включить' : 'Выключить',
                    ),

                    // Кнопка завершения
                    _buildControlButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      onPressed: _endCall,
                      label: 'Завершить',
                    ),

                    // Кнопка динамика
                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      color: _isSpeakerOn ? Colors.blue : Colors.white,
                      onPressed: _toggleSpeaker,
                      label: _isSpeakerOn ? 'Динамик' : 'Трубка',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Построение кнопки управления
  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, size: 40),
            color: color == Colors.white ? const Color(0xFF4CAF50) : Colors.white,
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
