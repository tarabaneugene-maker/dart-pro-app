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
├── bots/                     # Симуляция бросков, 5 уровней сложности
├── game/                     # Экраны: меню, настройка 501/Cricket, игровой процесс 501
├── online/                   # Онлайн: auth, профиль, лобби, комнаты, WebSocket
├── training/                 # Тренировочные режимы
├── services/                 # BotService
└── widgets/                  # Общие виджеты (табло, панель ввода)

server/                       # Dart-сервер
└── lib/
    ├── main.dart             # HTTP + WebSocket
    ├── auth/                 # JWT-аутентификация
    ├── db/                   # SQLite
    ├── game/                 # Комнаты, синхронизация
    └── models/               # Модели сервера
```

---

## ✅ Реализовано

### Локальная игра 501
- Два режима ввода: сумма подхода / каждый бросок
- Undo, bust-диалог, double out, сеты/леги
- Среднее (average) = (totalScore / totalDarts) × 3
- Диалог закрытия лега с выбором количества дротиков (1/2/3)
- Подсветка активного игрока (зелёный), счётчик дротиков
- Checkout-таблица (2–170)

### Боты
- Симуляция бросков, 5 уровней сложности
- Таблица checkout'ов

### Онлайн
- Регистрация/логин, JWT, bcrypt, «запомнить меня»
- WebSocket: heartbeat, reconnect с re-auth, очередь сообщений
- Лобби: создание комнат, вступление по коду, запросы на вступление
- Онлайн-матч 501: синхронизация ходов, обработка дисконнекта

### Сервер
- SQLite, graceful shutdown, health check (`/health`)
- Rate limiting, Docker multi-stage

### Деплой
- VPS (Ubuntu + Docker + Caddy + HTTPS)
- Скрипт `server/setup.sh` для быстрой настройки

---

## 🔧 В разработке

- **Cricket** — игровая страница, доска, подсчёт
- **Тренировки** — доработка режимов

---

## 📋 Планируется

- Звуки и анимации (бросок, попадание, победный лег)
- Unit-тесты (боты, симулятор, логика подсчёта)
- Локализация (русский/английский)
- ELO-рейтинг / система подбора игроков
- UI-улучшения: landscape lock, компактный layout

---

## 🐛 Известные проблемы

- `pendingPlayers` не очищается при выходе из комнаты (сервер)
- Turn timeout / Grace period / State reconciliation — не реализованы

---

## 🚀 Деплой

**Production VPS:** `192.144.13.217` (Ubuntu + Docker + Caddy)

| Действие | Команда |
|----------|---------|
| Быстрый запуск | `curl -fsSL https://raw.githubusercontent.com/tarabaneugene-maker/dart-pro-app/main/server/setup.sh \| sudo bash` |
| Обновление | `update_vps.ps1` (Windows) или `git pull && docker build/run` (Linux) |
| Проверка | `curl https://192.144.13.217.nip.io/health` |
| Логи | `docker logs -f dart-pro-server` |

### Переменные окружения сервера

| Переменная | Описание | По умолчанию |
|-----------|----------|-------------|
| `PORT` | Порт для HTTP/WS | `8080` |
| `DB_PATH` | Путь к SQLite | `/app/data/dart_pro.db` |
| `JWT_SECRET` | Секрет для JWT | (генерируется случайно) |

---

*Последнее обновление: 29.05.2026*
