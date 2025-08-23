# 📡 API Документация "Звонилка"

## 📖 Обзор API

Этот документ содержит полную документацию по REST API и WebSocket событиям семейного мессенджера "Звонилка". API построен на NestJS и использует JWT аутентификацию.

**Base URL:** `http://localhost:3000` (development) | `https://yourdomain.com` (production)

---

## 🔐 **Аутентификация**

Все защищенные endpoints требуют JWT токен в заголовке Authorization.

```http
Authorization: Bearer <jwt_token>
```

### **Получение токена:**
```http
POST /auth/login
Content-Type: application/json

{
  "username": "your_username",
  "password": "your_password"
}
```

---

## 🛡️ **HTTP API Endpoints**

### **1. 🔐 Аутентификация (`/auth`)**

#### **POST /auth/login**
Авторизация пользователя и получение JWT токена.

**Request:**
```http
POST /auth/login
Content-Type: application/json

{
  "username": "user1",
  "password": "password123"
}
```

**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "user1",
    "isAdmin": false
  }
}
```

**Errors:**
- `401 Unauthorized` - Неверные учетные данные
- `400 Bad Request` - Отсутствуют обязательные поля

---

### **2. 👤 Пользователи (`/users`)**

#### **POST /users/register**
Регистрация нового пользователя в семье.

**Request:**
```http
POST /users/register
Content-Type: application/json

{
  "username": "new_user",
  "password": "secure_password",
  "invitationCode": "secret_invite"
}
```

**Response (201 Created):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "username": "new_user",
  "isAdmin": false,
  "createdAt": "2025-08-20T10:30:00.000Z"
}
```

**Errors:**
- `400 Bad Request` - Некорректные данные или код приглашения
- `409 Conflict` - Username уже существует

---

#### **GET /users/profile** 🔒
Получение профиля текущего пользователя.

**Headers:**
```http
Authorization: Bearer <jwt_token>
```

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "user1",
  "isAdmin": false,
  "createdAt": "2025-08-15T14:20:00.000Z",
  "updatedAt": "2025-08-20T10:30:00.000Z"
}
```

---

#### **GET /users** 🔒
Получение списка всех пользователей, исключая текущего аутентифицированного.

**Headers:**
```http
Authorization: Bearer <jwt_token>
```

**Response (200 OK):**
```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440001",
    "username": "user2",
    "isAdmin": true,
    "createdAt": "2025-08-16T09:15:00.000Z",
    "updatedAt": "2025-08-20T08:45:00.000Z"
  },
  {
    "id": "550e8400-e29b-41d4-a716-446655440002",
    "username": "user3",
    "isAdmin": false,
    "createdAt": "2025-08-17T11:00:00.000Z",
    "updatedAt": "2025-08-17T11:00:00.000Z"
  }
]
```

---

#### **GET /users/:id** 🔒
Получение информации о конкретном пользователе.

**Parameters:**
- `id` (string, UUID) - ID пользователя

**Response (200 OK):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "username": "user2",
  "isAdmin": true,
  "createdAt": "2025-08-16T09:15:00.000Z",
  "updatedAt": "2025-08-20T08:45:00.000Z"
}
```

**Errors:**
- `404 Not Found` - Пользователь не найден

---

### **3. 💬 Чаты (`/chats`)**

#### **GET /chats** 🔒
Получение списка чатов текущего пользователя.

**Headers:**
```http
Authorization: Bearer <jwt_token>
```

**Response (200 OK):**
```json
[
  {
    "id": "282aacb0-1732-4c78-afbe-0bad9c0b0b31",
    "name": "Семейный Чат",
    "participants": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "username": "user1"
      },
      {
        "id": "550e8400-e29b-41d4-a716-446655440001", 
        "username": "user2"
      }
    ],
    "createdAt": "2025-08-16T14:36:53.716Z",
    "updatedAt": "2025-08-20T22:37:34.966Z"
  }
]
```

---

### **4. 📨 Сообщения (`/messages`)**

#### **GET /messages/:chatId** 🔒
Получение истории сообщений чата.

**Parameters:**
- `chatId` (string, UUID) - ID чата

**Query Parameters:**
- `limit` (number, optional) - Количество сообщений (по умолчанию: 50)
- `offset` (number, optional) - Смещение для пагинации (по умолчанию: 0)

**Headers:**
```http
Authorization: Bearer <jwt_token>
```

**Request:**
```http
GET /messages/282aacb0-1732-4c78-afbe-0bad9c0b0b31?limit=20&offset=0
```

**Response (200 OK):**
```json
[
  {
    "id": "c7825f2b-f65c-4688-9646-bb41146d9426",
    "content": "Привет всем!",
    "sender": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "username": "user1"
    },
    "senderId": "550e8400-e29b-41d4-a716-446655440000",
    "chat": {
      "id": "282aacb0-1732-4c78-afbe-0bad9c0b0b31",
      "name": "Семейный Чат"
    },
    "chatId": "282aacb0-1732-4c78-afbe-0bad9c0b0b31",
    "createdAt": "2025-08-20T22:40:25.235Z",
    "updatedAt": "2025-08-20T22:40:25.235Z"
  }
]
```

**Errors:**
- `404 Not Found` - Чат не найден
- `403 Forbidden` - Пользователь не является участником чата

---

#### **POST /chats/private** 🔒
Создание или поиск личного чата между текущим пользователем и указанным целевым пользователем.
Если чат уже существует, возвращается существующий чат.

**Request Body:**
```json
{
  "targetUserId": "a1b2c3d4-e5f6-7890-1234-567890abcdef"
}
```

**Headers:**
```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Response (201 Created / 200 OK):**
```json
{
  "id": "c5d6e7f8-1234-5678-90ab-cdef12345678",
  "name": "user1 & user2",
  "participants": [
    {
      "id": "user1-uuid",
      "username": "user1"
    },
    {
      "id": "user2-uuid",
      "username": "user2"
    }
  ],
  "createdAt": "2025-08-21T10:00:00.000Z",
  "updatedAt": "2025-08-21T10:00:00.000Z"
}
```

**Errors:**
- `400 Bad Request` - Некорректный ID пользователя или попытка создать чат с самим собой.
- `401 Unauthorized` - Не авторизован.
- `404 Not Found` - Целевой пользователь не найден.

---

### **5. 🎫 Пригласительные Коды (`/invitation-codes`)**

#### **POST /invitation-codes/generate** 🔒 👑
Создание нового пригласительного кода (только для администраторов).

**Headers:**
```http
Authorization: Bearer <jwt_token>
```

**Request:**
```http
POST /invitation-codes/generate
Content-Type: application/json

{
  "usageLimit": 5,
  "expiresAt": "2025-12-31T23:59:59.000Z"
}
```

**Response (201 Created):**
```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "code": "family_invite_2025",
  "isUsed": false,
  "usageLimit": 5,
  "usageCount": 0,
  "expiresAt": "2025-12-31T23:59:59.000Z",
  "createdAt": "2025-08-20T10:00:00.000Z"
}
```

---

#### **GET /invitation-codes** 🔒 👑
Получение списка всех пригласительных кодов (только для администраторов).

**Headers:**
```http
Authorization: Bearer <jwt_token>
```

**Response (200 OK):**
```json
[
  {
    "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "code": "secret_invite",
    "isUsed": false,
    "usageCount": 4,
    "createdAt": "2025-08-15T00:00:00.000Z"
  },
  {
    "id": "b2c3d4e5-f6g7-8901-bcde-f12345678901",
    "code": "family_invite_2025",
    "isUsed": false,
    "usageLimit": 5,
    "usageCount": 0,
    "expiresAt": "2025-12-31T23:59:59.000Z",
    "createdAt": "2025-08-20T10:00:00.000Z"
  }
]
```

---

## ⚡ **WebSocket API (Socket.IO)**

**Connection URL:** `ws://localhost:3000` (development) | `wss://yourdomain.com` (production)

### **Подключение к WebSocket**

```javascript
// Frontend (Flutter/JavaScript)
const socket = io('http://localhost:3000', {
  auth: {
    token: 'your_jwt_token_here'
  }
});
```

### **События Подключения**

#### **connect**
Успешное подключение к серверу.

```javascript
socket.on('connect', () => {
  console.log('Connected to server');
});
```

#### **disconnect**
Отключение от сервера.

```javascript
socket.on('disconnect', (reason) => {
  console.log('Disconnected:', reason);
});
```

#### **userConnected**
Уведомление о подключении пользователя.

```javascript
socket.on('userConnected', (userId) => {
  console.log('User connected:', userId);
});
```

#### **userDisconnected**
Уведомление об отключении пользователя.

```javascript
socket.on('userDisconnected', (userId) => {
  console.log('User disconnected:', userId);
});
```

---

### **События Чатов**

#### **📤 createChat**
Создание нового чата.

**Отправка:**
```javascript
socket.emit('createChat', {
  name: 'Новый чат',
  participantIds: [
    '550e8400-e29b-41d4-a716-446655440001',
    '550e8400-e29b-41d4-a716-446655440002'
  ]
});
```

**Ответ:**
```javascript
// Успех
{
  event: 'chatCreated',
  data: {
    id: '123e4567-e89b-12d3-a456-426614174000',
    name: 'Новый чат',
    participants: [...],
    createdAt: '2025-08-20T15:30:00.000Z'
  }
}

// Ошибка
{
  event: 'error',
  data: 'Error message'
}
```

#### **📤 getChats**
Получение списка чатов пользователя.

**Отправка:**
```javascript
socket.emit('getChats');
```

**Ответ:**
```javascript
socket.on('userChats', (chats) => {
  console.log('User chats:', chats);
});
```

---

### **События Сообщений**

#### **📤 sendMessage**
Отправка сообщения в чат.

**Отправка:**
```javascript
socket.emit('sendMessage', {
  chatId: '282aacb0-1732-4c78-afbe-0bad9c0b0b31',
  content: 'Привет всем!'
});
```

**Подтверждение отправки:**
```javascript
// Возвращается отправителю
{
  event: 'messageSent',
  data: {
    id: 'message-uuid',
    content: 'Привет всем!',
    sender: { ... },
    chat: { ... },
    createdAt: '2025-08-20T15:35:00.000Z'
  }
}
```

#### **📥 messageReceived**
Получение нового сообщения (real-time).

**Подписка:**
```javascript
socket.on('messageReceived', (message) => {
  console.log('New message:', message);
  // Добавить сообщение в UI
});
```

**Структура сообщения:**
```json
{
  "id": "c7825f2b-f65c-4688-9646-bb41146d9426",
  "content": "Привет всем!",
  "sender": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "username": "user1",
    "passwordHash": "$2b$10$...",
    "isAdmin": false,
    "invitationCode": "secret_invite",
    "createdAt": "2025-08-19T22:20:15.035Z",
    "updatedAt": "2025-08-19T22:20:15.035Z"
  },
  "senderId": "550e8400-e29b-41d4-a716-446655440000",
  "chat": {
    "id": "282aacb0-1732-4c78-afbe-0bad9c0b0b31",
    "name": "Семейный Чат",
    "createdAt": "2025-08-16T14:36:53.716Z",
    "updatedAt": "2025-08-16T14:36:53.716Z"
  },
  "chatId": "282aacb0-1732-4c78-afbe-0bad9c0b0b31",
  "createdAt": "2025-08-20T22:40:25.235Z",
  "updatedAt": "2025-08-20T22:40:25.235Z"
}
```

#### **📤 getMessages**
Получение истории сообщений чата через WebSocket.

**Отправка:**
```javascript
socket.emit('getMessages', {
  chatId: '282aacb0-1732-4c78-afbe-0bad9c0b0b31',
  limit: 50,
  offset: 0
});
```

**Ответ:**
```javascript
socket.on('chatMessages', (messages) => {
  console.log('Chat messages:', messages);
});
```

---

## 📋 **Планируемые API (Phase 2+)**

### **🔜 Голосовые Звонки (Phase 2)**

#### **POST /calls/initiate** 🔒
Инициация голосового звонка.

```http
POST /calls/initiate
{
  "targetUserId": "550e8400-e29b-41d4-a716-446655440001",
  "type": "voice"
}
```

#### **WebSocket Events:**
- `callInitiated` - Начало звонка
- `callAnswered` - Звонок принят
- `callEnded` - Звонок завершен
- `iceCandidate` - WebRTC ICE candidates
- `offer` / `answer` - WebRTC SDP

### **🔜 Файлы и Медиа (Phase 2)**

#### **POST /files/upload** 🔒
Загрузка файлов в чат.

```http
POST /files/upload
Content-Type: multipart/form-data

file: <binary_data>
chatId: 282aacb0-1732-4c78-afbe-0bad9c0b0b31
```

#### **GET /files/:fileId** 🔒
Скачивание файла.

### **🔜 Уведомления (Phase 2)**

#### **POST /notifications/register** 🔒
Регистрация устройства для push уведомлений.

```http
POST /notifications/register
{
  "fcmToken": "firebase_token_here",
  "platform": "android"
}
```

---

## 🎯 **Схемы Данных**

### **User Schema**
```typescript
interface User {
  id: string;           // UUID
  username: string;     // Уникальное имя пользователя
  passwordHash: string; // bcrypt хеш пароля
  isAdmin: boolean;     // Права администратора
  invitationCode: string; // Код, по которому регистрировался
  createdAt: Date;      // Дата создания
  updatedAt: Date;      // Дата последнего обновления
}
```

### **UserPublicDto Schema**
```typescript
interface UserPublicDto {
  id: string;           // UUID
  username: string;     // Уникальное имя пользователя
  isAdmin: boolean;     // Права администратора
  createdAt: Date;      // Дата создания
  updatedAt: Date;      // Дата последнего обновления
}
```

### **CreatePrivateChatDto Schema**
```typescript
interface CreatePrivateChatDto {
  targetUserId: string; // ID целевого пользователя для создания личного чата
}
```

### **Chat Schema**
```typescript
interface Chat {
  id: string;           // UUID
  name: string;         // Название чата
  isPrivate: boolean;   // Приватный ли чат (true для 1-на-1, false для групповых)
  participants: User[]; // Участники чата
  messages: Message[];  // Сообщения чата
  createdAt: Date;      // Дата создания
  updatedAt: Date;      // Дата последнего обновления
}
```

### **Message Schema**
```typescript
interface Message {
  id: string;           // UUID
  content: string;      // Текст сообщения
  sender: User;         // Отправитель
  senderId: string;     // ID отправителя
  chat: Chat;           // Чат
  chatId: string;       // ID чата
  createdAt: Date;      // Дата отправки
  updatedAt: Date;      // Дата последнего обновления
}
```

### **InvitationCode Schema**
```typescript
interface InvitationCode {
  id: string;           // UUID
  code: string;         // Уникальный код приглашения
  isUsed: boolean;      // Использован ли код
  usageLimit?: number;  // Лимит использований (опционально)
  usageCount: number;   // Количество использований
  usedByUserId?: string; // ID последнего пользователя
  usedAt?: Date;        // Дата последнего использования
  expiresAt?: Date;     // Дата истечения (опционально)
  createdAt: Date;      // Дата создания
  updatedAt: Date;      // Дата последнего обновления
}
```

---

## ⚠️ **Коды Ошибок**

### **HTTP Status Codes**
- `200 OK` - Успешный запрос
- `201 Created` - Ресурс создан
- `400 Bad Request` - Некорректные данные запроса
- `401 Unauthorized` - Требуется аутентификация
- `403 Forbidden` - Недостаточно прав
- `404 Not Found` - Ресурс не найден
- `409 Conflict` - Конфликт данных (например, username уже существует)
- `500 Internal Server Error` - Ошибка сервера

### **WebSocket Error Events**
```javascript
socket.on('error', (error) => {
  console.error('WebSocket error:', error);
});

// Примеры ошибок:
{
  event: 'error',
  data: 'Unauthorized'
}

{
  event: 'error', 
  data: 'Chat not found'
}
```

---

## 🔧 **Примеры Использования**

### **Полный Flow Регистрации и Отправки Сообщения**

```javascript
// 1. Регистрация
const registerResponse = await fetch('/users/register', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    username: 'new_user',
    password: 'secure_password',
    invitationCode: 'secret_invite'
  })
});

// 2. Авторизация
const loginResponse = await fetch('/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    username: 'new_user',
    password: 'secure_password'
  })
});

const { access_token } = await loginResponse.json();

// 3. Подключение к WebSocket
const socket = io('http://localhost:3000', {
  auth: { token: access_token }
});

// 4. Получение списка чатов
const chatsResponse = await fetch('/chats', {
  headers: { 'Authorization': `Bearer ${access_token}` }
});
const chats = await chatsResponse.json();

// 5. Подписка на новые сообщения
socket.on('messageReceived', (message) => {
  console.log('New message:', message.content);
});

// 6. Отправка сообщения
socket.emit('sendMessage', {
  chatId: chats[0].id,
  content: 'Привет, семья!'
});
```

---

## 🧪 **Тестирование API**

### **Postman Collection**
```json
{
  "info": {
    "name": "Звонилка API",
    "description": "API для тестирования семейного мессенджера"
  },
  "item": [
    {
      "name": "Auth Login",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"username\": \"{{username}}\",\n  \"password\": \"{{password}}\"\n}"
        },
        "url": {
          "raw": "{{base_url}}/auth/login",
          "host": ["{{base_url}}"],
          "path": ["auth", "login"]
        }
      }
    }
  ],
  "variable": [
    {
      "key": "base_url",
      "value": "http://localhost:3000"
    },
    {
      "key": "username",
      "value": "test_user"
    },
    {
      "key": "password", 
      "value": "test_password"
    }
  ]
}
```

### **cURL Examples**

```bash
# Авторизация
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "user1", "password": "password123"}'

# Получение профиля
curl -X GET http://localhost:3000/users/profile \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Получение чатов
curl -X GET http://localhost:3000/chats \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Получение сообщений
curl -X GET "http://localhost:3000/messages/CHAT_ID?limit=20" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## 🔄 **Changelog API**

### **Version 1.0.0 (Текущая)**
- ✅ Базовая аутентификация (login)
- ✅ Регистрация пользователей
- ✅ Управление чатами (получение списка)
- ✅ Сообщения (отправка, получение истории)
- ✅ WebSocket real-time сообщения
- ✅ Пригласительные коды (базовая функциональность)

### **Version 1.1.0 (В разработке)**
- ✅ Список пользователей (GET /users)
- ✅ Создание личных чатов
- [ ] Logout endpoint (POST /auth/logout) - планируется
- [ ] Управление профилем пользователя
- [ ] Расширенное управление пригласительными кодами

### **Version 2.0.0 (Phase 2)**
- [ ] Голосовые звонки (WebRTC)
- [ ] Загрузка файлов
- [ ] Push уведомления
- [ ] End-to-End шифрование
- [ ] Биометрическая аутентификация

---

**📅 Последнее обновление:** 22.08.2025  
**👨‍💻 Автор:** ИИ-Ассистент + Bessonniy  
**📡 Версия API:** 1.1.0  
**🎯 Статус:** Актуальная документация всех реализованных endpoints ✅ | Личные Чаты ✅

---

## 📎 **Дополнительные Ресурсы**

- **[Swagger UI](http://localhost:3000/api-docs)** - Интерактивная документация (планируется)
- **[Postman Collection](docs/assets/Inner_Circle_API.postman_collection.json)** - Готовая коллекция для тестирования
- **[WebSocket Test Client](docs/assets/websocket_test.html)** - HTML страница для тестирования WebSocket
