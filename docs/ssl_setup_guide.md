# Настройка SSL для zvonilka.ibessonniy.ru

## 🔍 ТЕКУЩАЯ СИТУАЦИЯ:
- ✅ DNS уже правильно настроен: `zvonilka.ibessonniy.ru` → `5.8.76.33`
- ✅ HTTP работает: `http://zvonilka.ibessonniy.ru/api-docs` доступен
- ❌ Let's Encrypt пока не может получить сертификат (кэширование DNS)

## 🛠️ ПОШАГОВАЯ НАСТРОЙКА SSL:

### 1. Подключение к серверу
```bash
ssh root@5.8.76.33
```

### 2. Установка Certbot (уже выполнено ✅)
```bash
apt update
apt install certbot python3-certbot-nginx -y
```

### 3. Восстановление рабочей HTTP конфигурации
```bash
# Создаем простую конфигурацию для домена
cat > /etc/nginx/sites-available/zvonilka << 'EOF'
server {
    listen 80;
    server_name zvonilka.ibessonniy.ru 5.8.76.33;
    
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
EOF

# Активируем
ln -sf /etc/nginx/sites-available/zvonilka /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/zvonilka-https
rm -f /etc/nginx/sites-enabled/zvonilka-ip

# Проверяем и перезагружаем
nginx -t
systemctl reload nginx
```

### 4. Ожидание обновления DNS (2-4 часа)
```bash
# Проверяем что HTTP работает
curl http://zvonilka.ibessonniy.ru/api-docs
curl http://zvonilka.ibessonniy.ru/users
```

### 5. Получение SSL сертификата (после ожидания)
```bash
# Останавливаем Nginx для standalone режима
systemctl stop nginx

# Получаем сертификат
certbot certonly --standalone --preferred-challenges http -d zvonilka.ibessonniy.ru

# Если не работает, пробуем с принудительным обновлением
certbot certonly --standalone --preferred-challenges http --force-renewal -d zvonilka.ibessonniy.ru
```

### 6. Настройка Nginx с SSL сертификатом
```bash
# Запускаем Nginx обратно
systemctl start nginx

# Создаем HTTPS конфигурацию
cat > /etc/nginx/sites-available/zvonilka-ssl << 'EOF'
server {
    listen 80;
    server_name zvonilka.ibessonniy.ru;
    
    # Автоматическое перенаправление HTTP на HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name zvonilka.ibessonniy.ru;

    # SSL сертификаты Let's Encrypt
    ssl_certificate /etc/letsencrypt/live/zvonilka.ibessonniy.ru/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/zvonilka.ibessonniy.ru/privkey.pem;
    
    # SSL настройки
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

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
EOF

# Активируем HTTPS конфигурацию
ln -sf /etc/nginx/sites-available/zvonilka-ssl /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/zvonilka

# Проверяем и перезагружаем
nginx -t
systemctl reload nginx
```

### 7. Проверка работы SSL
```bash
# Проверяем статус Nginx
systemctl status nginx

# Проверяем SSL сертификат
certbot certificates

# Тестируем HTTPS
curl -I https://zvonilka.ibessonniy.ru/api-docs
```

## 🎯 ОЖИДАЕМЫЙ РЕЗУЛЬТАТ:

После выполнения:
1. ✅ `https://zvonilka.ibessonniy.ru/api-docs` - работает с SSL
2. ✅ `http://zvonilka.ibessonniy.ru` - автоматически перенаправляет на HTTPS
3. ✅ SSL сертификат автоматически обновляется каждые 90 дней

## 🔧 АЛЬТЕРНАТИВНЫЕ МЕТОДЫ (если основной не работает):

### Метод 1: DNS Challenge
```bash
# Используем DNS проверку вместо HTTP
certbot certonly --manual --preferred-challenges dns -d zvonilka.ibessonniy.ru
```

### Метод 2: Временные самоподписанные сертификаты
```bash
# Генерируем самоподписанные сертификаты
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/zvonilka.key \
    -out /etc/ssl/certs/zvonilka.crt \
    -subj "/C=RU/ST=Moscow/L=Moscow/O=Zvonilka/CN=zvonilka.ibessonniy.ru"
```

## 📅 ПЛАН ВЫПОЛНЕНИЯ:

1. **Сейчас** - восстановить HTTP конфигурацию ✅
2. **Через 2-4 часа** - попробовать получить SSL сертификат
3. **Если не работает** - использовать альтернативные методы
4. **После получения** - настроить Nginx с SSL

## 🚨 ВАЖНЫЕ ЗАМЕЧАНИЯ:

- **Не торопитесь** - DNS изменения могут занимать время
- **Проверяйте логи** - `tail -f /var/log/letsencrypt/letsencrypt.log`
- **Делайте бэкапы** - `cp /etc/nginx/sites-available/zvonilka /etc/nginx/sites-available/zvonilka.backup`

## 📞 ПОДДЕРЖКА:

Если ничего не работает:
- Проверьте логи: `journalctl -u nginx -f`
- Проверьте статус: `systemctl status nginx`
- Проверьте порты: `netstat -tlnp | grep :80`
