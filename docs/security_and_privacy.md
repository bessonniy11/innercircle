# 🛡️ Безопасность и Конфиденциальность "Звонилка"

## 📖 Обзор Документа

Этот документ содержит детальные требования к безопасности, конфиденциальности и защите данных для семейного мессенджера "Звонилка". Безопасность семейных данных - наш главный приоритет.

---

## 🎯 **Принципы Безопасности**

### **Основные Принципы:**
1. **🔒 Privacy by Design** - конфиденциальность с самого начала
2. **🔐 End-to-End Encryption** - сквозное шифрование всех данных
3. **🛡️ Zero Trust Architecture** - не доверяем никому по умолчанию
4. **👨‍👩‍👧‍👦 Family Data Protection** - особая защита семейных данных
5. **🇷🇺 Compliance** - соответствие российскому законодательству

### **Уровни Защиты:**
```
┌─────────────────────────────────────┐
│           ФИЗИЧЕСКИЙ УРОВЕНЬ        │ ← Сервер, сеть, устройства
├─────────────────────────────────────┤
│           СЕТЕВОЙ УРОВЕНЬ           │ ← TLS, VPN, firewall
├─────────────────────────────────────┤
│         УРОВЕНЬ ПРИЛОЖЕНИЯ          │ ← Authentication, authorization
├─────────────────────────────────────┤
│           УРОВЕНЬ ДАННЫХ            │ ← Encryption, hashing, signing
├─────────────────────────────────────┤
│        ПОЛЬЗОВАТЕЛЬСКИЙ УРОВЕНЬ      │ ← UI/UX security, education
└─────────────────────────────────────┘
```

---

## 🔐 **Шифрование Данных**

### **1. Шифрование Сообщений (End-to-End)**

#### **Текущее Состояние:** ❌ НЕ РЕАЛИЗОВАНО (MVP упрощение)
#### **Планируемая Реализация (Phase 2):**

```typescript
// Архитектура E2E шифрования
interface MessageEncryption {
  algorithm: 'AES-256-GCM';
  keyExchange: 'ECDH-P256';
  signing: 'ECDSA-P256';
  keyRotation: '7 days';
}

// Процесс отправки сообщения
1. Генерация эфемерного ключа для каждого сообщения
2. Шифрование контента AES-256-GCM
3. Подпись сообщения ECDSA
4. Обмен ключами через ECDH
5. Отправка зашифрованного payload
```

#### **Требования к Реализации:**
- ✅ **Библиотека шифрования:** `crypto-js` (frontend), `crypto` (backend)
- ✅ **Алгоритм:** AES-256-GCM для симметричного шифрования
- ✅ **Обмен ключами:** ECDH (Elliptic Curve Diffie-Hellman)
- ✅ **Цифровые подписи:** ECDSA для подтверждения подлинности
- ✅ **Ротация ключей:** Каждые 7 дней автоматически

#### **База Данных (Зашифрованное Хранение):**
```sql
-- Таблица зашифрованных сообщений
CREATE TABLE encrypted_messages (
    id UUID PRIMARY KEY,
    chat_id UUID NOT NULL,
    sender_id UUID NOT NULL,
    encrypted_content BYTEA NOT NULL,  -- AES-256-GCM encrypted
    content_iv BYTEA NOT NULL,         -- Initialization Vector
    content_tag BYTEA NOT NULL,        -- Authentication Tag
    key_fingerprint VARCHAR(64),       -- SHA-256 hash of key
    signature BYTEA NOT NULL,          -- ECDSA signature
    created_at TIMESTAMP DEFAULT NOW()
);
```

### **2. Шифрование Голосовых/Видео Звонков**

#### **Текущее Состояние:** ❌ НЕ РЕАЛИЗОВАНО (Phase 2)
#### **Планируемая Реализация:**

```typescript
// WebRTC DTLS-SRTP шифрование
interface CallEncryption {
  transport: 'DTLS-SRTP';
  cipher: 'AES-128-GCM';
  keyExchange: 'ECDHE-RSA';
  certificate: 'Self-signed + fingerprint verification';
}

// Дополнительный слой E2E для звонков
interface VoiceE2E {
  algorithm: 'AES-256-CTR';
  keyDerivation: 'HKDF-SHA256';
  authentication: 'HMAC-SHA256';
  keyRotation: 'Every 30 seconds';
}
```

#### **Защита Audio/Video Потоков:**
- ✅ **DTLS-SRTP:** Встроенное шифрование WebRTC
- ✅ **Perfect Forward Secrecy:** Новые ключи для каждого звонка
- ✅ **Дополнительное E2E:** Поверх SRTP для максимальной защиты
- ✅ **Fingerprint Verification:** Проверка сертификатов участников

### **3. Шифрование Файлов и Медиа**

#### **Планируемая Реализация (Phase 3):**
```typescript
// Шифрование файлов перед загрузкой
interface FileEncryption {
  algorithm: 'AES-256-CBC';
  keyDerivation: 'PBKDF2-SHA256';
  iterations: 100000;
  saltLength: 32;
  chunkSize: 4096; // Для больших файлов
}
```

---

## 🔑 **Управление Ключами**

### **1. Архитектура Ключей**

```typescript
interface KeyManagement {
  // Ключи пользователя
  userKeyPair: {
    private: 'ECDSA-P256 (device-only)';
    public: 'Stored on server';
  };
  
  // Ключи чатов
  chatKeys: {
    symmetric: 'AES-256 (rotated weekly)';
    distribution: 'Via encrypted channels';
  };
  
  // Ключи устройств
  deviceKeys: {
    storage: 'Secure Enclave / Keychain';
    backup: 'User-controlled only';
  };
}
```

### **2. Генерация и Хранение Ключей**

#### **На Устройстве (Flutter):**
```dart
// Безопасное хранение ключей
class SecureKeyStorage {
  // iOS: Keychain Services
  // Android: Android Keystore System
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: IOSAccessibility.first_unlock_this_device,
    ),
  );
}
```

#### **На Сервере (Backend):**
```typescript
// Хранение только публичных ключей
interface ServerKeyStorage {
  userPublicKeys: 'Доступны всем участникам семьи';
  chatMetadata: 'Зашифрованные метаданные';
  privateKeys: 'НИКОГДА не хранятся на сервере';
}
```

---

## 🛡️ **Защита от Уязвимостей**

### **1. SQL Injection Prevention**

#### **Текущее Состояние:** ✅ ЗАЩИЩЕНО (TypeORM)
#### **Реализованные Меры:**

```typescript
// TypeORM автоматически защищает от SQL инъекций
@Injectable()
export class MessageService {
  async getMessagesForChat(chatId: string): Promise<Message[]> {
    // ✅ Безопасно - TypeORM использует параметризованные запросы
    return this.messageRepository.find({
      where: { chatId }, // Автоматически экранируется
      relations: ['sender', 'chat'],
    });
  }
  
  // ❌ ОПАСНО - прямой SQL (НЕ используется)
  // await this.repository.query(`SELECT * FROM messages WHERE chatId = '${chatId}'`);
}
```

#### **Дополнительные Меры:**
```typescript
// Валидация всех входящих данных
import { IsUUID, IsString, IsNotEmpty, MaxLength } from 'class-validator';

export class SendMessageDto {
  @IsUUID(4)
  chatId: string;

  @IsString()
  @IsNotEmpty()
  @MaxLength(4096) // Ограничение длины сообщения
  content: string;
}
```

### **2. XSS (Cross-Site Scripting) Prevention**

#### **Frontend (Flutter) - Защищено по умолчанию:**
```dart
// Flutter автоматически экранирует все Text виджеты
Text(message.content) // ✅ Безопасно - нет HTML рендеринга
```

#### **Backend (NestJS) - Дополнительная защита:**
```typescript
import { Transform } from 'class-transformer';
import * as xss from 'xss';

export class CreateMessageDto {
  @Transform(({ value }) => xss(value)) // Очистка от XSS
  @IsString()
  content: string;
}
```

### **3. CSRF (Cross-Site Request Forgery) Prevention**

```typescript
// JWT токены в заголовках (не в cookies)
@UseGuards(AuthGuard('jwt'))
export class ChatController {
  // ✅ CSRF невозможен - токен в Authorization header
}

// Дополнительная защита CORS
app.enableCors({
  origin: ['https://yourdomain.com'], // Только доверенные домены
  credentials: false, // Не используем cookies
});
```

### **4. NoSQL Injection Prevention**

#### **Не применимо:** Используется PostgreSQL (реляционная БД)
#### **Но для будущих NoSQL интеграций:**
```typescript
// Валидация типов данных
interface SafeQuery {
  chatId: string; // Только строки, никаких объектов
  limit: number;  // Только числа
}
```

### **5. Path Traversal Prevention**

```typescript
// Безопасная работа с файлами (будущее)
import * as path from 'path';

function sanitizeFilename(filename: string): string {
  // Удаление опасных символов
  return path.basename(filename).replace(/[^a-zA-Z0-9.-]/g, '_');
}
```

### **6. Rate Limiting & DDoS Protection**

```typescript
// Ограничение частоты запросов
import { ThrottlerModule } from '@nestjs/throttler';

@Module({
  imports: [
    ThrottlerModule.forRoot({
      ttl: 60, // 60 секунд
      limit: 100, // Максимум 100 запросов в минуту
    }),
  ],
})
export class AppModule {}

// Специальные лимиты для сообщений
@UseGuards(ThrottlerGuard)
@Throttle(20, 60) // 20 сообщений в минуту
export class MessageController {}
```

---

## 🔐 **Аутентификация и Авторизация**

### **1. Многофакторная Аутентификация (Планируется)**

```typescript
interface MFAOptions {
  primary: 'Username + Password';
  secondary: 'TOTP (Google Authenticator)' | 'SMS' | 'Biometric';
  backup: 'Recovery codes (one-time use)';
}

// Биометрическая аутентификация (Flutter)
class BiometricAuth {
  static Future<bool> authenticate() async {
    final LocalAuthentication auth = LocalAuthentication();
    return await auth.authenticate(
      localizedReason: 'Подтвердите вход в семейный чат',
      options: AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
  }
}
```

### **2. Session Management**

```typescript
// Безопасное управление сессиями
interface SessionSecurity {
  jwtExpiry: '1 hour';
  refreshToken: '30 days (httpOnly, secure)';
  sessionRotation: 'На каждом refresh';
  concurrentSessions: 'Максимум 3 устройства';
}

// Автоматический logout при подозрительной активности
class SecurityMonitoring {
  detectAnomalies(user: User, request: Request): boolean {
    // Проверка IP, User-Agent, частоты запросов
    // Автоматический logout при обнаружении аномалий
  }
}
```

### **3. Device Management**

```dart
// Управление доверенными устройствами
class DeviceManagement {
  static void registerDevice() {
    final deviceInfo = {
      'deviceId': await _getDeviceId(),
      'deviceName': await _getDeviceName(),
      'platform': Platform.operatingSystem,
      'appVersion': await _getAppVersion(),
      'registeredAt': DateTime.now().toIso8601String(),
    };
    // Отправка на сервер для регистрации
  }
}
```

---

## 📱 **Безопасность на Устройстве**

### **1. Локальное Хранение Данных**

```dart
// Шифрование локальных данных
class SecureLocalStorage {
  // Использование flutter_secure_storage
  static const _storage = FlutterSecureStorage();
  
  // Шифрование базы данных SQLite
  static Database? _database;
  
  static Future<Database> get database async {
    _database ??= await openDatabase(
      'encrypted_messages.db',
      version: 1,
      password: await _getDatabasePassword(), // Шифрование БД
    );
    return _database!;
  }
}
```

### **2. Memory Protection**

```dart
// Защита от дампов памяти
class MemoryProtection {
  static void clearSensitiveData() {
    // Очистка переменных с чувствительными данными
    // Принудительная сборка мусора
    // Обнуление буферов
  }
  
  static void enableAntiDebugging() {
    // Защита от отладчиков (Release mode)
    assert(false, 'Debugging not allowed in release');
  }
}
```

### **3. Screen Recording Protection**

```dart
// Защита от скриншотов/записи экрана
class ScreenProtection {
  static void enableScreenProtection() {
    // Android: FLAG_SECURE
    // iOS: UITextField.isSecureTextEntry для чувствительных полей
  }
  
  static void blurScreenInBackground() {
    // Размытие экрана при сворачивании приложения
  }
}
```

---

## 🌐 **Сетевая Безопасность**

### **1. TLS/SSL Configuration**

```typescript
// Принудительное использование HTTPS
interface TLSConfig {
  version: 'TLS 1.3';
  cipherSuites: [
    'TLS_AES_256_GCM_SHA384',
    'TLS_CHACHA20_POLY1305_SHA256',
    'TLS_AES_128_GCM_SHA256'
  ];
  certificatePinning: true;
  hsts: 'max-age=31536000; includeSubDomains';
}
```

### **2. Certificate Pinning**

```dart
// Закрепление сертификатов (Flutter)
class CertificatePinning {
  static Dio createSecureClient() {
    final dio = Dio();
    
    // Добавление interceptor для проверки сертификатов
    dio.interceptors.add(CertificatePinningInterceptor(
      allowedSHAFingerprints: ['YOUR_CERT_SHA256_FINGERPRINT'],
    ));
    
    return dio;
  }
}
```

### **3. WebSocket Security**

```typescript
// Безопасные WebSocket соединения
interface WebSocketSecurity {
  protocol: 'WSS (WebSocket Secure)';
  authentication: 'JWT in handshake';
  encryption: 'TLS 1.3';
  heartbeat: 'Каждые 30 секунд';
  connectionLimits: 'Максимум 1 соединение на пользователя';
}
```

---

## 🔍 **Мониторинг и Аудит Безопасности**

### **1. Security Logging**

```typescript
// Логирование событий безопасности
interface SecurityEvent {
  timestamp: Date;
  userId?: string;
  eventType: 'LOGIN' | 'LOGOUT' | 'FAILED_AUTH' | 'MESSAGE_SENT' | 'SUSPICIOUS_ACTIVITY';
  ipAddress: string;
  userAgent: string;
  details: Record<string, any>;
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL';
}

@Injectable()
export class SecurityLogger {
  logEvent(event: SecurityEvent) {
    // Отправка в защищенную систему логирования
    // НЕ логируем содержимое сообщений (конфиденциальность)
  }
}
```

### **2. Anomaly Detection**

```typescript
// Обнаружение аномальной активности
class SecurityMonitoring {
  detectSuspiciousActivity(user: User): boolean {
    // Множественные неудачные попытки входа
    // Необычные геолокации
    // Аномальные паттерны использования
    // Подозрительные WebSocket соединения
  }
}
```

### **3. Incident Response**

```typescript
// Автоматическое реагирование на инциденты
class IncidentResponse {
  handleSecurityIncident(incident: SecurityIncident) {
    switch (incident.severity) {
      case 'CRITICAL':
        // Блокировка аккаунта
        // Отзыв всех токенов
        // Уведомление администраторов
        break;
      case 'HIGH':
        // Требование повторной аутентификации
        // Дополнительные проверки
        break;
    }
  }
}
```

---

## 👨‍👩‍👧‍👦 **Особенности Безопасности для Семьи**

### **1. Parental Controls**

```typescript
// Контроль времени использования
interface ParentalControls {
  timeRestrictions: {
    dailyLimit: number; // Минуты в день
    quietHours: { start: string; end: string }; // "22:00" - "07:00"
    weekendRules: boolean;
  };
  
  contentFiltering: {
    allowedFileTypes: string[];
    maxFileSize: number;
    scanForMalware: boolean;
  };
  
  communicationLimits: {
    maxMessagesPerHour: number;
    allowDirectMessages: boolean;
    moderateUploads: boolean;
  };
}
```

### **2. Family Privacy Settings**

```typescript
// Настройки конфиденциальности семьи
interface FamilyPrivacy {
  messageRetention: '1 year' | '6 months' | '3 months' | 'forever';
  locationSharing: 'none' | 'family_only' | 'emergency_only';
  onlineStatusVisible: boolean;
  lastSeenVisible: boolean;
  readReceiptsEnabled: boolean;
}
```

### **3. Emergency Features**

```typescript
// Экстренные функции безопасности
interface EmergencyFeatures {
  panicButton: {
    enabled: boolean;
    action: 'send_location' | 'call_emergency' | 'notify_family';
  };
  
  emergencyContacts: {
    localEmergency: '112'; // Россия
    familyEmergency: string[];
  };
  
  dataWipe: {
    remoteWipe: boolean; // Удаленная очистка устройства
    autoWipeOnFailedAttempts: number; // 10 неудачных попыток
  };
}
```

---

## 🇷🇺 **Соответствие Российскому Законодательству**

### **1. Федеральный Закон №152-ФЗ "О персональных данных"**

```typescript
// Обработка персональных данных
interface PersonalDataCompliance {
  dataTypes: {
    identification: 'Username, IP-адрес';
    communication: 'Метаданные сообщений (НЕ содержимое)';
    technical: 'Логи безопасности, статистика';
  };
  
  processing: {
    purpose: 'Обеспечение работы семейного мессенджера';
    legalBasis: 'Согласие пользователя';
    retention: 'Не более необходимого срока';
    crossBorder: 'Данные НЕ передаются за пределы РФ';
  };
  
  rights: {
    access: 'Просмотр своих данных';
    rectification: 'Исправление данных';
    erasure: 'Удаление данных';
    portability: 'Экспорт данных';
  };
}
```

### **2. Закон Яровой (Антитеррористический пакет)**

```typescript
// Хранение метаданных (НЕ содержимого)
interface YarovayaCompliance {
  metadataStorage: {
    what: 'IP, время, участники (НЕ содержимое сообщений)';
    duration: '6 месяцев';
    access: 'Только по официальному запросу';
  };
  
  contentStorage: {
    encrypted: true;
    serverLocation: 'Только на территории РФ';
    keyManagement: 'Пользователи контролируют свои ключи';
  };
}
```

### **3. Федеральный Закон №436-ФЗ "О защите детей"**

```typescript
// Защита детей от вредной информации
interface ChildProtection {
  ageVerification: {
    required: true;
    method: 'Parental confirmation during registration';
  };
  
  contentModeration: {
    automaticScanning: 'Text analysis for harmful content';
    reportingMechanism: 'Easy reporting for parents';
    responseTime: '2 hours maximum';
  };
  
  parentalControls: {
    mandatory: true;
    features: ['time_limits', 'content_filtering', 'activity_monitoring'];
  };
}
```

---

## 📋 **План Внедрения Безопасности**

### **Phase 1 (MVP - Базовая Безопасность):**
- ✅ **HTTPS/TLS** - Шифрование транспорта
- ✅ **JWT Authentication** - Безопасная аутентификация
- ✅ **SQL Injection Protection** - TypeORM параметризованные запросы
- ✅ **Rate Limiting** - Защита от спама/DDoS
- ✅ **Input Validation** - class-validator
- [ ] **CORS Configuration** - Настройка безопасных источников

### **Phase 2 (Enhanced Security):**
- [ ] **End-to-End Encryption** - Сквозное шифрование сообщений
- [ ] **Certificate Pinning** - Закрепление сертификатов
- [ ] **Biometric Authentication** - Отпечатки/Face ID
- [ ] **Secure Local Storage** - Шифрование локальных данных
- [ ] **Device Management** - Управление доверенными устройствами
- [ ] **Security Monitoring** - Мониторинг аномалий

### **Phase 3 (Advanced Security):**
- [ ] **Voice/Video E2E** - Шифрование звонков
- [ ] **File Encryption** - Шифрование файлов
- [ ] **Perfect Forward Secrecy** - Продвинутое управление ключами
- [ ] **Hardware Security Module** - Аппаратная защита ключей
- [ ] **Zero-Knowledge Architecture** - Сервер не знает содержимое
- [ ] **Formal Security Audit** - Профессиональный аудит безопасности

---

## 🔧 **Рекомендации по Реализации**

### **1. Библиотеки и Инструменты:**

#### **Backend (NestJS):**
```json
{
  "crypto": "^1.0.1",           // Встроенное шифрование Node.js
  "bcryptjs": "^2.4.3",        // Хеширование паролей ✅
  "@nestjs/throttler": "^5.0.0", // Rate limiting ✅
  "helmet": "^7.0.0",          // Security headers
  "express-rate-limit": "^6.8.0", // Дополнительное ограничение
  "xss": "^1.0.14",           // XSS protection
  "validator": "^13.9.0"       // Дополнительная валидация
}
```

#### **Frontend (Flutter):**
```yaml
dependencies:
  flutter_secure_storage: ^9.0.0  # Безопасное хранение
  local_auth: ^2.1.6             # Биометрическая аутентификация
  crypto: ^3.0.3                 # Шифрование
  pointycastle: ^3.7.3           # Криптографические алгоритмы
  certificate_pinning: ^3.0.0    # Закрепление сертификатов
  device_info_plus: ^9.1.0       # Информация об устройстве
```

### **2. Конфигурация Development vs Production:**

```typescript
// Development (упрощенная безопасность для тестирования)
const devSecurity = {
  encryption: false,        // Отключено для отладки
  certificatePinning: false,
  biometric: false,
  logging: 'verbose',
};

// Production (полная безопасность)
const prodSecurity = {
  encryption: true,         // Включено ОБЯЗАТЕЛЬНО
  certificatePinning: true,
  biometric: true,
  logging: 'security-only',
};
```

### **3. Security Checklist перед Production:**

- [ ] **Все API endpoints** защищены аутентификацией
- [ ] **Rate limiting** настроен для всех endpoints
- [ ] **HTTPS** принудительно для всех соединений
- [ ] **Certificate pinning** активен в мобильном приложении
- [ ] **Secure headers** настроены (HSTS, CSP, X-Frame-Options)
- [ ] **Environment variables** не содержат секретов в коде
- [ ] **Error messages** не раскрывают системную информацию
- [ ] **Database** настроена с минимальными правами
- [ ] **Logs** не содержат чувствительной информации
- [ ] **Security testing** проведено (penetration testing)

---

## 🚨 **Критические Предупреждения**

### **⚠️ НЕ ДЕЛАТЬ НИКОГДА:**
1. **Хранить пароли в открытом виде** - только хеши ✅
2. **Логировать содержимое сообщений** - нарушение конфиденциальности
3. **Передавать секреты в URL параметрах** - только в заголовках/теле
4. **Использовать слабые алгоритмы** - MD5, SHA1, DES запрещены
5. **Хранить ключи шифрования на сервере** - только на устройствах
6. **Игнорировать обновления безопасности** - обновлять немедленно
7. **Использовать HTTP для чувствительных данных** - только HTTPS

### **🛡️ ОБЯЗАТЕЛЬНО ДЕЛАТЬ:**
1. **Регулярные обновления** всех зависимостей
2. **Мониторинг CVE** для используемых библиотек
3. **Backups зашифрованных данных** с ротацией ключей
4. **Incident response plan** для нарушений безопасности
5. **Security training** для всех разработчиков
6. **Penetration testing** перед каждым major release
7. **Compliance audits** соответствия российскому законодательству

---

**📅 Последнее обновление:** 20.08.2025  
**👨‍💻 Автор:** ИИ-Ассистент + Bessonniy  
**🛡️ Версия документа безопасности:** 1.0  
**🎯 Статус:** Требования определены, готов к поэтапной реализации ✅  
**⚠️ Важность:** КРИТИЧЕСКИ ВАЖНО для Production запуска
