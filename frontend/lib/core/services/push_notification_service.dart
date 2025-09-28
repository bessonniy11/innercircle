import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
// НОВОЕ: Прямые импорты для доступа к классам параметров
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/entities/notification_params.dart';
import 'package:uuid/uuid.dart';
import 'package:zvonilka/core/api/api_client.dart';


/**
 * Обработчик фоновых сообщений Firebase.
 * 
 * Эта функция ДОЛЖНА быть функцией верхнего уровня (не методом класса).
 * Она будет вызываться, когда приложение получит уведомление в фоновом режиме или будет закрыто.
 * 
 * @param message - Входящее сообщение от FCM.
 */
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("📳 Handling a background message: ${message.messageId}");
  debugPrint("   - Data: ${message.data}");
  
  // Парсим данные из уведомления
  final String callId = message.data['callId'] ?? '';
  final String callerName = message.data['callerName'] ?? 'Неизвестный';
  
  // Генерируем уникальный UUID для сессии CallKit
  final String callKitId = const Uuid().v4();

  // ВОЗВРАЩАЕМ КОРРЕКТНЫЙ КОД: Используем типизированный класс CallKitParams
  final params = CallKitParams(
    id: callKitId,
    nameCaller: callerName,
    appName: 'Звонилка',
    handle: 'Входящий звонок',
    type: 0, // 0 for voice call, 1 for video call
    duration: 60000, // Таймаут в миллисекундах (60 сек)
    textAccept: 'Принять',
    textDecline: 'Отклонить',
    missedCallNotification: NotificationParams(
      showNotification: true,
      isShowCallback: true,
      subtitle: 'Пропущенный звонок от $callerName',
    ),
    extra: <String, dynamic>{
      'callId': callId, // Наш внутренний ID звонка
      'callerName': callerName,
    },
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: false,
      ringtonePath: 'system_ringtone_default',
      backgroundColor: '#4CAF50',
      actionColor: '#2E7D32',
      incomingCallNotificationChannelName: 'Входящие звонки',
      missedCallNotificationChannelName: 'Пропущенные звонки',
    ),
    ios: const IOSParams(
      iconName: 'CallKitLogo',
      handleType: 'generic',
      supportsVideo: false,
      maximumCallGroups: 2,
      maximumCallsPerCallGroup: 1,
      audioSessionMode: 'voiceChat',
      audioSessionActive: true,
      audioSessionPreferredSampleRate: 44100.0,
      audioSessionPreferredIOBufferDuration: 0.005,
      supportsDTMF: true,
      supportsHolding: true,
      supportsGrouping: false,
      supportsUngrouping: false,
      ringtonePath: 'system_ringtone_default',
    ),
  );

  await FlutterCallkitIncoming.showCallkitIncoming(params);
}


/**
 * Сервис для управления Push-уведомлениями.
 * 
 * Отвечает за:
 * - Инициализацию Firebase Cloud Messaging.
 * - Получение и отправку FCM токена на бэкенд.
 * - (В будущем) обработку входящих уведомлений.
 * 
 * @since 2.2.0
 * @author ИИ-Ассистент + Bessonniy
 */
class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final ApiClient _apiClient;
  Function(Map<String, dynamic>)? _onForegroundCall; // НОВЫЙ КОЛБЭК

  PushNotificationService(this._apiClient);

  // НОВЫЙ МЕТОД
  void setForegroundCallCallback(Function(Map<String, dynamic>) callback) {
    _onForegroundCall = callback;
  }

  /**
   * Инициализирует сервис, запрашивает разрешения и получает FCM токен.
   * Отправляет токен на бэкенд, если он получен.
   */
  Future<void> initialize() async {
    // 1. Запрос разрешений на получение уведомлений (критически важно для iOS)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted permission for notifications');
    } else {
      debugPrint('❌ User declined or has not accepted permission for notifications');
      // В реальном приложении здесь можно показать диалог с просьбой включить уведомления в настройках
    }

    // 2. Получение FCM токена
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint('📱 FCM Token: $token');
        // 3. Отправка токена на бэкенд
        await _sendTokenToServer(token);
      } else {
        debugPrint('⚠️ FCM Token is null.');
      }

      // 4. Подписка на обновление токена (он может меняться)
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM Token refreshed: $newToken');
        _sendTokenToServer(newToken);
      });

    } catch (e) {
      debugPrint('🚨 Error getting FCM token: $e');
    }

    // 5. Установка обработчиков сообщений
    _setupMessageHandlers();
  }

  /**
   * Настраивает обработчики для входящих Push-уведомлений.
   */
  void _setupMessageHandlers() {
    // Обработчик для сообщений, когда приложение в Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 [PUSH] Сообщение в foreground: ${message.notification?.title}');
      
      // ВАЖНО: Больше не инициируем звонок через WebRTCService отсюда.
      // WebSocket является единственным источником правды для онлайн-клиентов.
      // Здесь можно показать локальное уведомление, если это необходимо в будущем.

      /*
      final String callId = message.data['callId'] ?? '';
      if (callId.isNotEmpty && _onForegroundCall != null) {
        _onForegroundCall!({
          'callId': callId,
          'callerName': message.data['callerName'],
          'remoteUserId': message.data['remoteUserId'],
          'callType': message.data['callType'],
        });
      }
      */
    });

    // Обработчик для сообщений, когда приложение открывается из Background (пользователь тапнул на уведомление)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📲 Message clicked!');
      debugPrint('   - Message data: ${message.data}');
      // Здесь можно навигироваться на экран звонка
    });
    
    // Устанавливаем фоновый обработчик
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    debugPrint('✅ Firebase message handlers configured.');
  }

  /**
   * Отправляет FCM токен на бэкенд через API клиент.
   * @param token - FCM токен для отправки.
   */
  Future<void> _sendTokenToServer(String? token) async {
    if (token == null) {
      debugPrint('FCM Token is null. Not sending to server.');
      return;
    }

    debugPrint('📳 Sending FCM token to server: $token');

    try {
      // ИСПРАВЛЕНИЕ: Передаем данные в параметре `data`, как этого ожидает Dio.
      await _apiClient.post('/users/fcm-token', data: {'fcmToken': token});
      debugPrint('📳 FCM token sent to server successfully.');
    } catch (e) {
      debugPrint('Error sending FCM token to server: $e');
    }
  }
}
