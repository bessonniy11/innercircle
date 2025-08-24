import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../socket/call_socket_client.dart';
import 'webrtc_service.dart';
import '../../features/call/presentation/screens/incoming_call_screen.dart';

/// Сервис для отображения уведомлений о входящих звонках
class CallNotificationService {
  static final CallNotificationService _instance = CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal();

  /// Показать экран входящего звонка
  void showIncomingCall(BuildContext context, Map<String, dynamic> callData) {
    debugPrint('🔔 CallNotificationService: Показываем экран входящего звонка');
    debugPrint('🔔 CallNotificationService: Данные звонка: $callData');
    
    // Извлекаем данные звонка
    final callId = callData['callId'] as String?;
    final remoteUserId = callData['remoteUserId'] as String?;
    final callType = callData['callType'] as String?;

    debugPrint('🔔 CallNotificationService: callId: $callId, remoteUserId: $remoteUserId, callType: $callType');

    if (callId == null || remoteUserId == null || callType == null) {
      debugPrint('🔥 CallNotificationService: Неполные данные звонка: $callData');
      return;
    }

    // Показываем экран входящего звонка
    debugPrint('🔔 CallNotificationService: Навигация к IncomingCallScreen');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => IncomingCallScreen(
          callId: callId,
          remoteUserId: remoteUserId,
          callType: callType,
        ),
      ),
    );
    debugPrint('🔔 CallNotificationService: IncomingCallScreen показан');
  }

  /// Инициализация слушателей для входящих звонков
  void initializeListeners(BuildContext context, CallSocketClient callSocketClient) {
    debugPrint('🔔 CallNotificationService: Инициализация слушателей');
    
    // Слушаем входящие звонки
    callSocketClient.on('incoming_call', (data) {
      debugPrint('🔔 CallNotificationService: Получен входящий звонок: $data');
      
      // Показываем экран входящего звонка
      if (context.mounted) {
        showIncomingCall(context, data);
      }
    });
  }
}
