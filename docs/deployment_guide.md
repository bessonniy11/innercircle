# 🚀 Руководство по Развертыванию "Звонилка"

## 📋 Обзор

Это подробное руководство по развертыванию backend приложения "Звонилка" на production сервере. Руководство покрывает все этапы от заказа VPS до финальной настройки и тестирования.

---

## 🎯 Архитектура Production Deployment

```
Internet
    ↓
[Nginx] (Port 80/443) → [NestJS Backend] (Port 3000) → [PostgreSQL] (Port 5432)
    ↑                         ↑                              ↑
SSL/Reverse Proxy        PM2 Process Manager         Database Server
```

### **Компоненты инфраструктуры:**
- **VPS сервер:** Ubuntu 24.04 LTS
- **Web сервер:** Nginx (reverse proxy + SSL termination)
- **Backend:** NestJS приложение
- **Process Manager:** PM2 для автозапуска и мониторинга
- **База данных:** PostgreSQL 16
- **Домен:** zvonilka.ibessonniy.ru (или прямой IP доступ)

---

## 🛒 Этап 1: Заказ и Настройка VPS

### **1.1 Заказ сервера**

**Рекомендуемые характеристики:**
```
CPU: 2+ cores
RAM: 2+ GB  
Storage: 20+ GB SSD
OS: Ubuntu 24.04 LTS
Network: 100 Mbps+
```

**Провайдеры:**
- DigitalOcean, Hetzner, Timeweb, REG.RU и др.

### **1.2 Первоначальная настройка сервера**

```bash
# Обновление системы
sudo apt update && sudo apt upgrade -y

# Установка базовых пакетов
sudo apt install -y curl wget git nano ufw
```

### **1.3 Настройка SSH (рекомендуется)**

```bash
# Отключение входа под root через пароль
sudo nano /etc/ssh/sshd_config

# Изменить:
PermitRootLogin no
PasswordAuthentication no

# Перезапуск SSH
sudo systemctl restart sshd
```

---

## 🔧 Этап 2: Установка Программного Обеспечения

### **2.1 Установка Node.js**

```bash
# Установка NodeSource репозитория
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

# Установка Node.js
sudo apt-get install -y nodejs

# Проверка установки
node --version  # должно показать v20.x.x
npm --version   # должно показать 10.x.x
```

### **2.2 Установка PostgreSQL**

```bash
# Установка PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# Запуск и автозапуск
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Проверка статуса
sudo systemctl status postgresql
```

### **2.3 Установка Nginx**

```bash
# Установка Nginx
sudo apt install -y nginx

# Запуск и автозапуск
sudo systemctl start nginx
sudo systemctl enable nginx

# Проверка статуса
sudo systemctl status nginx
```

### **2.4 Установка PM2**

```bash
# Глобальная установка PM2
sudo npm install -g pm2

# Настройка автозапуска PM2
pm2 startup
# Выполните команду которую покажет PM2
```

---

## 📁 Этап 3: Развертывание Backend Кода

### **3.1 Создание директории проекта**

```bash
# Создание директорий
sudo mkdir -p /var/www/zvonilka
sudo chown $USER:$USER /var/www/zvonilka
```

### **3.2 Перенос кода на сервер**

**Вариант A: Git (рекомендуется)**
```bash
cd /var/www/zvonilka
git clone https://github.com/yourusername/zvonilka.git .
cd backend
```

**Вариант B: FileZilla/SCP**
```bash
# Загрузите все файлы из папки backend/ на сервер в /var/www/zvonilka/backend/
# Исключите: node_modules/, dist/, .env (будем создавать отдельно)
```

### **3.3 Установка зависимостей и сборка**

```bash
cd /var/www/zvonilka/backend

# Установка зависимостей
npm install

# Сборка проекта
npm run build

# crypto
echo "global.crypto = require('crypto');" | cat - dist/main.js > temp && mv temp dist/main.js
```


---

## 🗄️ Этап 4: Настройка PostgreSQL

### **4.1 Создание пользователя и базы данных**

```bash
# Вход в PostgreSQL
sudo -u postgres psql

# В psql консоли:
CREATE USER zvonilka_user WITH PASSWORD 'ZvonilkaDB2025!';
CREATE DATABASE zvonilka OWNER zvonilka_user;
GRANT ALL PRIVILEGES ON DATABASE zvonilka TO zvonilka_user;

# Выход
\q
```

### **4.2 Проверка подключения**

```bash
# Тест подключения
psql -h localhost -U zvonilka_user -d zvonilka
# Введите пароль: ZvonilkaDB2025!
```

---

## ⚙️ Этап 5: Настройка Environment Variables

### **5.1 Создание .env файла**

```bash
cd /var/www/zvonilka/backend
nano .env
```

**Содержимое .env:**
```env
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USER=zvonilka_user
DATABASE_PASSWORD=ZvonilkaDB2025!
DATABASE_NAME=zvonilka
JWT_SECRET=ZvonilkaSecretKey2025ForProduction!
PORT=3000
NODE_ENV=production
```

### **5.2 Безопасность .env файла**

```bash
# Ограничение доступа к .env
chmod 600 .env
chown $USER:$USER .env
```

---

## 🎛️ Этап 6: Настройка PM2

### **6.1 Создание PM2 конфигурации**

```bash
cd /var/www/zvonilka/backend
nano ecosystem.config.js
```

**Содержимое ecosystem.config.js:**
```javascript
module.exports = {
  apps: [{
    name: 'zvonilka-backend',
    script: 'dist/main.js',
    cwd: '/var/www/zvonilka/backend',
    env: {
      NODE_ENV: 'production'
    },
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    error_file: './logs/err.log',
    out_file: './logs/out.log',
    log_file: './logs/combined.log',
    time: true
  }]
}
```

### **6.2 Создание директории для логов**

```bash
mkdir -p /var/www/zvonilka/backend/logs
```

### **6.3 Исправление crypto polyfill (если нужно)**

```bash
# Редактирование скомпилированного файла
nano /var/www/zvonilka/backend/dist/main.js

# В самое начало файла добавить:
global.crypto = require('crypto');
```

### **6.4 Запуск приложения через PM2**

```bash
cd /var/www/zvonilka/backend

# Запуск с конфигурацией
pm2 start ecosystem.config.js

# Сохранение конфигурации для автозапуска
pm2 save

# Проверка статуса
pm2 status
pm2 logs zvonilka-backend
```

---

## 🌐 Этап 7: Настройка Nginx

### **7.1 Создание конфигурации сайта**

```bash
sudo nano /etc/nginx/sites-available/zvonilka
```

**Содержимое конфигурации:**
```nginx
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

### **7.2 Активация конфигурации**

```bash
# Удаление default сайта
sudo rm /etc/nginx/sites-enabled/default

# Активация нашего сайта
sudo ln -s /etc/nginx/sites-available/zvonilka /etc/nginx/sites-enabled/

# Проверка конфигурации
sudo nginx -t

# Перезапуск Nginx
sudo systemctl restart nginx
```

---

## 🗄️ Этап 8: Инициализация Базы Данных

### **8.1 Создание схемы базы данных**

```bash
# Backend автоматически создаст таблицы при первом запуске
# Проверяем логи PM2
pm2 logs zvonilka-backend
```

### **8.2 Добавление пригласительного кода**

```bash
# Подключение к базе
psql -h localhost -U zvonilka_user -d zvonilka

# Добавление кода (если не создался автоматически)
INSERT INTO invitation_code (code, "isUsed") VALUES ('secret_invite', false);

# Проверка
SELECT * FROM invitation_code;

# Выход
\q
```

---

## 🔥 Этап 9: Настройка Firewall

### **9.1 Базовая настройка ufw**

```bash
# Включение firewall
sudo ufw enable

# Разрешение SSH
sudo ufw allow ssh

# Разрешение HTTP/HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Проверка статуса
sudo ufw status
```

---

## ✅ Этап 10: Тестирование Deployment

### **10.1 Проверка доступности API**

```bash
# Тест с сервера
curl http://localhost:3000/api-docs

# Тест извне (замените IP)
curl http://5.8.76.33/api-docs
```

### **10.2 Проверка Swagger UI**

Откройте в браузере:
- `http://5.8.76.33/api-docs`
- `https://zvonilka.ibessonniy.ru/api-docs` (когда DNS настроится)

### **10.3 Тест API endpoints**

```bash
# Проверка защищенных endpoints (должен возвращать 401)
curl http://5.8.76.33/chats

# Проверка пригласительных кодов
curl http://5.8.76.33/invitation-codes
```

### **10.4 Проверка логов**

```bash
# Логи приложения
pm2 logs zvonilka-backend

# Логи Nginx
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Логи системы
sudo journalctl -f -u nginx
```

---

## 🔄 Процедуры Обслуживания

### **Обновление Backend кода:**

```bash
cd /var/www/zvonilka/backend

# Стоп приложения
pm2 stop zvonilka-backend

# Обновление кода (git или замена файлов)
git pull origin main
# или загрузка новых файлов через FileZilla

# Установка новых зависимостей (если есть)
npm install

# Пересборка
npm run build

# Исправление crypto polyfill (если нужно)
echo "global.crypto = require('crypto');" | cat - dist/main.js > temp && mv temp dist/main.js

# Запуск
pm2 start zvonilka-backend
pm2 logs zvonilka-backend
```

### **🚀 Простой перезапуск backend (одной командой):**

```bash
# Создайте скрипт для быстрого перезапуска
nano /root/restart_backend.sh
```

**Содержимое скрипта `/root/restart_backend.sh`:**
```bash
#!/bin/bash
echo "🔄 Перезапуск backend..."

cd /var/www/zvonilka/backend

echo "⏹️ Останавливаем backend..."
pm2 stop zvonilka-backend

echo "🔨 Пересобираем проект..."
npm run build

echo "🔧 Исправляем crypto polyfill..."
echo "global.crypto = require('crypto');" | cat - dist/main.js > temp && mv temp dist/main.js

echo "▶️ Запускаем backend..."
pm2 start zvonilka-backend

echo "📊 Проверяем статус..."
pm2 status zvonilka-backend

echo "✅ Backend перезапущен!"
echo "📝 Логи: pm2 logs zvonilka-backend"
```

**Делаем скрипт исполняемым:**
```bash
chmod +x /root/restart_backend.sh
```

**Теперь перезапуск backend - одна команда:**
```bash
/root/restart_backend.sh
```

**Или создайте алиас в ~/.bashrc:**
```bash
echo 'alias restart-backend="/root/restart_backend.sh"' >> ~/.bashrc
source ~/.bashrc

# Теперь можно использовать:
restart-backend
```

### **Перезапуск сервисов:**

```bash
# Перезапуск Backend
pm2 restart zvonilka-backend

# Перезапуск Nginx
sudo systemctl restart nginx

# Перезапуск PostgreSQL
sudo systemctl restart postgresql
```

### **Мониторинг ресурсов:**

```bash
# Использование ресурсов
pm2 monit

# Статус всех сервисов
sudo systemctl status nginx postgresql
pm2 status

# Использование диска
df -h

# Использование памяти
free -h
```

---

## 🚨 Решение Проблем

### **Backend не запускается:**

```bash
# Проверка логов PM2
pm2 logs zvonilka-backend --lines 50

# Проверка .env файла
cat /var/www/zvonilka/backend/.env

# Проверка подключения к БД
psql -h localhost -U zvonilka_user -d zvonilka
```

### **Nginx показывает default страницу:**

```bash
# Проверка конфигурации
sudo nginx -t

# Проверка активных сайтов
ls -la /etc/nginx/sites-enabled/

# Перезапуск Nginx
sudo systemctl restart nginx
```

### **API недоступен извне:**

```bash
# Проверка портов
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :3000

# Проверка firewall
sudo ufw status

# Проверка логов
pm2 logs zvonilka-backend
sudo tail -f /var/log/nginx/error.log
```

### **База данных недоступна:**

```bash
# Статус PostgreSQL
sudo systemctl status postgresql

# Проверка подключения
sudo -u postgres psql -c "\l"

# Логи PostgreSQL
sudo journalctl -u postgresql
```

---

## 🔒 Безопасность Production

### **Обязательные меры:**

1. **SSH Keys:** Отключить парольную аутентификацию
2. **Firewall:** Открыть только необходимые порты
3. **SSL:** Настроить HTTPS сертификат (Let's Encrypt)
4. **Backup:** Регулярное резервное копирование БД
5. **Updates:** Регулярные обновления системы

### **Скрипт резервного копирования:**

```bash
#!/bin/bash
# /home/user/backup_zvonilka.sh

BACKUP_DIR="/home/user/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Создание директории
mkdir -p $BACKUP_DIR

# Бэкап базы данных
pg_dump -h localhost -U zvonilka_user zvonilka > $BACKUP_DIR/zvonilka_$DATE.sql

# Бэкап кода (опционально)
tar -czf $BACKUP_DIR/backend_$DATE.tar.gz /var/www/zvonilka/backend

# Удаление старых бэкапов (старше 7 дней)
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

---

## 📊 Мониторинг Production

### **Основные метрики для отслеживания:**

- **CPU Usage:** < 80%
- **Memory Usage:** < 80%
- **Disk Usage:** < 90%
- **Response Time:** < 500ms
- **Error Rate:** < 1%

### **Полезные команды мониторинга:**

```bash
# Мониторинг PM2
pm2 monit

# Системные ресурсы
htop
iotop
nethogs

# Логи в реальном времени
pm2 logs zvonilka-backend --lines 100 -f
sudo tail -f /var/log/nginx/access.log
```

---

## 🚨 Текущие Проблемы Production Deployment

### **Дата выявления:** 25.08.2025  
**Статус:** Production работает, но есть критические проблемы для решения

---

## 📞 **Проблема 1: WebRTC звонки работают частично**

### **Симптомы:**
- ✅ **Backend работает стабильно** - все API endpoints отвечают
- ✅ **WebSocket соединения** - стабильно работают между клиентами
- ✅ **Сигналинг работает** - экраны звонков, таймеры, UI функциональны
- ❌ **Аудио не передается** - пользователи не слышат друг друга

### **Диагностика на сервере:**
```bash
# Проверка WebSocket соединений
pm2 logs zvonilka-backend | grep "WebSocket"

# Проверка портов
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :3000

# Проверка firewall
sudo ufw status
```

### **Возможные причины:**
1. **STUN/TURN серверы отсутствуют** - нужны для NAT traversal
2. **ICE candidates не обмениваются** - проблема в WebRTC конфигурации
3. **Медиа потоки не устанавливаются** - peer-to-peer соединения не работают

### **Решение:**
- [ ] **Установка STUN сервера** на production сервере
- [ ] **Настройка TURN сервера** для сложных сетей
- [ ] **Обновление WebRTC конфигурации** с правильными ICE серверами

---

## 🔐 **Проблема 2: JWT токены устаревают**

### **Симптомы:**
- ✅ **Авторизация работает** при первом входе
- ❌ **Через 6-12 часов** чаты и контакты исчезают
- ❌ **API возвращает 401** Unauthorized
- ✅ **При повторной авторизации** всё восстанавливается

### **Диагностика на сервере:**
```bash
# Проверка логов аутентификации
pm2 logs zvonilka-backend | grep "JWT\|auth\|401"

# Проверка .env файла
cat /var/www/zvonilka/backend/.env | grep JWT

# Проверка базы данных
psql -h localhost -U zvonilka_user -d zvonilka -c "SELECT * FROM users LIMIT 5;"
```

### **Причина:**
- **Refresh token система отсутствует** - токены не обновляются автоматически
- **JWT expires in 24 hours** - но frontend не обрабатывает expired токены

### **Решение:**
- [ ] **Backend:** Добавить refresh token в login response
- [ ] **Frontend:** Автоматическое обновление токена при 401
- [ ] **AuthService:** Обработка expired токенов

---

## 🔒 **Проблема 3: Отсутствие шифрования**

### **Текущее состояние безопасности:**
```
Уровень безопасности:
├── ✅ HTTPS/TLS 1.3 (Nginx)
├── ✅ JWT токены (подписанные)
├── ✅ Пригласительные коды
├── ❌ End-to-end шифрование сообщений
├── ❌ Шифрование WebRTC медиа
└── ❌ Шифрование файлов
```

### **Планы по безопасности:**
- [ ] **End-to-end шифрование** сообщений (Phase 3)
- [ ] **WebRTC SRTP** для шифрования аудио/видео
- [ ] **Шифрование файлов** при передаче

---

## 🎯 **Приоритет решения проблем:**

### **🔥 Критически важно (следующие 1-2 сессии):**
1. **WebRTC аудио** - критично для основной функциональности
2. **Refresh токены** - критично для стабильной работы

### **⚠️ Важно (следующие 3-5 сессий):**
3. **Шифрование** - важно для безопасности, но не блокирует MVP

---

## 📊 **Статус Production:**

### **✅ Работает стабильно:**
- **Backend API** - все endpoints отвечают корректно
- **WebSocket соединения** - real-time коммуникация работает
- **База данных** - PostgreSQL стабильно работает
- **Nginx** - reverse proxy работает корректно
- **PM2** - process manager стабильно управляет приложением

### **🚨 Требует решения:**
- **WebRTC аудио** - основная функциональность звонков
- **JWT токены** - стабильность авторизации
- **STUN/TURN серверы** - для WebRTC через NAT

---

## 🔧 **Команды для диагностики:**

```bash
# Проверка статуса всех сервисов
sudo systemctl status nginx postgresql
pm2 status
pm2 logs zvonilka-backend --lines 50

# Проверка ресурсов
htop
df -h
free -h

# Проверка сетевых соединений
sudo netstat -tlnp | grep :80
sudo netstat -tlnp | grep :3000
sudo ufw status

# Проверка логов
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
pm2 logs zvonilka-backend --lines 100 -f
```

---

**📅 Последнее обновление:** 25.08.2025  
**🎯 Статус:** Production работает, но есть критические проблемы для решения 🚨

---

## 📝 Итоговый Checklist

### **✅ Перед запуском в production:**

- [ ] VPS сервер настроен и обновлен
- [ ] Node.js, PostgreSQL, Nginx установлены
- [ ] Backend код развернут в `/var/www/zvonilka/backend`
- [ ] .env файл создан с production настройками
- [ ] База данных создана и пригласительный код добавлен
- [ ] PM2 настроен и приложение запущено
- [ ] Nginx настроен как reverse proxy
- [ ] Firewall настроен (порты 22, 80, 443)
- [ ] API доступен и возвращает корректные ответы
- [ ] Swagger UI работает
- [ ] Логи не содержат критических ошибок

### **✅ После запуска:**

- [ ] Настроить SSL сертификат (Let's Encrypt)
- [ ] Настроить автоматические бэкапы
- [ ] Настроить мониторинг (Grafana + Prometheus)
- [ ] Настроить алерты при проблемах
- [ ] Документировать процедуры восстановления

---

**📅 Последнее обновление:** 24.08.2025  
**👨‍💻 Автор:** ИИ-Ассистент + Bessonniy  
**🌐 Production URL:** http://5.8.76.33 (временно), https://zvonilka.ibessonniy.ru (планируется)  
**🎯 Статус:** Production ready ✅

## 🎉 **WebRTC STUN Сервер: НАСТРОЕН И РАБОТАЕТ!** ✅

**Статус:** ✅ **ПОЛНОСТЬЮ НАСТРОЕН И РАБОТАЕТ** (25.08.2025)

**Результат:** WebRTC звонки теперь ПОЛНОСТЬЮ РАБОТАЮТ! Пользователи слышат друг друга как на веб-версии, так и на мобильных устройствах.

**Технические детали:**
- **STUN сервер:** coturn на порту 3478 UDP ✅
- **TURN сервер:** планируется в будущем для сложных сетей ⏳
- **Конфигурация:** `/etc/turnserver.conf` настроен для STUN ✅
- **Файрвол:** UFW с открытым портом 3478 UDP ✅
- **Сервис:** Автозапуск через systemd ✅
- **Тестирование:** Звонки работают между устройствами ✅

**📝 ПРИМЕЧАНИЕ:** TURN сервер планируется добавить позже для обеспечения стабильной работы в корпоративных сетях с жесткими файрволами.

**🎯 РЕЗУЛЬТАТ:** Семейный мессенджер "Звонилка" теперь имеет полноценные голосовые звонки!

**🚀 Следующие шаги:** Настройка TURN сервера для 100% покрытия сетей.
