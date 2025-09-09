import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/webrtc_service.dart';
import 'active_call_screen.dart';

/// Экран для отображения входящего звонка
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String remoteUserId;
  final String callType;
  final String remoteUsername;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.remoteUserId,
    required this.callType,
    required this.remoteUsername,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late WebRTCService _webrtcService;
  bool _isProcessing = false;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _webrtcService = Provider.of<WebRTCService>(context, listen: false);
    _webrtcService.addListener(_onCallStateChanged);
  }

  @override
  void dispose() {
    _webrtcService.removeListener(_onCallStateChanged);
    super.dispose();
  }
  
  void _onCallStateChanged() {
    // Если звонок был завершен удаленно (например, звонящий отменил его)
    if ((_webrtcService.callState == CallState.ended || _webrtcService.callState == CallState.idle) && !_isClosing && mounted) {
      setState(() {
        _isClosing = true;
      });
      Navigator.of(context).pop();
    }
  }

  /// Принятие входящего звонка
  Future<void> _acceptCall() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      
      // Принимаем звонок через WebRTCService
      final success = await _webrtcService.acceptCall(
        widget.callId,
        widget.callType == 'video' ? CallType.video : CallType.audio,
      );

      if (success) {
        // Переходим на экран активного звонка
        if (mounted) {
          // ИСПРАВЛЕНИЕ: Используем pushReplacement, чтобы заменить текущий экран (IncomingCallScreen)
          // на ActiveCallScreen. Это предотвращает возврат к экрану входящего вызова
          // после завершения звонка.
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ActiveCallScreen(
                remoteUserId: widget.remoteUserId,
                remoteUsername: widget.remoteUsername, // Используем переданное имя
                callType: widget.callType == 'video' ? CallType.video : CallType.audio,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось принять звонок')),
          );
          // Закрываем экран
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  /// Отклонение входящего звонка
  Future<void> _rejectCall() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      
      // Отклоняем звонок через WebRTCService
      _webrtcService.rejectCall(widget.callId);

      if (mounted) {
        // Закрываем экран
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
                    // Аватар звонящего
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: Text(
                        'U',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Имя звонящего
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        'Входящий звонок от ${widget.remoteUsername}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Тип звонка
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Text(
                        widget.callType == 'video' ? 'Видеозвонок' : 'Аудиозвонок',
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white70,
                        ),
                        textAlign: TextAlign.center,
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
                    // Кнопка отклонения
                    _buildControlButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      onPressed: _isProcessing ? null : _rejectCall,
                      label: 'Отклонить',
                    ),

                    // Кнопка принятия
                    _buildControlButton(
                      icon: Icons.call,
                      color: Colors.green,
                      onPressed: _isProcessing ? null : _acceptCall,
                      label: 'Принять',
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
    required VoidCallback? onPressed,
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
            color: Colors.white,
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
