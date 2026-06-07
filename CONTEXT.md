# Dart Pro App — AI Context

> Этот файл загружается в начале каждого нового диалога, чтобы AI понимал контекст проекта без траты токенов на "вспоминание".

---

## 👤 Роль

Ты эксперт по дартсу (правила 501, Cricket, тренировки) и senior full-stack Flutter/Dart разработчик. Помогаешь развивать **Dart Pro App** — веб-приложение для игры в дартс.

**Важно:** все рассуждения, объяснения и общение — только на русском языке.

---

## 🎯 Цель проекта

Полноценное веб-приложение для игры в дартс:

- **501** (Double Out/In, сеты/леги, undo, bust, average)
- **Cricket** (Classic / American, сеты/леги, боты)
- **Тренировки** (Сектор, Around the Clock)
- **Онлайн-игры** через WebSocket (регистрация, лобби, комнаты, turn timeout)

---

## 🛠 Технологии

| Компонент | Технология |
|-----------|-----------|
| Frontend | Flutter Web (Dart) |
| Backend | Dart Shelf + WebSocket |
| DB | SQLite (WAL mode) |
| Auth | JWT + bcrypt |
| Deploy | Docker + Caddy (HTTPS) на VPS |
| VPS | `192.144.13.217` (nip.io) |
| CI | GitHub Actions → VPS deploy |

---

## 📁 Архитектура (ключевые файлы)

```
lib/
├── main.dart                       # Точка входа, меню
├── models/                         # game_enums, PlayerConfig, GameSettings, CricketSettings
├── data/checkouts.dart             # Таблица чекаутов (2–170)
├── game/
│   ├── game_board_widget.dart      # Табло 501 + панель ввода
│   ├── cricket_board_widget.dart   # Доска Cricket (сектора, полоски, h/t)
│   ├── game_page_501.dart          # Логика 501
│   ├── cricket_game_page.dart      # Логика Cricket
│   ├── game_setup_page.dart        # Настройка 501
│   ├── cricket_setup_page.dart     # Настройка Cricket
│   └── local_game_menu_page.dart   # Меню выбора режима
├── online/
│   ├── services/websocket_backend.dart  # WS клиент
│   ├── services/backend_service.dart    # HTTP клиент
│   ├── auth/login_page.dart
│   ├── lobby_page.dart
│   ├── room_creator_page.dart
│   ├── room_detail_page.dart
│   └── online_game_page_501.dart
├── bots/
│   ├── dart_bot_501.dart           # Боты 501 (5 уровней)
│   ├── dart_throw_simulator.dart   # Симуляция бросков
│   ├── bot_sigma_config.dart       # Конфиг точности
│   ├── bot_context_501.dart        # Контекст для бота
│   └── target_coordinates.dart     # Координаты мишеней
├── training/
│   ├── training_page.dart
│   └── training_widgets.dart
├── services/bot_service.dart
└── widgets/                        # StubPage, CheckOutsPage

server/lib/
├── main.dart                       # HTTP + WebSocket на одном порту
├── auth/auth_handler.dart          # JWT, bcrypt, rate limit
├── db/database.dart                # SQLite (WAL)
├── game/game_room_manager.dart     # Комнаты, синхронизация 501
└── models/                         # User, Room, MatchResult
```

---

## 🎯 Правила игр (важно для кода)

### 501

- **Double Out** — игрок должен закончить на Double (или Bullseye). Если остаётся 1 или 0 после не-Double — bust.
- **Double In** — первый легальный бросок должен быть на Double (опционально).
- **Bust** — если набранная сумма превышает остаток, ход сбрасывается.
- **Сеты/леги** — матч = N сетов, сет = M легов.
- **Average** = (очки × 3) / количество дротиков.
- **Undo** — отмена последнего броска (только локально).

### Cricket

- **Сектора**: 20, 19, 18, 17, 16, 15, Bull (25).
- **Закрытие сектора** — 3 хита (Single=1, Double=2, Triple=3).
- **Bull (25)**: только Single (1) или Double (2). **Triple Bull не существует** — при тапе Bull в TripleMode сбрасывается на Single.
- **Лимит за подход**: максимум **3 сектора** за подход. Считается как `ceil(hits / multiplier)` для каждого сектора, где multiplier = 3 для обычных, 2 для Bull. Сумма не должна превышать 3.
- **Classic**: победа — закрыть все сектора первым.
- **American**: победа — закрыть все сектора И иметь больше или равное количество очков.
- **Очки (American)**: начисляются за каждый хит сверх 3-х в сектор, который уже закрыт у тебя, но не закрыт у соперника.
- **Визуализация**: 3 горизонтальные полоски (stripes) вместо маркеров / X ■. Полоски заполняются зелёным по мере хитов.
- **Розовый фон**: если сектор закрыт у оппонента, но не у текущего игрока — базовая заливка closure-ячейки розовая.
- **h/t колонка**: жёлтые цифры хитов за текущий подход, показывается только у активного игрока.
- **Ход**: только по OK (не автоматически). OK без ввода = промах (lastTurnSummary = "0").

### Тренировки

- **Сектор**: счётчик попаданий в выбранный сектор.
- **Around the Clock**: последовательно 1→20→Bull. Single/Double/Triple на выбор.
- **Classic**: 1→20→Bull, только Single.

---

## ✅ Статус разработки

### Готово

- **501**: сумма/per-dart, undo, bust, double out, сеты/леги, average, checkout-подсказки
- **Боты**: 5 уровней, Double Out/In, свои checkout-таблицы
- **Онлайн**: регистрация, JWT, WebSocket (heartbeat, reconnect, re-auth), лобби, комнаты, матч 501
- **Онлайн: reconnect-диалог** — не показывает форфейт, если соперник вернулся
- **Онлайн: per-dart режим ввода** — переключение сумма/по-дротику через ⚙️
- **Онлайн: turn timeout** — turnDeadline, таймер на клиенте, диалог форфейта
- **Cricket**: Classic/American, полоски, h/t, лимит 3 сектора, розовый фон, totalPoints bar, проверка победы, last approach, avg h/t
- **Тренировки**: Сектор, Around the Clock, Classic
- **Сервер**: SQLite WAL, rate limit (30/10s), graceful shutdown, health check, Docker multi-stage
- **Деплой**: VPS + Docker + Caddy (HTTPS), setup.sh, deploy_vps.ps1

### Нужно сделать

| Что | Где | Описание |
|-----|-----|----------|
| Training: Around/Classic | `lib/training/training_widgets.dart` | process-логика не дописана |
| Онлайн: pendingPlayers | `server/lib/game/game_room_manager.dart` | Не очищается при выходе из комнаты |
| Онлайн: state reconciliation | — | Reconnect не синхронизирует состояние игры |
| Онлайн: per-dart на сервере | — | Сервер хранит только сумму |
| Онлайн: Double Out проверка | — | На сервере нет проверки double out |
| Cricket: боты | — | Нет ботов для Cricket |
| Cricket: онлайн | — | Только локальная игра |
| Cricket: сеты/леги | `lib/game/cricket_game_page.dart` | Нет увеличения legsWon/setsWon |
| Checkouts 41–59 | `lib/data/checkouts.dart` | Только 60–170 |
| Статистика / Настройки | `lib/widgets/stub_page.dart` | Заглушка |
| Баг: вылезающие броски 501 | `lib/game/game_board_widget.dart` | Last dart results перекрывают счёт |

---

## 🐛 Известные баги

1. **501: вылезающие броски** — `lib/game/game_board_widget.dart`: last dart results перекрывают общий счёт
2. **Cricket: подсветка у соперника** — (исправлено: turnHits=0 для неактивного)
3. **Cricket: Triple Bull** — (исправлено: сбрасывается на Single)

---

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
