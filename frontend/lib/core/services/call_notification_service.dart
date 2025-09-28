import 'package:flutter/material.dart';
import 'webrtc_service.dart';
import '../../features/call/presentation/screens/incoming_call_screen.dart';
import '../../features/call/domain/models/call_model.dart'; // ИМПОРТИРУЕМ МОДЕЛЬ

/// Сервис для отображения уведомлений о входящих звонках
class CallNotificationService {
  static final CallNotificationService _instance = CallNotificationService._internal();
  factory CallNotificationService() => _instance;
  CallNotificationService._internal();

  BuildContext? _context;
  final Map<String, BuildContext> _contexts = {};

  /// Установка контекста для навигации
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Добавить контекст для конкретного экрана
  void addContext(String screenId, BuildContext context) {
    _contexts[screenId] = context;
    debugPrint('🔔 CallNotificationService: Добавлен контекст для экрана: $screenId');
  }

  /// Удалить контекст для конкретного экрана
  void removeContext(String screenId) {
    _contexts.remove(screenId);
    debugPrint('🔔 CallNotificationService: Удален контекст для экрана: $screenId');
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

    // Пытаемся найти активный контекст
    BuildContext? activeContext = _context;
    
    // Если основной контекст недействителен, ищем в сохраненных
    if (activeContext == null || !activeContext.mounted) {
      for (final context in _contexts.values) {
        if (context.mounted) {
          activeContext = context;
          break;
        }
      }
    }

    if (activeContext != null && activeContext!.mounted) {
      debugPrint('🔔 CallNotificationService: Навигация к IncomingCallScreen');
      
      // КОНВЕРТИРУЕМ СТРОКУ В ENUM
      final type = callType == 'video' ? CallType.video : CallType.voice;

      Navigator.of(activeContext!).push(
        MaterialPageRoute(
          builder: (context) => IncomingCallScreen(
            callId: callId,
            remoteUserId: remoteUserId,
            callType: type, // ПЕРЕДАЕМ ПРАВИЛЬНЫЙ ТИП
            remoteUsername: remoteUsername ?? 'Unknown User',
          ),
        ),
      );
      debugPrint('🔔 CallNotificationService: IncomingCallScreen показан');
    } else {
      debugPrint('⚠️ CallNotificationService: Нет активного контекста для навигации');
    }
  }

  /// Инициализация с WebRTCService
  void initializeWithWebRTCService(WebRTCService webrtcService, BuildContext context) {
    debugPrint('🔔 CallNotificationService: Инициализация с WebRTCService');
    setContext(context);
    
    // Устанавливаем callback в WebRTCService
    // webrtcService.setIncomingCallCallback(showIncomingCall); // УДАЛЯЕМ УСТАРЕВШИЙ ВЫЗОВ
  }
}
