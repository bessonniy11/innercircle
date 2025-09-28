import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zvonilka/features/call/domain/models/call_model.dart';
import 'package:zvonilka/core/services/webrtc_service.dart';
import 'package:zvonilka/features/call/presentation/screens/incoming_call_screen.dart';
import 'package:zvonilka/features/call/presentation/screens/active_call_screen.dart';

/// Экран звонка с WebRTC интеграцией
class CallScreen extends StatefulWidget {
  final CallModel call;
  final String currentUserId;
  final bool isIncoming;

  const CallScreen({
    super.key,
    required this.call,
    required this.currentUserId,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late WebRTCService _webrtcService;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isConnecting = false;
  bool _isConnected = false;
  Duration _callDuration = Duration.zero;
  late Timer _durationTimer;

  @override
  void initState() {
    super.initState();
    _webrtcService = Provider.of<WebRTCService>(context, listen: false);
    _initializeCall();
    _startDurationTimer();
  }

  @override
  void dispose() {
    _durationTimer.cancel();
    super.dispose();
  }

  /// Инициализация звонка
  Future<void> _initializeCall() async {
    try {
      setState(() {
        _isConnecting = true;
      });

      if (widget.isIncoming) {
        // Входящий звонок - ждем ответа
        _showIncomingCallUI();
      } else {
        // Исходящий звонок - инициализируем WebRTC
        await _initializeWebRTC();
        await _startOutgoingCall();
      }
    } catch (e) {
      debugPrint('🔥 Error initializing call: $e');
      if (mounted) {
        _showErrorDialog('Ошибка инициализации звонка: $e');
      }
    }
  }

  /// Инициализация WebRTC
  Future<void> _initializeWebRTC() async {
    try {
      // WebRTC инициализируется автоматически при создании сервиса
      setState(() {
        _isConnecting = false;
        _isConnected = true;
      });

    } catch (e) {
      debugPrint('🔥 Error initializing WebRTC: $e');
      rethrow;
    }
  }

  /// Запуск исходящего звонка
  Future<void> _startOutgoingCall() async {
    try {
      setState(() {
        _isConnecting = true;
      });

      // Инициация звонка через WebRTCService
      final success = await _webrtcService.initiateCall(
        widget.call.receiverId,
        widget.call.type,
      );
      
      if (success) {
        debugPrint('🔔 Call initiated successfully');
        // НЕ запускаем таймер здесь - только когда звонок принят!
      } else {
        debugPrint('🔥 Failed to start call');
      }

    } catch (e) {
      debugPrint('🔥 Error starting call: $e');
      rethrow;
    }
  }

  /// Показать UI для входящего звонка
  void _showIncomingCallUI() {
    setState(() {
      _isConnecting = false;
    });
  }

  /// Ответ на входящий звонок
  Future<void> _answerCall() async {
    try {
      // Принимаем звонок через WebRTCService
      final success = await _webrtcService.acceptCall();
      
      if (success) {
        debugPrint('🔊 Call answered');
        setState(() {
          _isConnected = true;
        });
      } else {
        debugPrint('🔥 Failed to answer call');
      }

    } catch (e) {
      debugPrint('🔥 Error answering call: $e');
      rethrow;
    }
  }

  /// Отклонить входящий звонок
  Future<void> _rejectCall() async {
    try {
      debugPrint('🔊 Call rejected');

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('🔥 Error rejecting call: $e');
    }
  }

  /// Завершить звонок
  Future<void> _endCall() async {
    try {
      debugPrint('🔊 Call ended');

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('🔥 Error ending call: $e');
    }
  }

  /// Переключение микрофона
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    
    _webrtcService.setMicrophoneMute(_isMuted);
  }

  /// Переключение динамика
  void _toggleSpeaker() {
    setState(() {
      _isSpeakerOn = !_isSpeakerOn;
    });
    
    _webrtcService.setSpeakerphoneOn(_isSpeakerOn);
  }

  /// Запуск таймера длительности
  void _startDurationTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isConnected) {
        setState(() {
          _callDuration = DateTime.now().difference(widget.call.createdAt);
        });
      }
    });
  }

  /// Обновление длительности звонка
  void _updateCallDuration() {
    if (mounted && _isConnected) {
      setState(() {
        _callDuration = DateTime.now().difference(widget.call.createdAt);
      });
    }
  }

  /// Очистка WebRTC ресурсов
  Future<void> _disposeWebRTC() async {
    try {
      // WebRTCService автоматически очищает ресурсы при dispose
      debugPrint('🔔 WebRTC resources disposed');
    } catch (e) {
      debugPrint('🔥 Error disposing WebRTC: $e');
    }
  }

  /// Показать диалог ошибки
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ошибка'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Форматирование длительности звонка
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final peerUsername = widget.call.getPeerUsername(widget.currentUserId);
    final isCaller = widget.call.isCaller(widget.currentUserId);

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
                        peerUsername.isNotEmpty ? peerUsername[0].toUpperCase() : '?',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Имя собеседника
                    Text(
                      peerUsername,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Статус звонка
                    if (_isConnecting)
                      const Text(
                        'Подключение...',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      )
                    else if (_isConnected)
                      Text(
                        _formatDuration(_callDuration),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      )
                    else if (widget.isIncoming)
                      const Text(
                        'Входящий звонок',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                      )
                    else
                      const Text(
                        'Вызов...',
                        style: TextStyle(
                          fontSize: 18,
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
                      onPressed: _isConnected ? _toggleMute : null,
                    ),

                    // Основная кнопка (принять/завершить)
                    if (widget.isIncoming && !_isConnected)
                      _buildMainButton(
                        icon: Icons.call,
                        color: Colors.green,
                        onPressed: _answerCall,
                      )
                    else
                      _buildMainButton(
                        icon: Icons.call_end,
                        color: Colors.red,
                        onPressed: _endCall,
                      ),

                    // Кнопка динамика
                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                      color: Colors.white,
                      onPressed: _isConnected ? _toggleSpeaker : null,
                    ),
                  ],
                ),
              ),
            ),

            // Кнопка отклонения для входящего звонка
            if (widget.isIncoming && !_isConnected)
              Padding(
                padding: const EdgeInsets.only(bottom: 32),
                child: _buildMainButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  onPressed: _rejectCall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Построение основной кнопки
  Widget _buildMainButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
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
        color: Colors.white,
        onPressed: onPressed,
      ),
    );
  }

  /// Построение кнопки управления
  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: IconButton(
        icon: Icon(icon, size: 30),
        color: color,
        onPressed: onPressed,
      ),
    );
  }
}

