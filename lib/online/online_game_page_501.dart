import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_service.dart';
import '../game/game_board_widget.dart';
import '../utils/dart_utils.dart';

/// Онлайн-игра 501
///
/// Использует общие виджеты табло и ввода из game_board_widget.dart.
/// Состояние получает от сервера через WebSocket.
class OnlineGamePage501 extends StatefulWidget {
  final BackendService backend;
  final RoomState roomState;
  final String playerName;
  final String? userId;

  const OnlineGamePage501({
    super.key,
    required this.backend,
    required this.roomState,
    required this.playerName,
    this.userId,
  });

  @override
  State<OnlineGamePage501> createState() => _OnlineGamePage501State();
}

class _OnlineGamePage501State extends State<OnlineGamePage501> {
  late RoomState _room;
  StreamSubscription? _subscription;
  String? _winnerMessage;

  // Состояние ввода (режим суммы)
  String _inputBuffer = '';

  // Состояние ввода (режим каждого броска)
  final List<DartEntryDisplay> _dartEntries = [
    const DartEntryDisplay(),
    const DartEntryDisplay(),
    const DartEntryDisplay(),
  ];
  int _currentDartIndex = 0;
  String _selectedModifier = 'S';

  bool _isMyTurn = false;
  int _myIndex = 0;

  @override
  void initState() {
    super.initState();
    _room = widget.roomState;
    // Ищем себя по userId (если есть), иначе по имени
    if (widget.userId != null && widget.userId!.isNotEmpty) {
      _myIndex = _room.players.indexWhere(
        (p) => p.userId == widget.userId,
      );
    }
    if (_myIndex == -1) {
      _myIndex = _room.players.indexWhere(
        (p) => p.name == widget.playerName,
      );
    }
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
          _room.scores[e.playerIndex] = e.newScore;
          _updateTurn();
          _resetInput();
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
          _resetInput();
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

  void _resetInput() {
    _inputBuffer = '';
    for (int i = 0; i < 3; i++) {
      _dartEntries[i] = const DartEntryDisplay();
    }
    _currentDartIndex = 0;
    _selectedModifier = 'S';
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
              Navigator.of(context).pop();
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // ВВОД (режим суммы)
  // ===================================================================

  void _onSumDigit(String digit) {
    setState(() {
      if (_inputBuffer.length < 3) {
        _inputBuffer += digit;
      }
    });
  }

  void _onSumClear() {
    setState(() {
      if (_inputBuffer.isNotEmpty) {
        _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
      }
    });
  }

  void _onQuickSum(int value) {
    _submitThrow(value);
  }

  void _onSubmitSum() {
    if (_inputBuffer.isEmpty) return;
    final value = int.tryParse(_inputBuffer);
    if (value == null) return;
    _submitThrow(value);
    setState(() {
      _inputBuffer = '';
    });
  }

  void _onRemainder() {
    if (_inputBuffer.isEmpty) return;
    final value = int.tryParse(_inputBuffer);
    if (value == null) return;
    final myScore = _room.scores[_myIndex];
    final computed = myScore - value;
    if (computed > 0) {
      _submitThrow(computed);
    }
    setState(() {
      _inputBuffer = '';
    });
  }

  // ===================================================================
  // ВВОД (режим каждого броска)
  // ===================================================================

  void _onDartDigit(String digit) {
    final number = int.tryParse(digit);
    if (number == null || number < 0 || number > 25) return;
    if (_currentDartIndex >= 3) return;

    final modifier =
        (number == 25 && _selectedModifier == 'T') ? 'S' : _selectedModifier;

    setState(() {
      _dartEntries[_currentDartIndex] = DartEntryDisplay(
        modifier: modifier,
        number: number,
      );
      if (_currentDartIndex < 2) {
        _currentDartIndex++;
        _selectedModifier = 'S';
      }
    });
  }

  void _onDartClear() {
    setState(() {
      if (_currentDartIndex > 0 || !_dartEntries[_currentDartIndex].isEmpty) {
        if (!_dartEntries[_currentDartIndex].isEmpty) {
          _dartEntries[_currentDartIndex] = const DartEntryDisplay();
        } else if (_currentDartIndex > 0) {
          _currentDartIndex--;
          _dartEntries[_currentDartIndex] = const DartEntryDisplay();
        }
        _selectedModifier = 'S';
      }
    });
  }

  void _onModifierSelect(String mod) {
    setState(() {
      _selectedModifier = mod;
    });
  }

  void _onSubmitDart() {
    if (_dartEntries.every((e) => e.isEmpty)) return;

    final total = _dartEntries.fold<int>(0, (sum, e) => sum + e.score);
    _submitThrow(total);

    setState(() {
      for (int i = 0; i < 3; i++) {
        _dartEntries[i] = const DartEntryDisplay();
      }
      _currentDartIndex = 0;
      _selectedModifier = 'S';
    });
  }

  // ===================================================================
  // ОТПРАВКА ХОДА
  // ===================================================================

  void _submitThrow(int score) {
    if (!_isMyTurn || score <= 0) return;
    if (!isValidThreeDartScore(score)) {
      _showSnackBar('Невозможная сумма ($score) для трёх дротиков');
      return;
    }
    widget.backend.sendThrow(score);
    setState(() {
      _inputBuffer = '';
    });
  }

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (isLandscape) {
      return _buildLandscapeLayout(theme);
    }
    return _buildPortraitLayout(theme);
  }

  Widget _buildPortraitLayout(ThemeData theme) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBar(theme),
            // Табло
            Expanded(
              flex: 4,
              child: GameScoreBoard(state: _buildBoardState()),
            ),
            // Нижняя часть: ввод или "Ход соперника"
            Expanded(
              flex: 6,
              child: _buildBottomPanel(theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandscapeLayout(ThemeData theme) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildStatusBar(theme),
                  Expanded(child: GameScoreBoard(state: _buildBoardState())),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: _buildBottomPanel(theme),
            ),
          ],
        ),
      ),
    );
  }

  GameBoardState _buildBoardState() {
    return GameBoardState(
      players: _room.players.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        return PlayerBoardInfo(
          name: p.name,
          score: _room.scores[i],
          legsWon: _room.legsWon[i],
          average: _room.dartsInLeg[i] > 0
              ? (_room.scores[i] / _room.dartsInLeg[i]) * 3
              : null,
          lastApproach: _room.lastApproach[i],
          isActive: _room.currentPlayerIndex == i,
        );
      }).toList(),
      currentPlayerIndex: _room.currentPlayerIndex,
      gameType: '501',
      isDoubleOut: true,
    );
  }

  Widget _buildStatusBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Выйти из игры',
          ),
          const SizedBox(width: 4),
          Text(
            '501 | ${_room.code}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            '${_room.legsWon[0]} - ${_room.legsWon[1]}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_winnerMessage != null) ...[
            const SizedBox(width: 8),
            Text(
              _winnerMessage!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomPanel(ThemeData theme) {
    if (_room.status == 'finished') {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            _winnerMessage ?? 'Игра завершена',
            style: const TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    if (!_isMyTurn) {
      return Container(
        padding: const EdgeInsets.all(24),
        color: Colors.grey.withValues(alpha: 0.1),
        child: const Center(
          child: Text(
            'Ход соперника...',
            style: TextStyle(fontSize: 18),
          ),
        ),
      );
    }

    // Мой ход — показываем панель ввода
    // Определяем режим ввода: для онлайн используем сумму подхода (упрощённо)
    return Column(
      children: [
        // Строка бросков / быстрые суммы
        GameDartStatusBar(
          dartEntries: _dartEntries,
          currentDartIndex: _currentDartIndex,
          isSumMode: true,
          onQuickSum: _onQuickSum,
        ),
        // Панель ввода
        Expanded(
          child: GameDartInputPanel(
            isSumMode: true,
            inputBuffer: _inputBuffer,
            dartEntries: _dartEntries,
            currentDartIndex: _currentDartIndex,
            selectedModifier: _selectedModifier,
            currentScore: _room.scores[_myIndex],
            onDigit: _onSumDigit,
            onClear: _onSumClear,
            onSubmit: _onSubmitSum,
            onRemainder: _onRemainder,
            onUndo: null,
            onModifierSelect: _onModifierSelect,
          ),
        ),
      ],
    );
  }
}
