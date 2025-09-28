import 'package:flutter/foundation.dart'; // <-- ИМПОРТ ДЛЯ kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:provider/provider.dart';
import 'package:zvonilka/core/api/api_client.dart'; // <-- ИМПОРТИРУЕМ API CLIENT
import 'package:zvonilka/core/services/webrtc_service.dart';

/// Этот сервис отвечает за прослушивание и обработку событий от нативного UI звонков (CallKit/ConnectionService).
class CallKitService {
  // Убираем зависимость от BuildContext
  // final BuildContext _context;

  // Храним ссылку на ApiClient, полученную при инициализации
  ApiClient? _apiClient;
  WebRTCService? _webrtcService;

  CallKitService() {
    // Инициализация теперь будет вызываться извне, после того как сервисы будут доступны
  }
  
  void initialize(BuildContext context) {
    // Сохраняем ссылки на сервисы
    _apiClient = Provider.of<ApiClient>(context, listen: false);
    _webrtcService = Provider.of<WebRTCService>(context, listen: false,);
    
    // Эта логика предназначена только для мобильных платформ
    if (kIsWeb) {
      return;
    }

    debugPrint('📞 [CallKitService] Инициализация слушателя событий для FOREGROUND...');
    // Этот слушатель теперь будет отвечать ТОЛЬКО за события, когда приложение уже запущено и активно.
    // Фоновые события обрабатываются глобальным хендлером в main.dart
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;

      debugPrint('📞 [CallKitService] Получено FOREGROUND событие: ${event.event}');
      debugPrint('📞 [CallKitService] Тело события: ${event.body}');

      // Логика обработки событий, специфичная для открытого приложения, остается здесь.
      // Например, если звонок отклонен из UI приложения, а не из CallKit.
      // На данный момент, мы полагаемся на фоновый обработчик, но эта структура остается для будущих доработок.
      switch (event.event) {
        case Event.actionCallAccept:
          debugPrint('📞 [CallKitService] Пользователь принял звонок в открытом приложении.');
          _webrtcService?.acceptCall();
          break;
        case Event.actionCallDecline:
          debugPrint('📞 [CallKitService] Пользователь отклонил звонок в открытом приложении.');
          _handleCallDecline(event.body);
          break;
        case Event.actionCallTimeout:
          debugPrint('📞 [CallKitService] Звонок в открытом приложении не был отвечен (тайм-аут).');
          _handleCallDecline(event.body);
          break;
        case Event.actionCallEnded:
          debugPrint('📞 [CallKitService] Пользователь завершил звонок из нативного UI.');
          _webrtcService?.endCall();
          break;
        default:
          break;
      }
    });
  }

  /// Обрабатывает отклонение или таймаут звонка через HTTP запрос (когда приложение активно).
  Future<void> _handleCallDecline(dynamic body) async {
    try {
      final String callKitId = body['id'];
      final String callId = body['extra']['callId'];
      
      if (_apiClient == null) {
        debugPrint('🚨 [CallKitService] ApiClient не инициализирован.');
        return;
      }

      debugPrint('📞 [CallKitService] Отклонение звонка callId: $callId, callKitId: $callKitId');

      // 1. Отправляем HTTP запрос на бэкенд для надежности
      // Используем публичный эндпоинт для унификации логики
      await _apiClient!.post('/calls/public/respond', data: {
        'callId': callId,
        'action': 'reject',
      });
      debugPrint('📞 [CallKitService] HTTP запрос на отклонение отправлен.');

      // 2. Завершаем сессию CallKit, чтобы убрать UI
      await endCall(callKitId);
      debugPrint('📞 [CallKitService] UI CallKit завершен.');

    } catch (e) {
      debugPrint('🚨 [CallKitService] Ошибка при отклонении звонка: $e');
      // В случае ошибки все равно пытаемся завершить UI
      await endCall(body['id']);
    }
  }
  
  /// Завершает конкретный звонок в нативном UI.
  Future<void> endCall(String callKitId) async {
    if (kIsWeb) return;
    try {
      await FlutterCallkitIncoming.endCall(callKitId);
      debugPrint('📞 [CallKitService] UI CallKit для звонка $callKitId завершен.');
    } catch (e) {
      debugPrint('🚨 [CallKitService] Ошибка при завершении UI CallKit для звонка $callKitId: $e');
    }
  }

  /// Завершает ВСЕ активные звонки в нативном UI.
  Future<void> endAllCalls() async {
    if (kIsWeb) return;
    try {
      await FlutterCallkitIncoming.endAllCalls();
      debugPrint('📞 [CallKitService] Все UI CallKit завершены.');
    } catch (e) {
      debugPrint('🚨 [CallKitService] Ошибка при завершении всех UI CallKit: $e');
    }
  }
}
