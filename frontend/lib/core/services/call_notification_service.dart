import 'package:flutter/material.dart';
import 'webrtc_service.dart';
import '../../features/call/presentation/screens/incoming_call_screen.dart';

/// Сервис для отображения уведомлений о входящих звонках
class CallNotificationService {
  static final CallNotificationService _instance = CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal();

  BuildContext? _context;

  /// Установка контекста для навигации
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Показать экран входящего звонка
  void showIncomingCall(Map<String, dynamic> callData) {
    debugPrint('🔔 CallNotificationService: Показываем экран входящего звонка');
    debugPrint('🔔 CallNotificationService: Данные звонка: $callData');
    
    final callId = callData['callId'] as String?;
    final remoteUserId = callData['remoteUserId'] as String?;
    final callType = callData['callType'] as String?;
    final remoteUsername = callData['remoteUsername'] as String?;
    
    debugPrint('🔔 CallNotificationService: callId: $callId, remoteUserId: $remoteUserId, callType: $callType, remoteUsername: $remoteUsername');

    if (callId == null || remoteUserId == null || callType == null) {
      debugPrint('🔥 CallNotificationService: Неполные данные звонка: $callData');
      return;
    }

    if (_context != null && _context!.mounted) {
      debugPrint('🔔 CallNotificationService: Навигация к IncomingCallScreen');
              Navigator.of(_context!).push(
          MaterialPageRoute(
            builder: (context) => IncomingCallScreen(
              callId: callId,
              remoteUserId: remoteUserId,
              callType: callType,
              remoteUsername: remoteUsername ?? 'Unknown User',
            ),
          ),
        );
      debugPrint('🔔 CallNotificationService: IncomingCallScreen показан');
    } else {
      debugPrint('⚠️ CallNotificationService: Контекст не установлен или не mounted');
    }
  }

  /// Инициализация с WebRTCService
  void initializeWithWebRTCService(WebRTCService webrtcService, BuildContext context) {
    debugPrint('🔔 CallNotificationService: Инициализация с WebRTCService');
    setContext(context);
    
    // Устанавливаем callback в WebRTCService
    webrtcService.setIncomingCallCallback(showIncomingCall);
  }
}
