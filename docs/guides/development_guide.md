# 🚀 Руководство по разработке и управлению "Звонилка"

Этот документ — ваш главный помощник в разработке, тестировании, сборке и управлении приложением "Звонилка". Здесь собраны все необходимые команды и инструкции.

---

## 🛠️ Настройка локального окружения

### **Backend (NestJS)**

1.  **Установите зависимости:**
    ```bash
    cd backend
    npm install
    ```

2.  **Настройте базу данных PostgreSQL:**
    *   Установите PostgreSQL.
    *   Создайте базу данных (например, `zvonilka_db`).
    *   **Важно:** При первом запуске backend автоматически создаст в базе данных пригласительный код `secret_invite`.

3.  **Настройте переменные окружения:**
    Создайте файл `backend/.env` и заполните его по примеру:
    ```env
    DATABASE_HOST=localhost
    DATABASE_PORT=5432
    DATABASE_USER=postgres
    DATABASE_PASSWORD=ваш_пароль
    DATABASE_NAME=zvonilka_db
    JWT_SECRET=супер_секретный_ключ_для_локальной_разработки
    ```

4.  **Запустите сервер для разработки:**
    ```bash
    npm run start:dev
    ```
    Сервер будет доступен по адресу `http://localhost:3000`.
    Swagger UI для тестирования API: `http://localhost:3000/api-docs`.

### **Frontend (Flutter)**

1.  **Установите зависимости:**
    ```bash
    cd frontend
    flutter pub get
    ```

2.  **Создайте файлы с переменными окружения:**
    В папке `frontend/` создайте два файла:

    *   `.env.development` (для подключения к локальному backend):
        ```
        API_URL=http://localhost:3000
        ```
    *   `.env.production` (для подключения к production backend):
        ```
        API_URL=https://zvonilka.ibessonniy.ru
        ```

---

## ⚙️ Запуск Frontend для разработки

Вы можете запускать frontend в разных режимах, используя файлы `.env` для указания нужного backend.

### **Запуск в браузере (Google Chrome)**

Это самый быстрый способ для UI-разработки.

```bash
# Запуск с подключением к ЛОКАЛЬНОМУ backend
flutter run -d chrome --dart-define-from-file=.env.development

# Запуск с подключением к PRODUCTION backend
flutter run -d chrome --dart-define-from-file=.env.production
```

### **Запуск на эмуляторе или физическом устройстве**

```bash
# Запуск на любом подключенном устройстве (эмулятор или USB)
# (по умолчанию использует .env.development, если не указано иное)
flutter run

# Запуск на конкретном устройстве по его ID с production backend
# Укажите ID вашего устройства
flutter run -d 0N13C08I261020C8 --dart-define-from-file=.env.production
```

---

## 📦 Сборка приложения (Build)

### **Android APK**

```bash
# Сборка debug-версии APK (для тестирования)
flutter build apk --debug --dart-define-from-file=.env.production

# Сборка release-версии APK (для установки)
flutter build apk --release --dart-define-from-file=.env.production
```
Собранный файл будет находиться в `frontend/build/app/outputs/flutter-apk/`.

### **Web-версия**

```bash
# Сборка release-версии для Web
flutter build web --release --dart-define-from-file=.env.production
```
Собранные файлы будут находиться в `frontend/build/web/`.

---

## 🖥️ Управление Production сервером

Все команды выполняются на сервере `5.8.76.33` после подключения по SSH.

### **Подключение к серверу**

```bash
ssh root@5.8.76.33
```

### **Управление Backend процессом (PM2)**

PM2 — это менеджер процессов, который следит, чтобы backend всегда был запущен.

```bash
# Перезапустить backend-приложение
# (Используйте этот alias для быстрого рестарта)
restart-backend

# Посмотреть последние 100 строк логов backend
pm2 logs zvonilka-backend --lines 100

# Посмотреть логи в реальном времени
pm2 logs zvonilka-backend --lines 50 -f

# Посмотреть статус всех запущенных процессов
pm2 list
```

### **Тестирование STUN сервера**

Чтобы убедиться, что STUN сервер для WebRTC-звонков работает корректно.

```bash
# Проверка статуса сервиса coturn
sudo systemctl status coturn

# Проверка, что сервер слушает порт 3478
sudo netstat -tulpn | grep 3478
```
