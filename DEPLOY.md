# Инструкция по деплою

## 🅰 Полный стек на VPS (рекомендуется)

Всё на одном сервере: Flutter Web + Dart сервер + Caddy (HTTPS).

### 1. Подготовка сервера

Зайдите на сервер по SSH:

```bash
ssh -i ~/.ssh/dart -o StrictHostKeyChecking=accept-new bombressor@192.144.13.217
```

### 2. Быстрый запуск (автоматический скрипт)

```bash
curl -fsSL https://raw.githubusercontent.com/tarabaneugene-maker/dart-pro-app/main/server/setup.sh | bash
```

Скрипт сделает всё автоматически:
- ✅ Добавит SSH-ключи
- ✅ Установит Docker
- ✅ Установит Caddy
- ✅ Склонирует проект
- ✅ Соберёт Docker-образ (Flutter Web + сервер)
- ✅ Запустит контейнер
- ✅ Настроит Caddy reverse proxy с HTTPS

После завершения приложение будет доступно по адресу:
**https://192.144.13.217.nip.io**

### 3. Ручной запуск (пошагово)

```bash
# 1. Клонируем проект
git clone https://github.com/tarabaneugene-maker/dart-pro-app.git /opt/dart-pro-app
cd /opt/dart-pro-app

# 2. Собираем Docker-образ (Flutter Web + сервер)
docker build -t dart-pro-server -f Dockerfile .

# 3. Создаём папку для данных
mkdir -p /opt/dart-pro-data

# 4. Запускаем контейнер
docker run -d \
    --name dart-pro-server \
    --restart unless-stopped \
    -p 127.0.0.1:8080:8080 \
    -v /opt/dart-pro-data:/app/data \
    -e PORT=8080 \
    -e JWT_SECRET="$(openssl rand -hex 32)" \
    dart-pro-server

# 5. Проверяем, что сервер работает
curl http://localhost:8080/health
# → {"status":"ok","uptime":"...","activeRooms":0,"activePlayers":0}

# 6. Устанавливаем Caddy для HTTPS
apt-get install -y caddy
cat > /etc/caddy/Caddyfile << 'CADDY'
192.144.13.217.nip.io {
    reverse_proxy localhost:8080
}
CADDY
systemctl enable caddy
systemctl restart caddy
```

### 4. Обновление

```bash
cd /opt/dart-pro-app
git pull
docker stop dart-pro-server
docker rm dart-pro-server
docker build -t dart-pro-server -f Dockerfile .
docker run -d \
    --name dart-pro-server \
    --restart unless-stopped \
    -p 127.0.0.1:8080:8080 \
    -v /opt/dart-pro-data:/app/data \
    -e PORT=8080 \
    -e JWT_SECRET="$(openssl rand -hex 32)" \
    dart-pro-server
```

### 5. Просмотр логов

```bash
docker logs -f dart-pro-server
```

---

## 🅱 Railway + Vercel (альтернативный вариант)

### 1. Railway (сервер)

1. Зайдите на https://railway.app
2. Войдите через GitHub
3. Нажмите **"New Project"** → **"Deploy from GitHub repo"**
4. Выберите репозиторий **tarabaneugene-maker/dart-pro-app**
5. В настройках проекта укажите:
   - **Root Directory**: `server`
   - **Builder**: Dockerfile (автоматически)
6. В **Variables** добавьте:
   - `PORT` = `8080`
   - `DB_PATH` = `/app/data/dart_pro.db`
7. В **Volumes** добавьте volume, смонтированный в `/app/data`
8. Нажмите **Deploy**
9. После деплоя скопируйте URL (например `dart-pro-server.up.railway.app`)

### 2. Vercel (фронтенд)

1. Зайдите на https://vercel.com
2. Войдите через GitHub
3. Нажмите **"Add New"** → **"Project"**
4. Выберите **tarabaneugene-maker/dart-pro-app**
5. В настройках:
   - **Framework Preset**: Other
   - **Build Command**: `flutter build web --release --dart-define=SERVER_URL=wss://ВАШ_RAILWAY_URL/ws`
   - **Output Directory**: `build/web`
6. Нажмите **Deploy**

---

## Проверка сервера

```bash
curl https://192.144.13.217.nip.io/health
# → {"status":"ok","uptime":"...","activeRooms":0,"activePlayers":0}
```

## Переменные окружения сервера

| Переменная | Описание | По умолчанию |
|-----------|----------|-------------|
| `PORT` | Порт для HTTP/WS | `8080` |
| `DB_PATH` | Путь к файлу SQLite | `/app/data/dart_pro.db` |
| `JWT_SECRET` | Секрет для JWT токенов | (генерируется случайно) |
