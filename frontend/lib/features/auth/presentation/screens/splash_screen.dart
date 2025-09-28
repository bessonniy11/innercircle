import 'package:flutter/material.dart';
import 'package:zvonilka/core/api/api_client.dart';
import 'package:zvonilka/core/services/auth_service.dart';
import 'package:zvonilka/features/auth/presentation/screens/login_screen.dart';
import 'package:zvonilka/features/chat/presentation/screens/chat_list_screen.dart';
import 'package:zvonilka/core/widgets/app_logo.dart';
import 'package:provider/provider.dart';
import 'package:zvonilka/core/services/push_notification_service.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:zvonilka/core/services/webrtc_service.dart';
import 'package:zvonilka/features/call/presentation/screens/active_call_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // НОВЫЙ ИМПОРТ
import 'package:zvonilka/core/socket/call_socket_client.dart';


/// Экран загрузки для проверки состояния аутентификации
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Небольшая задержка, чтобы UI успел отрисоваться
    Future.delayed(const Duration(milliseconds: 50), _checkAuthStatus);
  }

  /// Проверка состояния аутентификации при запуске
  Future<void> _checkAuthStatus() async {
    // Показываем splash screen минимум 1.5 секунды для лучшего UX
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (!mounted) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    
    // НОВОЕ: Передаем PushNotificationService в AuthService
    final pushService = Provider.of<PushNotificationService>(context, listen: false);
    authService.setPushNotificationService(pushService);
    
    // Проверяем, есть ли валидный refresh token
    final hasRefreshToken = await authService.hasValidRefreshToken();

    if (hasRefreshToken) {
      // Если есть, сразу пытаемся обновить токен доступа
      final refreshed = await authService.refreshAccessToken();
      if (refreshed) {
        // ЕСЛИ УСПЕШНО, ГАРАНТИРУЕМ ПОДКЛЮЧЕНИЕ К СОКЕТУ
        try {
          debugPrint('🔌 [Splash] Токен обновлен, ожидание подключения сокета...');
          final callSocketClient = Provider.of<CallSocketClient>(context, listen: false);
          await callSocketClient.ensureConnected();
          debugPrint('✅ [Splash] Сокет успешно подключен.');

          // ПРОВЕРЯЕМ НАЛИЧIE АКТИВНОГО ЗВОНКА ПОСЛЕ АВТОРИЗАЦИИ
          final callHandled = await _checkAndNavigateToCallingPage();

          // Если звонок не был обработан, переходим к списку чатов
          if (!callHandled) {
            _navigateToChatList();
          }
        } catch (e) {
          debugPrint('🚨 [Splash] Не удалось подключиться к сокету: $e. Переход на экран входа.');
          _navigateToLogin();
        }
      } else {
        _navigateToLogin();
      }
    } else {
      _navigateToLogin();
    }
  }

  /// Переход к экрану входа
  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  /// Переход к списку чатов
  void _navigateToChatList() async {
    if (!mounted) return;
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = await authService.getUserId();
    final username = await authService.getUsername();

    if (userId == null || username == null) {
      _navigateToLogin();
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ChatListScreen(
          currentUserId: userId,
          currentUsername: username,
        ),
      ),
    );
  }

  /// НОВЫЙ МЕТОД: Проверяет наличие активных звонков CallKit и открывает экран звонка.
  /// Возвращает true, если звонок был обработан, иначе false.
  Future<bool> _checkAndNavigateToCallingPage() async {
    // НОВАЯ ПРОВЕРКА: Эта логика только для мобильных платформ
    if (kIsWeb) {
      return false;
    }
    
    // Этот context УЖЕ имеет доступ ко всем Provider'ам
    if (!mounted) return false;

    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is List && calls.isNotEmpty) {
        debugPrint('📞 [Splash] Найден активный звонок: $calls');
        final callData = calls.first as Map<dynamic, dynamic>;
        
        // НОВОЕ: Безопасное извлечение данных
        final extra = callData['extra'] as Map<dynamic, dynamic>? ?? {};
        final callId = extra['callId'] as String?;
        final remoteUsername = extra['callerName'] as String?;
        final remoteUserId = extra['remoteUserId'] as String?;
        final callKitId = callData['id'] as String?;

        // Если критически важные данные отсутствуют, завершаем "сломанный" звонок
        if (callId == null || remoteUsername == null || remoteUserId == null || callKitId == null) {
          debugPrint('🚨 [Splash] Неполные данные в активном звонке CallKit. Завершаем его.');
          if(callKitId != null) {
            await FlutterCallkitIncoming.endCall(callKitId);
          }
          return false;
        }

        // --- НОВАЯ ЛОГИКА ---
        // 1. Получаем ApiClient, чтобы сделать запрос к бэкенду
        final apiClient = Provider.of<ApiClient>(context, listen: false);
        final webRTCService = Provider.of<WebRTCService>(context, listen: false);

        try {
          debugPrint('📞 [Splash] Запрос деталей звонка $callId с сервера...');
          final response = await apiClient.get('/calls/$callId');

          if (response.statusCode == 200) {
            final fullCallData = response.data;
            final sdpOffer = fullCallData['sdpOffer'];
            final List<dynamic>? iceCandidates = fullCallData['callerIceCandidates'];

            if (sdpOffer == null) {
              debugPrint('🚨 [Splash] SDP Offer не найден на сервере для звонка $callId. Завершаем звонок.');
              await FlutterCallkitIncoming.endCall(callKitId);
              return false;
            }

            debugPrint('✅ [Splash] SDP Offer получен. Начинаем инициализацию WebRTC.');

            // 2. Готовим сервис к принятию звонка
            await webRTCService.prepareForAcceptedCall(callId, remoteUserId, remoteUsername);
            
            // 3. Сообщаем сервису, что пользователь "принял" звонок (нажал на нативном UI)
            await webRTCService.acceptCall();

            // 4. "Скармливаем" сервису полученный SDP Offer
            await webRTCService.processSdpOffer({'sdp': sdpOffer});

            // 5. НОВОЕ: "Скармливаем" сервису полученные ICE кандидаты
            if (iceCandidates != null && iceCandidates.isNotEmpty) {
              debugPrint('📞 [Splash] Получено ${iceCandidates.length} сохраненных ICE кандидатов. Добавляем их.');
              await webRTCService.addStoredIceCandidates(iceCandidates);
            }

            debugPrint('📞 [Splash] WebRTC инициализирован. Переход на экран звонка...');
            
            // 6. Переходим на экран активного звонка
            final authService = Provider.of<AuthService>(context, listen: false);
            final userId = await authService.getUserId();
            final username = await authService.getUsername();

            if (userId == null || username == null) {
              debugPrint('🚨 [Splash] Не удалось получить данные текущего пользователя для навигации.');
              return false;
            }

            await Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => ActiveCallScreen(
                remoteUsername: remoteUsername,
                remoteUserId: remoteUserId,
                callType: webRTCService.callType,
                currentUserId: userId,
                currentUsername: username,
              )),
              (route) => false,
            );
            return true; // Звонок успешно обработан

          } else {
            debugPrint('🚨 [Splash] Ошибка при получении деталей звонка ${response.statusCode}. Завершаем звонок.');
            await FlutterCallkitIncoming.endCall(callKitId);
            return false;
          }
        } catch (e) {
          debugPrint('🚨 [Splash] Исключение при получении деталей звонка: $e. Завершаем звонок.');
          await FlutterCallkitIncoming.endCall(callKitId);
          return false;
        }
        // --- КОНЕЦ НОВОЙ ЛОГИКИ ---

      } else {
        debugPrint('📞 [Splash] Активных звонков CallKit не найдено.');
        return false; // Звонок не обработан
      }
    } catch (e) {
      debugPrint('🚨 [Splash] Ошибка при проверке активного звонка: $e');
      // В случае любой ошибки, пытаемся завершить все звонки, чтобы очистить состояние
      try {
        await FlutterCallkitIncoming.endAllCalls();
      } catch (_) {}
      return false; // Звонок не обработан
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50), // Фирменный зеленый фон
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Логотип приложения
            const AppLogo(size: 120),
            
            const SizedBox(height: 40),
            
            // Название приложения
            const Text(
              'Звонилка',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Подзаголовок
            const Text(
              'Семейный мессенджер',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
                fontWeight: FontWeight.w300,
              ),
            ),
            
            const SizedBox(height: 60),
            
            // Индикатор загрузки
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Текст загрузки
            const Text(
              'Подключение...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
