import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_service.dart';
import 'online_game_page_501.dart';

/// Страница просмотра комнаты (для Игрока2)
class RoomDetailPage extends StatefulWidget {
  final BackendService backend;
  final LobbyRoomInfo roomInfo;
  final String playerName;
  final double playerAvg;

  const RoomDetailPage({
    super.key,
    required this.backend,
    required this.roomInfo,
    required this.playerName,
    required this.playerAvg,
  });

  @override
  State<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends State<RoomDetailPage> {
  StreamSubscription? _subscription;
  bool _requested = false;
  String? _statusMessage;

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
      case JoinRequestedEvent _:
        setState(() {
          _requested = true;
          _statusMessage = 'Запрос отправлен, ожидайте...';
        });
        break;
      case GameStartedEvent event:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OnlineGamePage501(
              backend: widget.backend,
              roomState: event.room,
              playerName: widget.playerName,
            ),
          ),
        );
        break;
      case JoinRejectedEvent _:
        setState(() {
          _requested = false;
          _statusMessage = 'Создатель отклонил ваш запрос';
        });
        break;
      case ErrorEvent e:
        setState(() => _statusMessage = e.message);
        break;
      default:
        break;
    }
  }

  void _requestJoin() {
    widget.backend.requestJoin(widget.roomInfo.id, widget.playerName,
        avg: widget.playerAvg);
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.roomInfo;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Комната'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Информация о комнате
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      child: Text(
                        room.creatorName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 28),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      room.creatorName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    _infoRow('Средний набор',
                        room.creatorAvg.toStringAsFixed(1)),
                    const SizedBox(height: 4),
                    _infoRow('Тип игры', room.gameType),
                    const SizedBox(height: 4),
                    _infoRow('Параметры',
                        'Best of ${room.gameParams['legs'] ?? 5}'),
                    const SizedBox(height: 4),
                    _infoRow('Код комнаты', room.code),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Статус
            if (_statusMessage != null)
              Card(
                color: _statusMessage!.contains('отклонил')
                    ? Colors.red.shade50
                    : Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _statusMessage!.contains('отклонил')
                            ? Icons.cancel_outlined
                            : Icons.info_outline,
                        color: _statusMessage!.contains('отклонил')
                            ? Colors.red
                            : Colors.teal,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_statusMessage!)),
                    ],
                  ),
                ),
              ),
            if (_statusMessage != null) const SizedBox(height: 24),

            // Кнопки
            if (!_requested)
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _requestJoin,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Присоединиться',
                      style: TextStyle(fontSize: 16)),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Выйти', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }
}
