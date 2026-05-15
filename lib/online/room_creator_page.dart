import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_service.dart';
import 'online_game_page_501.dart';

/// Страница создателя комнаты — ожидание заявок + отказ/начало
class RoomCreatorPage extends StatefulWidget {
  final BackendService backend;
  final String roomCode;
  final String playerName;

  const RoomCreatorPage({
    super.key,
    required this.backend,
    required this.roomCode,
    required this.playerName,
  });

  @override
  State<RoomCreatorPage> createState() => _RoomCreatorPageState();
}

class _RoomCreatorPageState extends State<RoomCreatorPage> {
  StreamSubscription? _subscription;
  RoomPlayerInfo? _pendingPlayer;
  String? _roomId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = widget.backend.events.listen(_handleEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleEvent(ServerEvent event) {
    if (!mounted) return;
    switch (event) {
      case RoomCreatedEvent e:
        setState(() => _roomId = e.room.roomId);
        break;
      case JoinRequestEvent e:
        setState(() {
          _roomId ??= e.roomId;
          _pendingPlayer = e.player;
        });
        break;
      case GameStartedEvent e:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnlineGamePage501(
              backend: widget.backend,
              roomState: e.room,
              playerName: widget.playerName,
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
    if (_roomId == null) return;
    widget.backend.acceptJoin(_roomId!);
  }

  void _rejectPlayer() {
    if (_roomId == null) return;
    widget.backend.rejectJoin(_roomId!);
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
