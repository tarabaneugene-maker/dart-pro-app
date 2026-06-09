import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_service.dart';
import 'online_game_page_501.dart';
import 'online_cricket_game_page.dart';

/// Страница просмотра комнаты (для Игрока2)
/// При нажатии на комнату в лобби — "проваливаемся" сюда.
/// Видим подробности, кнопка "Присоединиться" отправляет запрос.
/// После принятия создателем — попадаем в игру.
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
          _statusMessage = null;
        });
        break;

      case GameStartedEvent e:
        // Игра началась — проверяем, участвуем ли мы
        final isMyGame = e.room.players.any(
          (p) => p.name == widget.playerName,
        );
        if (isMyGame) {
          // Мы в игре — переходим
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
        } else {
          // Игра началась без нас — показываем диалог и возвращаемся в лобби
          _showGameStartedWithoutUs();
        }
        break;


      case JoinRejectedEvent e:
        setState(() {
          _requested = false;
          _statusMessage = null;
        });
        final creatorName = e.creatorName ?? 'Создатель';
        _showRejectedDialog(creatorName);
        break;

      case ErrorEvent e:
        // Если игра уже началась — диалог с возвратом в лобби
        if (e.message.contains('игра уже началась') ||
            e.message.contains('Комната заполнена') ||
            e.message.contains('уже есть запрос')) {
          _showGameStartedWithoutUs();
        } else {
          setState(() => _statusMessage = e.message);
        }
        break;

      default:
        break;
    }
  }

  void _showRejectedDialog(String creatorName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Запрос отклонён'),
        content: Text('Игрок $creatorName отклонил ваш запрос'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showGameStartedWithoutUs() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Игра уже началась'),
        content: const Text(
          'Игра уже началась. Попробуйте поискать другую в лобби или создать свою.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Возврат в лобби
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _requestJoin() {
    // Сразу показываем "Ожидание игры..." до ответа сервера
    setState(() {
      _requested = true;
      _statusMessage = null;
    });
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
                    const SizedBox(height: 4),
                    _infoRow('Игроков в комнате',
                        '${room.playersCount}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Статус
            if (_statusMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_statusMessage!)),
                    ],
                  ),
                ),
              ),
            if (_statusMessage != null) const SizedBox(height: 24),

            // Кнопки
            SizedBox(
              height: 48,
              child: _requested
                  ? OutlinedButton.icon(
                      onPressed: null, // disabled
                      icon: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      label: const Text('Ожидание игры...',
                          style: TextStyle(fontSize: 16)),
                    )
                  : FilledButton.icon(
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
