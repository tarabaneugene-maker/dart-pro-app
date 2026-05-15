import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_service.dart';

/// Онлайн-игра 501
///
/// Адаптирует игровой процесс под WebSocket.
/// Получает события от сервера и отображает счёт.
class OnlineGamePage501 extends StatefulWidget {
  final BackendService backend;
  final RoomState roomState;
  final String playerName;

  const OnlineGamePage501({
    super.key,
    required this.backend,
    required this.roomState,
    required this.playerName,
  });

  @override
  State<OnlineGamePage501> createState() => _OnlineGamePage501State();
}

class _OnlineGamePage501State extends State<OnlineGamePage501> {
  late RoomState _room;
  StreamSubscription? _subscription;
  String? _winnerMessage;

  // Состояние ввода
  int _inputScore = 0;
  String _inputText = '';
  bool _isMyTurn = false;
  int _myIndex = 0;

  @override
  void initState() {
    super.initState();
    _room = widget.roomState;
    _myIndex = _room.players.indexWhere(
      (p) => p.name == widget.playerName,
    );
    if (_myIndex == -1) _myIndex = 0;
    _updateTurn();

    _subscription = widget.backend.events.listen(_handleEvent);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _updateTurn() {
    _isMyTurn = _room.currentPlayerIndex == _myIndex;
  }

  void _handleEvent(ServerEvent event) {
    if (!mounted) return;

    switch (event) {
      case ThrowResultEvent e:
        setState(() {
          _room = RoomState(
            roomId: _room.roomId,
            code: _room.code,
            players: _room.players,
            status: _room.status,
            currentPlayerIndex: e.currentPlayerIndex,
            scores: _room.scores,
            legsWon: _room.legsWon,
            dartsInLeg: e.dartsInLeg,
            lastApproach: e.lastApproach,
          );
          // Обновляем счёт
          _room.scores[e.playerIndex] = e.newScore;
          _updateTurn();
          _inputText = '';
          _inputScore = 0;
        });
        break;

      case LegWonEvent e:
        setState(() {
          _room = RoomState(
            roomId: _room.roomId,
            code: _room.code,
            players: _room.players,
            status: _room.status,
            currentPlayerIndex: _room.currentPlayerIndex,
            scores: [501, 501],
            legsWon: e.scores,
            dartsInLeg: [0, 0],
            lastApproach: [null, null],
          );
          _updateTurn();
        });
        _showLegWonDialog(e.winnerIndex);
        break;

      case MatchWonEvent e:
        setState(() {
          _winnerMessage =
              '${_room.players[e.winnerIndex].name} выиграл матч!';
          _room = RoomState(
            roomId: _room.roomId,
            code: _room.code,
            players: _room.players,
            status: 'finished',
            currentPlayerIndex: _room.currentPlayerIndex,
            scores: _room.scores,
            legsWon: e.scores,
            dartsInLeg: _room.dartsInLeg,
            lastApproach: _room.lastApproach,
          );
        });
        _showMatchWonDialog(e.winnerIndex);
        break;

      case PlayerDisconnectedEvent _:
        _showSnackBar('Соперник отключился');
        break;

      case PlayerTimeoutEvent _:
        _showSnackBar('Соперник потерял соединение');
        break;

      case ErrorEvent e:
        _showSnackBar(e.message);
        break;

      default:
        break;
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showLegWonDialog(int winnerIndex) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Лег выигран!'),
        content: Text('${_room.players[winnerIndex].name} выиграл лег'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }

  void _showMatchWonDialog(int winnerIndex) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Матч завершён!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏆 ${_room.players[winnerIndex].name} победил!'),
            const SizedBox(height: 8),
            Text('Счёт: ${_room.legsWon[0]} - ${_room.legsWon[1]}'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Выход в меню
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  void _submitThrow() {
    if (!_isMyTurn || _inputScore <= 0) return;
    widget.backend.sendThrow(_inputScore);
    setState(() {
      _inputText = '';
      _inputScore = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('501 — ${_room.code}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Строка статуса
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.teal.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text('501 | DO'),
                Text('${_room.legsWon[0]} - ${_room.legsWon[1]}'),
                if (_winnerMessage != null)
                  Text(_winnerMessage!,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          // Карточки игроков
          Expanded(
            child: Row(
              children: [
                _playerCard(0),
                const VerticalDivider(width: 1),
                _playerCard(1),
              ],
            ),
          ),

          // Блок ввода (только если мой ход)
          if (_isMyTurn && _room.status == 'playing')
            _buildInputPanel()
          else if (_room.status == 'playing')
            Container(
              padding: const EdgeInsets.all(24),
              color: Colors.grey.withValues(alpha: 0.1),
              child: const Center(
                child: Text('Ход соперника...',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _playerCard(int index) {
    final isActive = _room.currentPlayerIndex == index;
    final player = _room.players[index];
    final score = _room.scores[index];
    final legs = _room.legsWon[index];
    final last = _room.lastApproach[index];

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? Colors.teal.withValues(alpha: 0.05) : null,
          border: isActive
              ? Border.all(color: Colors.teal, width: 2)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              player.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$score',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.teal : null,
              ),
            ),
            const SizedBox(height: 4),
            Text('Леги: $legs'),
            if (last != null) Text('← $last'),
          ],
        ),
      ),
    );
  }

  Widget _buildInputPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: const Border(top: BorderSide(color: Colors.teal, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Отображение ввода
          Text(
            _inputText.isEmpty ? 'Введите сумму' : _inputText,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Numpad
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (int i = 1; i <= 9; i++)
                _numButton('$i', () => _addDigit(i)),
              _numButton('⌫', () => _removeDigit()),
              _numButton('0', () => _addDigit(0)),
              _numButton('OK', _submitThrow,
                  color: Colors.teal, textColor: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numButton(String label, VoidCallback onPressed,
      {Color? color, Color? textColor}) {
    return SizedBox(
      width: 60,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
        ),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  void _addDigit(int digit) {
    setState(() {
      if (_inputText.length < 3) {
        _inputText += '$digit';
        _inputScore = int.tryParse(_inputText) ?? 0;
      }
    });
  }

  void _removeDigit() {
    setState(() {
      if (_inputText.isNotEmpty) {
        _inputText = _inputText.substring(0, _inputText.length - 1);
        _inputScore = int.tryParse(_inputText) ?? 0;
      }
    });
  }
}
