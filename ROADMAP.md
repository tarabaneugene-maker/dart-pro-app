# 🎯 Dart Pro App

Flutter Web + Dart сервер. Дартс: 501, Cricket, тренировки, онлайн.

**Стек:** Flutter Web → Dart сервер → SQLite → WebSocket → Docker + Caddy  
**VPS:** `192.144.13.217` (nip.io), health: `GET /health`

---

## 📁 Структура

```
lib/
├── main.dart                       # Точка входа, меню
├── models/                         # game_enums, PlayerConfig, GameSettings, CricketSettings
├── data/checkouts.dart             # Таблица чекаутов (2–170)
├── game/
│   ├── game_board_widget.dart      # Табло 501 + панель ввода (сумма/per-dart)
│   ├── cricket_board_widget.dart   # Доска Cricket (сектора, полоски, h/t, Triple/Double/OK)
│   ├── game_page_501.dart          # Локальная игра 501
│   ├── cricket_game_page.dart      # Локальная игра Cricket (Classic / American)
│   ├── game_setup_page.dart        # Настройка 501
│   ├── cricket_setup_page.dart     # Настройка Cricket
│   └── local_game_menu_page.dart   # Меню выбора режима
├── online/                         # Auth (JWT), лобби, комнаты, WebSocket, онлайн-матч 501
├── bots/                           # 5 уровней, симуляция бросков, Double Out/In
├── training/                       # Сектор, Around the Clock (2 варианта)
├── services/bot_service.dart
└── widgets/                        # StubPage, CheckOutsPage

server/lib/
├── main.dart                       # HTTP + WebSocket на одном порту
├── auth/                           # JWT, bcrypt, rate limit
├── db/                             # SQLite (WAL)
├── game/                           # Комнаты, синхронизация 501
└── models/                         # User, Room, MatchResult
```

## ✅ Готово

- **501**: сумма/per-dart, undo, bust, double out, сеты/леги, average, checkout-подсказки
- **Боты**: 5 уровней, Double Out/In, свои checkout-таблицы
- **Онлайн**: регистрация, JWT, WebSocket (heartbeat, reconnect, re-auth), лобби, комнаты, матч 501
- **Онлайн: reconnect-диалог** — не показывает форфейт, если соперник вернулся
- **Онлайн: per-dart режим ввода** — переключение сумма/по-дротику через ⚙️
- **Онлайн: turn timeout** — turnDeadline (абсолютный timestamp), таймер на клиенте, диалог форфейта
- **Cricket**: Classic/American, сектора 20→Bull, полоски (stripes) вместо маркеров / X ■, Triple/Double/OK, h/t колонка (хиты за подход), лимит 3 сектора за подход (ceil(hits/mult)), розовый фон для чужих закрытых секторов, подсчёт очков (American), totalPoints bar, проверка победы, last approach, avg h/t, AppBar с условиями
- **Тренировки**: Сектор (счётчик попаданий), Around the Clock (выбор Single/Double/Triple), Classic 1→20→Bull
- **Сервер**: SQLite WAL, rate limit (30/10s), graceful shutdown, health check, Docker multi-stage
- **Деплой**: VPS + Docker + Caddy (HTTPS авто), скрипт setup.sh, deploy_vps.ps1

## ⚠️ Нужно сделать / Доработать

| Что | Где | Описание |
|-----|-----|----------|
| **Training: Around/Classic** | `lib/training/training_widgets.dart` | process-логика не дописана (TODO) |
| **Онлайн: pendingPlayers** | `server/lib/game/game_room_manager.dart` | Не очищается при выходе из комнаты |
| **Онлайн: state reconciliation** | — | Reconnect не синхронизирует состояние игры |
| **Онлайн: per-dart на сервере** | — | Сервер хранит только сумму — соперник не видит отдельные дротики |
| **Онлайн: Double Out проверка** | — | На сервере нет проверки double out |
| **Cricket: боты** | — | Нет ботов для Cricket |
| **Cricket: онлайн** | — | Только локальная игра |
| **Cricket: сеты/леги** | `lib/game/cricket_game_page.dart` | Не реализованы — только леги (нет увеличения legsWon/setsWon) |
| **Checkouts 41–59** | `lib/data/checkouts.dart` | Только 60–170 |
| **Статистика / Настройки** | `lib/widgets/stub_page.dart` | Заглушка |
| **Баг: вылезающие броски 501** | `lib/game/game_board_widget.dart` | Last dart results перекрывают счёт |

## 🚀 Деплой

```bash
# Быстрый запуск с нуля
curl -fsSL https://raw.githubusercontent.com/tarabaneugene-maker/dart-pro-app/main/server/setup.sh | sudo bash

# Обновление
cd /opt/dart-pro-app && git pull && docker build -t dart-pro-server . && docker stop dart-pro-server && docker rm dart-pro-server && docker run -d --name dart-pro-server --restart unless-stopped -p 9090:9090 -v /opt/dart-pro-data:/app/data -e PORT=9090 dart-pro-server

# Проверка
curl http://192.144.13.217:9090/health
```

Переменные: `PORT` (9090), `DB_PATH` (/app/data/dart_pro.db), `JWT_SECRET` (генерируется).

---

*05.06.2026*
