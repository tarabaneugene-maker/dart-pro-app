# Инструкция по деплою

## 1. Railway (сервер)

1. Зайдите на https://railway.app
2. Войдите через GitHub
3. Нажмите **"New Project"** → **"Deploy from GitHub repo"**
4. Выберите репозиторий **tarabaneugene-maker/dart-pro-app**
5. В настройках проекта укажите:
   - **Root Directory**: `server`
   - **Start Command**: `dart run lib/main.dart`
6. Нажмите **Deploy**
7. После деплоя скопируйте URL (например `dart-pro-server.up.railway.app`)

## 2. Vercel (фронтенд)

1. Зайдите на https://vercel.com
2. Войдите через GitHub
3. Нажмите **"Add New"** → **"Project"**
4. Выберите **tarabaneugene-maker/dart-pro-app**
5. В настройках:
   - **Framework Preset**: Other
   - **Build Command**: `flutter build web --release --dart-define=SERVER_URL=wss://ВАШ_RAILWAY_URL/ws`
   - **Output Directory**: `build/web`
6. Нажмите **Deploy**

## 3. После деплоя

Готово! Фронтенд будет доступен по ссылке Vercel, сервер — на Railway.
