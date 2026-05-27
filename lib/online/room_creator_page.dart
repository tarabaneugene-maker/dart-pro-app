import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_service.dart';
import 'online_game_page_501.dart';

/// Страница создания комнаты — выбор настроек + создание на сервере
class RoomCreatorPage extends StatefulWidget {
  final BackendService backend;
  final String playerName;
  final bool isPrivate;

  const RoomCreatorPage({
    super.key,
    required this.backend,
    required this.playerName,
    this.isPrivate = false,
  });

  @override
  State<RoomCreatorPage> createState() => _RoomCreatorPageState();
}

class _RoomCreatorPageState extends State<RoomCreatorPage> {
  StreamSubscription? _subscription;
  bool _creating = false;
  String? _error;
  Timer? _createTimer;

  // Настройки (как в офлайн GameSetupPage)
  String _gameType = '501';
  int _sets = 1;
  int _legs = 3;
  String _startType = 'straightIn';   // straightIn / doubleIn
  String _finishType = 'doubleOut';   // doubleOut / straightOut

  @override
  void initState() {
    super.initState();
    _subscription = widget.backend.events.listen(_handleEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _createTimer?.cancel();
    super.dispose();
  }

  void _handleEvent(ServerEvent event) {
    if (!mounted) return;
    switch (event) {
      case RoomCreatedEvent e:
        _createTimer?.cancel();
        _openWaitingRoom(e.code, e.room.roomId);
        break;
      case ErrorEvent e:
        _createTimer?.cancel();
        setState(() {
          _creating = false;
          _error = e.message;
        });
        // C2: если «Не авторизован» — предложить перелогиниться
        if (e.message.contains('Не авторизован') || e.message.contains('не авторизован')) {
          _showReauthSnackBar();
        }
        break;
      default:
        break;
    }
  }

  void _showReauthSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Сессия сброшена. Выйдите и войдите снова'),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {},
        ),
      ),
    );
  }

  Future<void> _createRoom() async {
    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      // createRoom() сам вызывает ensureConnected() + waitForAuth()
      await widget.backend.createRoom(
        widget.playerName,
        isPrivate: widget.isPrivate,
        gameType: _gameType,
        gameParams: {
          'legs': _legs,
          'sets': _sets,
          'startType': _startType,
          'finishType': _finishType,
        },
      );
    } catch (e) {
      setState(() {
        _creating = false;
        _error = e is StateError ? e.message : 'Ошибка: ${e.toString()}';
      });
      return;
    }

    // Таймаут на случай если сервер не ответил
    _createTimer?.cancel();
    _createTimer = Timer(const Duration(seconds: 10), () {
      if (!mounted) return;
      setState(() {
        _creating = false;
        _error = 'Сервер не отвечает. Проверьте соединение и попробуйте снова.';
      });
    });
  }

  void _openWaitingRoom(String code, String roomId) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _WaitingRoomPage(
          backend: widget.backend,
          roomCode: code,
          roomId: roomId,
          playerName: widget.playerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создание игры'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Тип игры
            DropdownButtonFormField<String>(
              initialValue: _gameType,
              decoration: const InputDecoration(
                labelText: 'Тип игры',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '501', child: Text('501')),
                DropdownMenuItem(value: '301', child: Text('301')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _gameType = v);
              },
            ),
            const SizedBox(height: 16),

            // Сеты
            DropdownButtonFormField<int>(
              initialValue: _sets,
              decoration: const InputDecoration(
                labelText: 'Сеты (1-6)',
                border: OutlineInputBorder(),
              ),
              items: List.generate(6, (i) => i + 1)
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _sets = v);
              },
            ),
            const SizedBox(height: 16),

            // Леги
            DropdownButtonFormField<int>(
              initialValue: _legs,
              decoration: const InputDecoration(
                labelText: 'Леги (1-6)',
                border: OutlineInputBorder(),
              ),
              items: List.generate(6, (i) => i + 1)
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _legs = v);
              },
            ),
            const SizedBox(height: 16),

            // Начало
            DropdownButtonFormField<String>(
              initialValue: _startType,
              decoration: const InputDecoration(
                labelText: 'Начало',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'straightIn',
                  child: Text('Straight In'),
                ),
                DropdownMenuItem(
                  value: 'doubleIn',
                  child: Text('Double In'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _startType = v);
              },
            ),
            const SizedBox(height: 16),

            // Финиш
            DropdownButtonFormField<String>(
              initialValue: _finishType,
              decoration: const InputDecoration(
                labelText: 'Финиш',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'doubleOut',
                  child: Text('Double Out'),
                ),
                DropdownMenuItem(
                  value: 'straightOut',
                  child: Text('Straight Out'),
                ),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _finishType = v);
              },
            ),
            const SizedBox(height: 16),

            // Тип комнаты
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      widget.isPrivate ? Icons.lock : Icons.public,
                      color: widget.isPrivate ? Colors.orange : Colors.teal,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.isPrivate
                          ? 'Приватная комната (по коду)'
                          : 'Публичная комната (в лобби)',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Ошибка
            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!)),
                    ],
                  ),
                ),
              ),
            if (_error != null) const SizedBox(height: 16),

            // Кнопка создания
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _creating ? null : _createRoom,
                icon: _creating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: Text(
                  _creating ? 'Создаю...' : 'Создать игру',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// Страница ожидания игроков (показывается после создания комнаты)
class _WaitingRoomPage extends StatefulWidget {
  final BackendService backend;
  final String roomCode;
  final String roomId;
  final String playerName;

  const _WaitingRoomPage({
    required this.backend,
    required this.roomCode,
    required this.roomId,
    required this.playerName,
  });

  @override
  State<_WaitingRoomPage> createState() => _WaitingRoomPageState();
}

class _WaitingRoomPageState extends State<_WaitingRoomPage> {
  StreamSubscription? _subscription;
  RoomPlayerInfo? _pendingPlayer;
  String? _error;
  bool _disconnected = false;
  Timer? _connectionCheckTimer;

  @override
  void initState() {
    super.initState();
    _subscription = widget.backend.events.listen(_handleEvent);
    // Проверка соединения каждые 5 секунд
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (!widget.backend.isConnected && !_disconnected) {
        setState(() {
          _disconnected = true;
          _error = 'Соединение с сервером потеряно. Попытка переподключения...';
        });
      } else if (widget.backend.isConnected && _disconnected) {
        setState(() {
          _disconnected = false;
          _error = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _connectionCheckTimer?.cancel();
    super.dispose();
  }

  void _handleEvent(ServerEvent event) {
    if (!mounted) return;
    switch (event) {
      case JoinRequestEvent e:
        if (e.roomId == widget.roomId) {
          setState(() => _pendingPlayer = e.player);
        }
        break;
      case GameStartedEvent e:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnlineGamePage501(
              backend: widget.backend,
              roomState: e.room,
              playerName: widget.playerName,
              userId: widget.backend.currentUserId,
            ),
          ),
        );
        break;
      case ErrorEvent e:
        setState(() => _error = e.message);
        break;
      default:
        break;
    }
  }

  void _acceptPlayer() {
    widget.backend.acceptJoin(widget.roomId);
  }

  void _rejectPlayer() {
    widget.backend.rejectJoin(widget.roomId);
    setState(() => _pendingPlayer = null);
  }

  void _leaveRoom() {
    widget.backend.leaveRoom();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Моя комната'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _leaveRoom,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Код комнаты
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.wifi_tethering, size: 48, color: Colors.teal),
                    const SizedBox(height: 12),
                    Text(
                      'Код комнаты',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal),
                      ),
                      child: Text(
                        widget.roomCode,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Отправьте этот код, чтобы пригласить игрока',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Ошибка
            if (_error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!)),
                    ],
                  ),
                ),
              ),
            if (_error != null) const SizedBox(height: 16),

            // Ожидание
            if (_pendingPlayer == null) ...[
              const Spacer(),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Ожидание игроков...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Когда кто-то захочет присоединиться, вы увидите его здесь',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
            ] else ...[
              // Информация об игроке, запросившем присоединение
              Text(
                'Игрок хочет присоединиться',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        child: Text(
                          _pendingPlayer!.name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _pendingPlayer!.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.trending_up,
                              size: 20, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            'Средний набор: ${_pendingPlayer!.avg.toStringAsFixed(1)}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Кнопки
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _rejectPlayer,
                        icon: const Icon(Icons.close),
                        label: const Text('Отказать'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: _acceptPlayer,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Начать игру'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
