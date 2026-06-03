# 🎯 Dart Pro App

Flutter Web + Dart сервер. Дартс: 501, Cricket, тренировки, онлайн.

**Стек:** Flutter Web → Dart сервер → SQLite → WebSocket → Docker + Caddy  
**VPS:** `192.144.13.217` (nip.io), health: `GET /health`

---

## 📁 Структура

```
lib/
├── main.dart               # Точка входа, меню
├── models/                  # game_enums, PlayerConfig, GameSettings, CricketSettings
├── data/checkouts.dart      # Таблица чекаутов (2–170)
├── game/                    # 501: меню, настройка, доска, ввод; Cricket: только настройка
├── online/                  # Auth (JWT), лобби, комнаты, WebSocket, онлайн-матч 501
├── bots/                    # 5 уровней, симуляция бросков, Double Out/In
├── training/                # Сектор, Around the Clock (2 варианта)
├── services/bot_service.dart
└── widgets/                 # Табло, панель ввода, CheckOutsPage

server/lib/
├── main.dart                # HTTP + WebSocket на одном порту
├── auth/                    # JWT, bcrypt, rate limit
├── db/                      # SQLite (WAL)
├── game/                    # Комнаты, синхронизация 501
└── models/                  # User, Room, MatchResult
```

## ✅ Готово

- **501**: сумма/per-dart, undo, bust, double out, сеты/леги, average, checkout-подсказки
- **Боты**: 5 уровней, Double Out/In, свои checkout-таблицы
- **Онлайн**: регистрация, JWT, WebSocket (heartbeat, reconnect, re-auth), лобби, комнаты, матч 501
- **Онлайн: reconnect-диалог** — не показывает форфейт, если соперник вернулся
- **Онлайн: per-dart режим ввода** — переключение сумма/по-дротику через ⚙️ в статус-баре
- **Тренировки**: Сектор (счётчик попаданий), Around the Clock (выбор Single/Double/Triple), Classic 1→20→Bull
- **Сервер**: SQLite WAL, rate limit (30/10s), graceful shutdown, health check, Docker multi-stage
- **Деплой**: VPS + Docker + Caddy (HTTPS авто), скрипт setup.sh

## ⚠️ Частично / Требует доработки

| Что | Статус |
|-----|--------|
| **Cricket** | Настройка есть, игровой процесс — заглушка |
| **Training: Around/Classic** | Интерфейс есть, process-логика не дописана (TODO) |
| **Онлайн: turn timeout** | Нет — игрок может висеть бесконечно |
| **Онлайн: pendingPlayers** | Не очищается при выходе из комнаты |
| **Онлайн: state reconciliation** | Нет — reconnect не синхронизирует состояние |
| **Онлайн: per-dart на сервере** | Клиент умеет, но сервер хранит только сумму — соперник не видит отдельные дротики |
| **Онлайн: Double Out проверка** | На сервере нет — клиент локально не проверяет (кроме локальной игры) |
| **Статистика / Настройки** | StubPage |
| `lib/data/checkouts.dart` | Только 60–170, нет 41–59 |

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

*30.05.2026*
