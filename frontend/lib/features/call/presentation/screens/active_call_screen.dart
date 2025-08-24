import 'dart:async';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import '../../../../core/services/webrtc_service.dart' as webrtc;

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

  @override
  void initState() {
    super.initState();
    _webrtcService = Provider.of<webrtc.WebRTCService>(context, listen: false);
    
    // Слушаем изменения состояния звонка
    _webrtcService.addListener(_onCallStateChanged);
    
    // Проверяем текущее состояние
    if (_webrtcService.callState == webrtc.CallState.connected) {
      _startDurationTimer();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _webrtcService.removeListener(_onCallStateChanged);
    super.dispose();
  }
  
  /// Обработчик изменения состояния звонка
  void _onCallStateChanged() {
    if (mounted) {
      if (_webrtcService.callState == webrtc.CallState.connected) {
        // Звонок подключен - запускаем таймер
        if (_durationTimer == null) {
          debugPrint('🔔 ActiveCallScreen: Звонок подключен, запускаем таймер');
          _startDurationTimer();
        }
      } else if (_webrtcService.callState == webrtc.CallState.ended || 
                 _webrtcService.callState == webrtc.CallState.error) {
        // Звонок завершен - останавливаем таймер и закрываем экран
        debugPrint('🔔 ActiveCallScreen: Звонок завершен, закрываем экран');
        _durationTimer?.cancel();
        if (mounted) {
          Navigator.pop(context);
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
    debugPrint('🔊 Speaker ${_isSpeakerOn ? "on" : "off"}');
  }

  /// Завершение звонка
  void _endCall() {
    _webrtcService.endCall();
    if (mounted) {
      Navigator.pop(context);
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
                    // Аватар собеседника
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
