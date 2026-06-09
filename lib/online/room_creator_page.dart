import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_service.dart';
import 'services/websocket_backend.dart';
import 'online_game_page_501.dart';
import 'online_cricket_game_page.dart';

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

  // Категория игры: 'x01' или 'cricket'
  String _gameCategory = 'x01';
  // Подтип внутри категории
  String _gameSubtype = '501'; // для x01: '501'|'301'; для cricket: 'classic'|'american'
  int _sets = 1;
  int _legs = 3;
  String _startType = 'straightIn';
  String _finishType = 'doubleOut';
  bool _isPrivate = false;

  bool get _isX01 => _gameCategory == 'x01';

  String get _computedGameType {
    if (_gameCategory == 'cricket') {
      return 'cricket_$_gameSubtype';
    }
    return _gameSubtype; // '501' или '301'
  }

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
      final params = <String, dynamic>{
        'legs': _legs,
        'sets': _sets,
      };
      if (_isX01) {
        params['startType'] = _startType;
        params['finishType'] = _finishType;
      }
      await widget.backend.createRoom(
        widget.playerName,
        isPrivate: _isPrivate,
        gameType: _computedGameType,
        gameParams: params,
      );
    } catch (e) {
      setState(() {
        _creating = false;
        _error = e is StateError ? e.message : 'Ошибка: ${e.toString()}';
      });
      return;
    }

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
            // Первый дропдаун — категория игры
            DropdownButtonFormField<String>(
              value: _gameCategory,
              decoration: const InputDecoration(
                labelText: 'Категория',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'x01', child: Text('X01')),
                DropdownMenuItem(value: 'cricket', child: Text('Cricket')),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _gameCategory = v;
                    // Сброс подтипа при смене категории
                    _gameSubtype = v == 'cricket' ? 'classic' : '501';
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Второй дропдаун — подтип (зависит от категории)
            DropdownButtonFormField<String>(
              value: _gameSubtype,
              decoration: const InputDecoration(
                labelText: 'Вариант',
                border: OutlineInputBorder(),
              ),
              items: _isX01
                  ? const [
                      DropdownMenuItem(value: '501', child: Text('501')),
                      DropdownMenuItem(value: '301', child: Text('301')),
                    ]
                  : const [
                      DropdownMenuItem(value: 'classic', child: Text('Classic')),
                      DropdownMenuItem(value: 'american', child: Text('American')),
                    ],
              onChanged: (v) {
                if (v != null) setState(() => _gameSubtype = v);
              },
            ),
            const SizedBox(height: 16),

            // Сеты и Леги в один ряд
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _sets,
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _legs,
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
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Начало и Финиш — только для X01
            if (_isX01)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _startType,
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _finishType,
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
                  ),
                ],
              ),
            if (_isX01) const SizedBox(height: 16),

            // Тип комнаты — Dropdown
            DropdownButtonFormField<bool>(
              value: _isPrivate,
              decoration: const InputDecoration(
                labelText: 'Тип комнаты',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              items: const [
                DropdownMenuItem(value: false, child: Text('Публичная (в лобби)')),
                DropdownMenuItem(value: true, child: Text('Приватная (по коду)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _isPrivate = v);
              },
            ),
            const SizedBox(height: 24),

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

            SizedBox(
              width: double.infinity,
              height: 48,
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
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
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
  List<RoomPlayerInfo> _pendingPlayers = [];
  String? _error;
  bool _disconnected = false;
  Timer? _connectionCheckTimer;

  @override
  void initState() {
    super.initState();
    _subscription = widget.backend.events.listen(_handleEvent);
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
          setState(() {
            if (!_pendingPlayers.any((p) => p.userId == e.player.userId)) {
              _pendingPlayers.add(e.player);
            }
          });
        }
        break;
      case PendingPlayersUpdateEvent e:
        if (e.roomId == widget.roomId) {
          setState(() => _pendingPlayers = e.players);
        }
        break;
      case GameStartedEvent e:
        final isCricket = e.room.gameType == 'cricket_classic' || e.room.gameType == 'cricket_american';
        if (isCricket) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => OnlineCricketGamePage(
                backend: widget.backend,
                roomState: e.room,
                playerName: widget.playerName,
                userId: widget.backend.currentUserId,
                initialTurnDeadline: e.turnDeadline,
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => OnlineGamePage501(
                backend: widget.backend,
                roomState: e.room,
                playerName: widget.playerName,
                userId: widget.backend.currentUserId,
                initialTurnDeadline: e.turnDeadline,
              ),
            ),
          );
        }
        break;

      case ErrorEvent e:
        setState(() => _error = e.message);
        break;
      default:
        break;
    }
  }

  void _acceptPlayer(RoomPlayerInfo player) {
    if (widget.backend is WebSocketBackend) {
      (widget.backend as WebSocketBackend)
          .acceptPlayer(widget.roomId, player.userId);
    } else {
      widget.backend.acceptJoin(widget.roomId);
    }
  }

  void _rejectPlayer(RoomPlayerInfo player) {
    if (widget.backend is WebSocketBackend) {
      (widget.backend as WebSocketBackend)
          .rejectPlayer(widget.roomId, player.userId);
    } else {
      widget.backend.rejectJoin(widget.roomId);
    }
    setState(() => _pendingPlayers.removeWhere((p) => p.userId == player.userId));
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
                    const Icon(Icons.wifi_tethering,
                        size: 48, color: Colors.teal),
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

            // Список ожидающих игроков
            if (_pendingPlayers.isEmpty) ...[
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
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      'Игроки хотят присоединиться',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    ..._pendingPlayers.map((player) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  child: Text(
                                    player.name[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        player.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.trending_up,
                                              size: 16, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Средний: ${player.avg.toStringAsFixed(1)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  tooltip: 'Отказать',
                                  onPressed: () => _rejectPlayer(player),
                                ),
                                const SizedBox(width: 4),
                                FilledButton.icon(
                                  onPressed: () => _acceptPlayer(player),
                                  icon: const Icon(Icons.play_arrow,
                                      size: 18),
                                  label: const Text('Начать'),
                                ),
                              ],
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
