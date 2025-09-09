# 📱 Inner Circle - Flutter Mobile App

**Мобильное приложение семейного мессенджера "Inner Circle"**

## 📋 Содержание
- [Требования к системе](#требования-к-системе)
- [Быстрый старт](#быстрый-старт)
- [Разработка](#разработка)
- [Сборка релиза](#сборка-релиза)
- [Подключение к Backend](#подключение-к-backend)
- [Тестирование](#тестирование)
- [Решение проблем](#решение-проблем)

---

## 🛠 Требования к системе

### **Обязательные требования:**
- **Flutter SDK:** v3.10.0 или выше
- **Dart SDK:** v3.0.0 или выше (обычно идет с Flutter)
- **Android Studio** с Android SDK (для Android разработки)
- **Xcode** (только для iOS разработки на macOS)

### **Для Android разработки:**
- **Android SDK:** API Level 21 (Android 5.0) или выше
- **Android Emulator** или физическое Android устройство
- **Java JDK:** 11 или выше

### **Для iOS разработки (только macOS):**
- **Xcode:** 14.0 или выше
- **iOS Simulator** или физическое iOS устройство
- **CocoaPods:** для управления зависимостями

---

## 🚀 Быстрый старт

### **1. Проверка Flutter установки**
```bash
flutter doctor
```
**Результат должен показать:** ✅ для всех необходимых компонентов

### **2. Установка зависимостей**
```bash
cd frontend
flutter pub get
```

### **3. Запуск приложения**
```bash
# Запуск на подключенном устройстве/эмуляторе
flutter run

# Выбор конкретного устройства
flutter devices  # посмотреть доступные устройства
flutter run -d <device_id>

# Запуск в debug режиме на Chrome (web)
flutter run -d chrome
```

### **4. Первый вход в приложение**
- **Пригласительный код:** `secret_invite`
- **Создайте аккаунт** с любым именем пользователя и паролем (минимум 6 символов)
- **После регистрации войдите** с теми же данными

---

## 👨‍💻 Разработка

### **Структура проекта:**
```
lib/
├── core/                     # Основные сервисы
│   ├── api/                 # HTTP клиент (Dio)
│   │   └── api_client.dart
│   └── socket/              # Socket.IO клиент
│       └── socket_client.dart
├── features/                # Функциональные модули
│   ├── auth/               # Аутентификация
│   │   └── presentation/
│   │       └── screens/
│   │           ├── login_screen.dart
│   │           └── registration_screen.dart
│   └── chat/               # Чаты и сообщения
│       ├── domain/
│       │   └── models/
│       │       └── message_model.dart
│       └── presentation/
│           └── screens/
│               ├── chat_list_screen.dart
│               └── message_screen.dart
└── main.dart               # Точка входа
```

### **Основные зависимости:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0                    # HTTP клиент для API запросов
  socket_io_client: ^3.1.2       # Socket.IO для real-time сообщений
```

### **Hot Reload (горячая перезагрузка):**
- **В терминале:** Нажмите `r` для hot reload
- **В IDE:** Ctrl+S (VS Code) или Cmd+S (macOS) автоматически запускает hot reload

### **Отладка:**
```bash
# Запуск с подробными логами
flutter run --verbose

# Очистка кеша (если что-то работает неправильно)
flutter clean
flutter pub get
```

---

## 📦 Сборка релиза

### **Android APK:**

#### **1. Подготовка к сборке:**
```bash
# Очистка проекта
flutter clean
flutter pub get
```

#### **2. Сборка APK:**
```bash
# Сборка APK для всех архитектур (универсальный APK)
flutter build apk

# Сборка APK для конкретной архитектуры (меньший размер)
flutter build apk --target-platform android-arm64

# Сборка split APKs (отдельные APK для каждой архитектуры)
flutter build apk --split-per-abi
```

#### **3. Местоположение APK:**
```
build/app/outputs/flutter-apk/
├── app-release.apk           # Универсальный APK
├── app-arm64-v8a-release.apk # Для ARM64 устройств
├── app-armeabi-v7a-release.apk # Для ARM32 устройств
└── app-x86_64-release.apk    # Для x86_64 устройств
```

#### **4. Установка APK на устройство:**
```bash
# Установка через ADB
adb install build/app/outputs/flutter-apk/app-release.apk

# Или просто скопируйте APK на устройство и установите вручную
```

### **Android App Bundle (для Google Play):**
```bash
# Сборка App Bundle
flutter build appbundle

# Результат в: build/app/outputs/bundle/release/app-release.aab
```

### **Web (веб-версия):**
```bash
# 1. Убедитесь, что backend настроен на прием запросов с вашего домена (CORS)

# 2. Сборка production-версии веб-приложения
# Используем --web-renderer canvaskit для лучшей совместимости
flutter build web --release --web-renderer canvaskit --dart-define-from-file=.env.production

# 3. Результат будет в папке: build/web/
#    Содержимое этой папки нужно загрузить на ваш хостинг.
```

### **iOS (только на macOS):**

#### **1. Подготовка:**
```bash
# Установка CocoaPods зависимостей
cd ios
pod install
cd ..
```

#### **2. Сборка для iOS:**
```bash
# Сборка iOS приложения
flutter build ios

# Сборка IPA файла
flutter build ipa
```

#### **3. Результат:**
- **Xcode проект:** `ios/Runner.xcworkspace`
- **IPA файл:** `build/ios/ipa/`

---

## 🔗 Подключение к Backend

### **Конфигурация API:**

**Файл:** `lib/core/api/api_client.dart`

```dart
// Для локальной разработки
baseUrl: 'http://localhost:3000'

// Для production (замените на ваш сервер)
baseUrl: 'https://yourdomain.com'

// Для Android эмулятора (подключение к localhost на хост-машине)
baseUrl: 'http://10.0.2.2:3000'
```

### **Конфигурация Socket.IO:**

**Файл:** `lib/core/socket/socket_client.dart`

```dart
// Тот же URL что и для API
IO.io('http://localhost:3000', options)
```

### **Для различных сред:**

#### **Localhost (разработка):**
- **Backend URL:** `http://localhost:3000`
- **Требования:** Backend должен быть запущен локально

#### **Android Эмулятор:**
- **Backend URL:** `http://10.0.2.2:3000`
- **Причина:** `10.0.2.2` - это localhost хост-машины из Android эмулятора

#### **Физическое устройство в той же сети:**
- **Backend URL:** `http://192.168.x.x:3000`
- **Как узнать IP:** `ipconfig` (Windows) или `ifconfig` (Linux/macOS)

#### **Production сервер:**
- **Backend URL:** `https://yourdomain.com`
- **Требования:** SSL сертификат для HTTPS

---

## 🧪 Тестирование

### **Ручное тестирование:**

1. **Регистрация:**
   - Код приглашения: `secret_invite`
   - Проверить валидацию полей
   - Проверить уникальность имени пользователя

2. **Авторизация:**
   - Вход с правильными данными
   - Проверка неправильных данных
   - Автоматическое перенаправление после входа

3. **Чаты:**
   - Отображение списка чатов
   - Отправка сообщений
   - Получение сообщений в реальном времени

### **Автоматические тесты:**
```bash
# Запуск unit тестов
flutter test

# Запуск интеграционных тестов
flutter test integration_test/
```

### **Тестирование производительности:**
```bash
# Профилирование производительности
flutter run --profile

# Анализ размера приложения
flutter build apk --analyze-size
```

---

## 🆘 Решение проблем

### **Частые проблемы и решения:**

#### **1. Ошибки установки зависимостей:**
```bash
# Очистка и переустановка
flutter clean
flutter pub cache repair
flutter pub get
```

#### **2. Проблемы с Android сборкой:**
```bash
# Очистка Gradle кеша
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

#### **3. Ошибки подключения к backend:**
- **Проверьте URL** в `api_client.dart` и `socket_client.dart`
- **Для Android эмулятора** используйте `10.0.2.2` вместо `localhost`
- **Проверьте CORS** настройки на backend
- **Убедитесь что backend запущен** и доступен

#### **4. Socket.IO не подключается:**
```dart
// Добавьте больше логирования в socket_client.dart
_socket.onConnectError((error) => debugPrint('Socket Error: $error'));
_socket.onError((error) => debugPrint('Socket.IO Error: $error'));
```

#### **5. APK не устанавливается:**
- **Включите "Неизвестные источники"** в настройках Android
- **Проверьте архитектуру** устройства и используйте соответствующий APK
- **Для тестирования** используйте debug APK: `flutter build apk --debug`

### **Логи и отладка:**

#### **Flutter логи:**
```bash
# Просмотр логов устройства
flutter logs

# Детальные логи
flutter logs --verbose
```

#### **Android логи:**
```bash
# Логи через ADB
adb logcat | grep flutter
```

#### **Отладка в IDE:**
- **VS Code:** Используйте Flutter Inspector и Debug Console
- **Android Studio:** Встроенный Flutter Inspector

---

## 📱 Поддерживаемые платформы

### **✅ Поддерживается:**
- **Android:** API 21+ (Android 5.0+)
- **iOS:** iOS 11.0+ (планируется)
- **Web:** Chrome, Firefox, Safari (для тестирования)

### **❌ Не поддерживается:**
- **Windows Desktop** (пока не требуется)
- **macOS Desktop** (пока не требуется)
- **Linux Desktop** (пока не требуется)

---

## 🔧 Дополнительные команды

### **Анализ кода:**
```bash
# Анализ качества кода
flutter analyze

# Форматирование кода
dart format lib/
```

### **Обновление зависимостей:**
```bash
# Обновление до последних версий
flutter pub upgrade

# Просмотр устаревших зависимостей
flutter pub outdated
```

### **Информация о проекте:**
```bash
# Информация о Flutter проекте
flutter config

# Размер приложения
flutter build apk --analyze-size
```

---

## 📞 Поддержка

### **Документация:**
- **Flutter:** [https://docs.flutter.dev/](https://docs.flutter.dev/)
- **Dart:** [https://dart.dev/guides](https://dart.dev/guides)
- **Dio:** [https://pub.dev/packages/dio](https://pub.dev/packages/dio)
- **Socket.IO Client:** [https://pub.dev/packages/socket_io_client](https://pub.dev/packages/socket_io_client)

### **Полезные команды для диагностики:**
```bash
# Полная информация о системе Flutter
flutter doctor -v

# Информация о подключенных устройствах
flutter devices

# Конфигурация Flutter
flutter config
```

---

**📅 Последнее обновление:** 16.08.2025  
**👨‍💻 Автор:** ИИ-Ассистент + Bessonniy  
**📱 Версия Flutter:** 3.10.0+  
**🎯 Статус:** Готово к разработке ✅

---

## 🚨 Текущие Проблемы и Ограничения

### **Критические проблемы (25.08.2025):**

#### **1. WebRTC звонки работают частично** 📞
- ✅ **Сигналинг работает:** экраны входящих звонков, таймеры, UI полностью функциональны
- ✅ **WebSocket соединения:** стабильно работают между устройствами
- ❌ **Аудио не передается:** пользователи не слышат друг друга во время звонка

**Возможные причины:**
- Отсутствуют STUN/TURN серверы для NAT traversal
- ICE candidates не обмениваются корректно
- Медиа потоки не устанавливаются peer-to-peer

**Решение:** Настройка STUN/TURN серверов на production сервере

#### **2. JWT токены устаревают** 🔐
- ✅ **Авторизация работает** при первом входе
- ❌ **Через время (несколько часов)** чаты и контакты исчезают
- ❌ **При перезаходе** всё работает нормально

**Причина:** Отсутствует автоматическое обновление JWT токенов

**Решение:** Реализация refresh token системы

#### **3. Отсутствие шифрования** 🔒
- ❌ **Сообщения не шифруются** end-to-end
- ❌ **WebRTC медиа не шифруется** дополнительно
- ✅ **Только HTTPS** на уровне транспорта (Nginx)

**Планы:** End-to-end шифрование в Phase 3

### **Технические ограничения:**
- **WebRTC:** Требует STUN/TURN серверы для работы через NAT
- **Безопасность:** Базовый уровень (JWT + HTTPS), без end-to-end шифрования
- **Масштабируемость:** Оптимизировано под 5-10 пользователей
- **Файлы:** Пока только текстовые сообщения

---

## 🎯 Статус Проекта

**Текущий этап:** WebRTC модуль полностью готов и интегрирован ✅  
**Следующий этап:** Решение критических проблем WebRTC и авторизации 🚨

### **✅ Полностью работающие функции:**
- 🔐 **Аутентификация и регистрация** (JWT + invite codes)
- 👥 **Семейный чат** (автосоздание, real-time сообщения, история)
- 💬 **Личные чаты** (создание, поиск пользователей, 1-на-1 общение)
- ⚡ **Real-time сообщения** (Socket.IO, мгновенная доставка)
- 📱 **Улучшенный список чатов** (последние сообщения, время, непрочитанные)
- 🎨 **Полный брендинг "Звонилка"** (логотип, иконки, splash screen)
- 📞 **WebRTC UI** (экраны звонков, таймеры, кнопки управления)

### **🚨 Критические проблемы для решения:**
1. **WebRTC аудио** - пользователи не слышат друг друга
2. **JWT токены** - устаревают через несколько часов
3. **STUN/TURN серверы** - отсутствуют для NAT traversal

---

## 🚀 Быстрый Запуск для Тестирования
