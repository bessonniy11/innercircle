# Детальная Структура Проекта "Inner Circle"

## 📁 Полная Структура Проекта

```
innercircle/
├── 📁 backend/                                    # NestJS Backend приложение
│   ├── 📁 src/                                   # Исходный код приложения
│   │   ├── 📁 auth/                             # Модуль аутентификации
│   │   │   ├── auth.controller.ts               # HTTP контроллер для аутентификации
│   │   │   ├── auth.service.ts                  # Сервис аутентификации (JWT)
│   │   │   ├── auth.module.ts                   # Модуль аутентификации
│   │   │   ├── 📁 dto/                         # Data Transfer Objects
│   │   │   │   └── login-user.dto.ts           # DTO для входа
│   │   │   └── 📁 strategies/                  # Passport стратегии
│   │   │       ├── local.strategy.ts           # Локальная стратегия
│   │   │       └── jwt.strategy.ts             # JWT стратегия
│   │   ├── 📁 users/                           # Модуль пользователей
│   │   │   ├── users.controller.ts             # HTTP контроллер пользователей
│   │   │   ├── users.service.ts                # Сервис управления пользователями
│   │   │   ├── users.module.ts                 # Модуль пользователей
│   │   │   ├── 📁 dto/                         # Data Transfer Objects
│   │   │   │   ├── create-user.dto.ts          # DTO для создания пользователя
│   │   │   │   └── update-user.dto.ts          # DTO для обновления пользователя
│   │   │   └── 📁 entities/                    # Сущности TypeORM
│   │   │       ├── user.entity.ts              # Сущность пользователя
│   │   │       └── invitation-code.entity.ts   # Сущность пригласительного кода
│   │   ├── 📁 chat/                            # Модуль чатов и сообщений
│   │   │   ├── chat.gateway.ts                 # Socket.IO gateway для real-time
│   │   │   ├── chat.service.ts                 # Сервис управления чатами
│   │   │   ├── chat.controller.ts              # HTTP контроллер чатов
│   │   │   ├── chat.module.ts                  # Модуль чатов
│   │   │   ├── 📁 dto/                         # Data Transfer Objects
│   │   │   │   ├── create-chat.dto.ts          # DTO для создания чата
│   │   │   │   └── send-message.dto.ts         # DTO для отправки сообщения
│   │   │   ├── 📁 entities/                    # Сущности TypeORM
│   │   │   │   ├── chat.entity.ts              # Сущность чата
│   │   │   │   └── message.entity.ts           # Сущность сообщения
│   │   │   └── 📁 message/                     # Подмодуль сообщений
│   │   │       ├── message.service.ts          # Сервис управления сообщениями
│   │   │       ├── message.controller.ts       # HTTP контроллер сообщений (НОВОЕ)
│   │   │       └── message.module.ts           # Модуль сообщений (НОВОЕ)
│   │   ├── 📁 invitation-codes/                # Модуль пригласительных кодов
│   │   │   ├── invitation-codes.controller.ts  # HTTP контроллер кодов
│   │   │   ├── invitation-codes.service.ts     # Сервис управления кодами (MVP: единый код 'secret_invite')
│   │   │   ├── invitation-codes.module.ts      # Модуль пригласительных кодов
│   │   │   └── 📁 dto/                         # Data Transfer Objects
│   │   │       └── create-invitation-code.dto.ts # DTO для создания кода
│   │   ├── app.controller.ts                   # Корневой контроллер
│   │   ├── app.service.ts                      # Корневой сервис
│   │   ├── app.module.ts                       # Корневой модуль приложения
│   │   └── main.ts                             # Точка входа приложения
│   ├── 📁 dist/                                # Скомпилированный код (автогенерируемый)
│   ├── 📁 node_modules/                        # Зависимости npm (автогенерируемый)
│   ├── .env                                    # Переменные окружения (НЕ в git)
│   ├── .gitignore                              # Файлы игнорируемые git
│   ├── package.json                            # Конфигурация npm и зависимости
│   ├── package-lock.json                       # Зафиксированные версии зависимостей
│   ├── tsconfig.json                           # Конфигурация TypeScript
│   ├── tsconfig.build.json                     # Конфигурация TypeScript для сборки
│   └── nest-cli.json                           # Конфигурация NestJS CLI
├── 📁 frontend/                                # Flutter Mobile приложение
│   ├── 📁 lib/                                 # Исходный код Flutter
│   │   ├── 📁 core/                           # Основные сервисы и утилиты
│   │   │   ├── 📁 api/                        # HTTP клиент
│   │   │   │   └── api_client.dart            # Dio клиент для API запросов
│   │   │   └── 📁 socket/                     # Socket.IO клиент
│   │   │       └── socket_client.dart         # Socket.IO клиент для real-time
│   │   ├── 📁 features/                       # Функциональные модули
│   │   │   ├── 📁 auth/                       # Модуль аутентификации
│   │   │   │   └── 📁 presentation/           # UI слой
│   │   │   │       └── 📁 screens/            # Экраны
│   │   │   │           ├── login_screen.dart  # Экран входа
│   │   │   │           └── registration_screen.dart # Экран регистрации
│   │   │   └── 📁 chat/                       # Модуль чатов
│   │   │       ├── 📁 domain/                 # Доменный слой
│   │   │       │   └── 📁 models/             # Модели данных
│   │   │       │       └── message_model.dart # Модель сообщения
│   │   │       └── 📁 presentation/           # UI слой
│   │   │           └── 📁 screens/            # Экраны
│   │   │               ├── chat_list_screen.dart # Экран списка чатов
│   │   │               └── message_screen.dart   # Экран сообщений
│   │   └── main.dart                          # Точка входа Flutter приложения
│   ├── 📁 android/                            # Android специфичный код
│   ├── 📁 ios/                                # iOS специфичный код
│   ├── 📁 assets/                             # Ресурсы приложения
│   │   ├── 📁 images/                         # Изображения
│   │   ├── 📁 icons/                          # Иконки
│   │   └── 📁 fonts/                          # Шрифты
│   ├── 📁 test/                               # Тесты
│   ├── pubspec.yaml                           # Конфигурация Flutter и зависимости
│   ├── pubspec.lock                           # Зафиксированные версии зависимостей
│   ├── analysis_options.yaml                  # Правила анализа кода Dart
│   └── README.md                              # Подробное руководство по Flutter приложению
├── 📁 docs/                                   # Документация проекта
│   ├── 📁 project_documentation/              # Техническая документация
│   │   ├── structure.md                       # Этот файл - структура проекта
│   │   ├── api_documentation.md               # API документация (планируется)
│   │   ├── database_schema.md                 # Схема базы данных (планируется)
│   │   └── deployment_guide.md                # Руководство по развертыванию (планируется)
│   ├── tasks.md                               # Задачи и прогресс разработки
│   ├── technology_stack.md                    # Технологический стек и обоснования
│   ├── testing_guide.md                       # Руководство по тестированию (НОВОЕ)
│   └── 📁 assets/                             # Ресурсы документации
│       ├── 📁 images/                         # Диаграммы и схемы
│       └── 📁 screenshots/                    # Скриншоты приложения
├── .gitignore                                 # Глобальные правила игнорирования git
├── README.md                                  # Главная документация проекта
└── 📁 scripts/                                # Скрипты для автоматизации (планируется)
    ├── deploy.sh                              # Скрипт развертывания (планируется)
    ├── backup_db.sh                           # Скрипт резервного копирования БД (планируется)
    └── setup_env.sh                           # Скрипт настройки окружения (планируется)
```

## 📊 База Данных - Структура Таблиц

### **Существующие Таблицы**

#### 1. **users** - Пользователи системы
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR UNIQUE NOT NULL,
    "passwordHash" VARCHAR NOT NULL,
    "isAdmin" BOOLEAN DEFAULT false,
    "invitationCode" VARCHAR,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 2. **invitation_codes** - Пригласительные коды
```sql
CREATE TABLE invitation_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR UNIQUE NOT NULL,
    "isUsed" BOOLEAN DEFAULT false,
    "usedByUserId" UUID REFERENCES users(id),
    "usedAt" TIMESTAMP,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 3. **chats** - Чаты (общие и личные)
```sql
CREATE TABLE chats (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR NOT NULL,
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 4. **messages** - Сообщения в чатах
```sql
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content TEXT NOT NULL,
    "senderId" UUID NOT NULL REFERENCES users(id),
    "chatId" UUID NOT NULL REFERENCES chats(id),
    "createdAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### 5. **chat_participants** - Участники чатов (Many-to-Many)
```sql
CREATE TABLE chat_participants (
    "chatId" UUID REFERENCES chats(id) ON DELETE CASCADE,
    "userId" UUID REFERENCES users(id) ON DELETE CASCADE,
    PRIMARY KEY ("chatId", "userId")
);
```

## 🔗 Связи между Компонентами

### **Backend Архитектура**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Controllers   │◄──►│    Services     │◄──►│   Repositories  │
│                 │    │                 │    │                 │
│ - HTTP Routes   │    │ - Business      │    │ - Database      │
│ - Validation    │    │   Logic         │    │   Operations    │
│ - Response      │    │ - Data Trans.   │    │ - TypeORM       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   DTOs          │    │   Entities      │    │   PostgreSQL    │
│                 │    │                 │    │                 │
│ - Request       │    │ - Database      │    │ - Tables        │
│ - Response      │    │   Models        │    │ - Constraints   │
│ - Validation    │    │ - Relations     │    │ - Indexes       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **Frontend Архитектура**

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│     Screens     │◄──►│     Models      │◄──►│     Services    │
│                 │    │                 │    │                 │
│ - UI Widgets    │    │ - Data Models   │    │ - API Client    │
│ - User Input    │    │ - Serialization │    │ - Socket Client │
│ - Navigation    │    │ - Validation    │    │ - HTTP Requests │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 📋 Конвенции Именования

### **Backend (TypeScript/NestJS)**
- **Файлы:** `kebab-case.type.ts` (например: `user.entity.ts`, `create-user.dto.ts`)
- **Классы:** `PascalCase` (например: `UserService`, `CreateUserDto`)
- **Методы:** `camelCase` (например: `findUserById`, `createNewChat`)
- **Переменные:** `camelCase` (например: `userId`, `chatMessages`)
- **Константы:** `UPPER_SNAKE_CASE` (например: `JWT_SECRET`, `MAX_MESSAGE_LENGTH`)

### **Frontend (Dart/Flutter)**
- **Файлы:** `snake_case.dart` (например: `user_model.dart`, `chat_list_screen.dart`)
- **Классы:** `PascalCase` (например: `UserModel`, `ChatListScreen`)
- **Методы:** `camelCase` (например: `getUserProfile`, `sendMessage`)
- **Переменные:** `camelCase` (например: `userId`, `messageContent`)
- **Константы:** `lowerCamelCase` (например: `apiBaseUrl`, `maxRetryAttempts`)

### **База Данных (PostgreSQL)**
- **Таблицы:** `snake_case` (например: `users`, `chat_participants`)
- **Колонки:** `camelCase` в кавычках (например: `"userId"`, `"createdAt"`)
- **Индексы:** `idx_table_column` (например: `idx_users_username`)

## 🛡 Безопасность и Валидация

### **Backend Валидация**
- **class-validator:** Декораторы для валидации DTO
- **class-transformer:** Преобразование данных
- **ValidationPipe:** Глобальная валидация всех входящих запросов
- **Guards:** Проверка аутентификации и авторизации

### **Frontend Валидация**
- **Form Validation:** Проверка форм на стороне клиента
- **Input Sanitization:** Очистка пользовательского ввода
- **Error Handling:** Обработка ошибок сети и сервера

### **База Данных**
- **Constraints:** Ограничения целостности данных
- **Indexes:** Индексы для производительности
- **Relations:** Внешние ключи для связей

## 📦 Зависимости

### **Backend Dependencies**
```json
{
  "dependencies": {
    "@nestjs/common": "^10.0.0",
    "@nestjs/core": "^10.0.0",
    "@nestjs/platform-express": "^10.0.0",
    "@nestjs/platform-socket.io": "^10.0.0",
    "@nestjs/typeorm": "^10.0.0",
    "@nestjs/jwt": "^10.0.0",
    "@nestjs/passport": "^10.0.0",
    "@nestjs/config": "^10.0.0",
    "typeorm": "^0.3.0",
    "pg": "^8.8.0",
    "bcryptjs": "^2.4.3",
    "passport": "^0.6.0",
    "passport-local": "^1.0.0",
    "passport-jwt": "^4.0.0",
    "class-validator": "^0.14.0",
    "class-transformer": "^0.5.0",
    "socket.io": "^4.6.0",
    "uuid": "^9.0.0"
  }
}
```

### **Frontend Dependencies**
```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0                    # HTTP client
  socket_io_client: ^3.1.2       # Socket.IO client
  provider: ^6.0.0               # State management (планируется)
  shared_preferences: ^2.0.0     # Local storage (планируется)
  permission_handler: ^11.0.0    # Permissions (планируется)
```

## 🔄 Жизненный Цикл Разработки

### **Правила Обновления Структуры**
1. **При создании новых файлов:** Обязательно обновить этот файл
2. **При изменении архитектуры:** Обновить диаграммы и описания
3. **При добавлении зависимостей:** Обновить списки зависимостей
4. **При изменении БД:** Обновить схему таблиц

### **Процесс Добавления Новой Функции**
1. **Планирование:** Описание в `docs/tasks.md`
2. **Backend:** Создание сущностей, сервисов, контроллеров
3. **Frontend:** Создание моделей, экранов, сервисов
4. **Тестирование:** Проверка функциональности
5. **Документирование:** Обновление всей документации
6. **Обновление структуры:** Актуализация этого файла

---

**Последнее обновление:** 16.08.2025  
**Статус:** Авторизация работает ✅ | Чаты в разработке 🔄  
**Версия структуры:** 2.1

## 🔑 **MVP Логика Пригласительных Кодов**

### **Текущая Реализация (Временная) - Протестировано ✅**
- **Единый код:** `secret_invite` для всех пользователей
- **Многократное использование:** Код можно использовать неограниченно
- **Автоматическое создание:** Backend автоматически создает запись `secret_invite` если её нет
- **Статистика:** Отслеживается последний пользователь и дата использования

### **Установка в БД:**
```sql
-- Автоматически создается при первом запуске backend
-- Или можно добавить вручную:
INSERT INTO invitation_codes (code, "isUsed") VALUES ('secret_invite', false);
```

### **Будущие Улучшения:**
- Множественные одноразовые коды
- Ограничение по времени действия
- Разные типы кодов (admin, user, temporary)
- Web-интерфейс для управления кодами

### **JSDoc Документация:**
- Все backend Services, Controllers, Entities полностью документированы
- Использование специальных маркеров: "MVP:", "В будущих версиях:", "ВРЕМЕННОЕ УПРОЩЕНИЕ"
- Обязательные теги: @param, @returns, @throws, @example, @since, @author

