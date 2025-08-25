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

  @override
  void initState() {
    super.initState();
    _webrtcService = Provider.of<WebRTCService>(context, listen: false);
  }

  /// Принятие входящего звонка
  Future<void> _acceptCall() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });

    try {
      debugPrint('🔔 IncomingCallScreen: Принимаем звонок ${widget.callId}');
      
      // Принимаем звонок через WebRTCService
      final success = await _webrtcService.acceptCall(
        widget.callId,
        widget.callType == 'video' ? CallType.video : CallType.audio, // Используем тип из widget
      );

      if (success) {
        debugPrint('🔔 IncomingCallScreen: Звонок принят успешно');
        // Переходим на экран активного звонка
        if (mounted) {
          Navigator.push(
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
        debugPrint('🔥 IncomingCallScreen: Не удалось принять звонок');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось принять звонок')),
          );
        }
      }
    } catch (e) {
      debugPrint('🔥 IncomingCallScreen: Ошибка принятия звонка: $e');
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
      debugPrint('🔔 IncomingCallScreen: Отклоняем звонок ${widget.callId}');
      
      // Отклоняем звонок через WebRTCService
      _webrtcService.rejectCall(widget.callId);

      if (mounted) {
        // Возвращаемся к предыдущему экрану
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('🔥 IncomingCallScreen: Ошибка отклонения звонка: $e');
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
