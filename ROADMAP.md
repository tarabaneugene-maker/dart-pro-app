# 🎯 Dart Pro App — Roadmap

> Flutter Web + Dart сервер для игры в дартс (501, Cricket, тренировки).
> Production: **https://192.144.13.217.nip.io**

**Стек:** Flutter Web (клиент), Dart (сервер), SQLite (БД), WebSocket (реалтайм), Docker + Caddy (деплой).

---

## 🏗 Архитектура

```
lib/                          # Flutter-клиент
├── main.dart                 # Точка входа, главное меню (плитки)
├── models/                   # Модели данных (enums, PlayerConfig, GameSettings, CricketSettings)
├── bots/                     # Симуляция бросков, контекст, 5 уровней сложности
├── game/                     # Экраны: меню, настройка 501/Cricket, игровой процесс 501
├── online/                   # Онлайн: auth, профиль, лобби, комнаты, WebSocket-сервис
├── training/                 # Тренировочные режимы
├── services/                 # BotService
└── widgets/                  # Общие виджеты

server/                       # Dart-сервер
└── lib/
    ├── main.dart             # Точка входа (HTTP + WebSocket)
    ├── auth/                 # JWT-аутентификация (bcrypt)
    ├── db/                   # SQLite (WAL mode)
    ├── game/                 # Комнаты, синхронизация
    └── models/               # Модели сервера
```

---

## ✅ Готово

- **Главное меню** — 5 плиток (Локальная игра, Тренировка, Онлайн, Статистика, Настройки), без нижнего бара
- **Навигация** — через `Navigator.push`, каждая страница со своим AppBar
- **Модели данных** — enums, PlayerConfig, GameSettings, CricketSettings (с copyWith)
- **Система ботов** — симуляция бросков, 5 уровней сложности, таблица checkout'ов
- **Игра 501 офлайн** — 2 режима ввода (сумма подхода / каждый бросок), undo, bust-диалог, double out, сеты/леги, статистика, checkout-таблица (2-170), подсветка активного игрока (зелёный), счётчик дротиков
- **Онлайн-аутентификация** — регистрация/логин, JWT, bcrypt, rate limiting, «запомнить меня»
- **WebSocket** — heartbeat (15с), reconnect с re-auth, очередь сообщений (_outbox), защита от гонок, request-response для auth
- **Лобби** — создание комнат, вступление по коду, запросы на вступление, авто-обновление списка
- **Сервер** — SQLite (WAL), graceful shutdown (SIGTERM), health check (`/health`), Docker multi-stage, rate limiting
- **Деплой** — VPS (Docker + Caddy + HTTPS), скрипт `server/setup.sh` для быстрой настройки

---

## 🔧 В разработке

- **Онлайн-матч 501 (~70%)** — синхронизация ходов, обработка disconnect, навигация после матча, доведение joinByCode/acceptJoin
- **Cricket (~10%)** — игровая страница, доска, подсчёт
- **Тренировки (~30%)** — доработка режимов

---

## 📝 В плане

- Звуки и анимации (бросок, попадание, победный лег)
- Unit-тесты (боты, симулятор, логика подсчёта)
- Локализация (русский/английский)
- ELO-рейтинг / система подбора игроков
- UI-улучшения: landscape lock, компактный layout, кнопка OK для режима «каждый бросок»

---

## 🐛 Замеченные баги / Техдолг

- Расчёт среднего набора — bust-ввод не должен участвовать в статистике
- `pendingPlayers` не очищается при выходе из комнаты (сервер)
- Turn timeout / Grace period / State reconciliation — не реализованы
- WSS (HTTPS) — требуется настройка Caddy/Nginx (на VPS настроено)

---

## 🚀 Деплой

**Production VPS:** `192.144.13.217` (Ubuntu + Docker + Caddy)

| Действие | Команда |
|----------|---------|
| Быстрый запуск | `curl -fsSL https://raw.githubusercontent.com/tarabaneugene-maker/dart-pro-app/main/server/setup.sh \| sudo bash` |
| Обновление | `update_vps.ps1` (Windows) или `git pull && docker build/run` (Linux) |
| Проверка | `curl https://192.144.13.217.nip.io/health` |
| Логи | `docker logs -f dart-pro-server` |

**Альтернатива:** Railway (сервер) + Vercel (фронтенд) — см. `DEPLOY.md`

### Переменные окружения сервера

| Переменная | Описание | По умолчанию |
|-----------|----------|-------------|
| `PORT` | Порт для HTTP/WS | `8080` |
| `DB_PATH` | Путь к SQLite | `/app/data/dart_pro.db` |
| `JWT_SECRET` | Секрет для JWT | (генерируется случайно) |

---

*Последнее обновление: 29.05.2026*
