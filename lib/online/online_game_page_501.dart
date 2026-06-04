import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_service.dart';
import '../game/game_board_widget.dart';
import '../utils/dart_utils.dart';
import 'lobby_page.dart';

/// Онлайн-игра 501
///
/// Использует общие виджеты табло и ввода из game_board_widget.dart.
/// Состояние получает от сервера через WebSocket.
class OnlineGamePage501 extends StatefulWidget {
  final BackendService backend;
  final RoomState roomState;
  final String playerName;
  final String? userId;
  final int initialTurnDeadline;

  const OnlineGamePage501({
    super.key,
    required this.backend,
    required this.roomState,
    required this.playerName,
    this.userId,
    this.initialTurnDeadline = 0,
  });


  @override
  State<OnlineGamePage501> createState() => _OnlineGamePage501State();
}

class _OnlineGamePage501State extends State<OnlineGamePage501>
    with WidgetsBindingObserver {
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

  // Режим ввода (сумма / каждый бросок)
  bool _isSumMode = true;

  // Результаты дротиков последнего подхода (для per-dart режима)
  List<DartEntryDisplay> _lastDartResults = [];

  // Таймер хода
  Timer? _turnTimer;
  int _turnSecondsLeft = 120;
  static const int _turnTimeout = 120;


  // Диалог turn_timeout
  bool _showTurnTimeoutDialog = false;
  BuildContext? _turnTimeoutDialogContext;
  bool _turnTimeoutForfeitRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    // Запускаем таймер с initialTurnDeadline (если есть)
    if (widget.initialTurnDeadline > 0) {
      _startTurnTimer(turnDeadline: widget.initialTurnDeadline);
    }

    _subscription = widget.backend.events.listen(_handleEvent);


  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    _turnTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // При блокировке экрана — приостанавливаем таймер
      _turnTimer?.cancel();
      _turnTimer = null;
    } else if (state == AppLifecycleState.resumed) {
      // При разблокировке — возобновляем таймер
      if (_turnTimer == null && _room.status != 'finished') {
        _startTurnTimer();
      }
    }
  }



  void _updateTurn() {
    _isMyTurn = _room.currentPlayerIndex == _myIndex;
  }

  void _startTurnTimer({int? turnDeadline}) {
    _turnTimer?.cancel();
    if (turnDeadline != null && turnDeadline > 0) {
      _turnSecondsLeft = ((turnDeadline - DateTime.now().millisecondsSinceEpoch) / 1000).ceil().clamp(0, _turnTimeout);
    } else {
      _turnSecondsLeft = _turnTimeout;
    }
    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _turnSecondsLeft--;
      });
      if (_turnSecondsLeft <= 0) {
        timer.cancel();
      }
    });
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
        _startTurnTimer(turnDeadline: e.turnDeadline);
        break;

      case LegWonEvent e:
        setState(() {
          _room = RoomState(
            roomId: _room.roomId,
            code: _room.code,
            players: _room.players,
            status: _room.status,
            currentPlayerIndex: e.currentPlayerIndex,
            scores: [501, 501],
            legsWon: e.scores,
            dartsInLeg: [0, 0],
            lastApproach: [null, null],
          );
          _updateTurn();
          _resetInput();
        });
        _startTurnTimer(turnDeadline: e.turnDeadline);

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
        _turnTimer?.cancel();
        _showMatchWonDialog(e.winnerIndex);
        break;

      case TurnTimeoutEvent e:
        // Соперник не ходит 2+ минуты — показываем диалог
        if (!_showTurnTimeoutDialog && !_turnTimeoutForfeitRequested) {
          _showTurnTimeoutDialog = true;
          _showTurnTimeoutDialogWidget(e.turnDeadline);
        }
        break;


      case OpponentForfeitEvent e:
        _turnTimer?.cancel();
        _closeTurnTimeoutDialog();
        if (e.winnerIndex == _myIndex) {
          _showOpponentForfeitDialog(isWinner: true, reason: e.reason);
        } else {
          _showOpponentForfeitDialog(isWinner: false, reason: e.reason);
        }
        break;

      case GameResumeEvent e:
        // Обновляем состояние игры после переподключения
        // Запускаем таймер с turnDeadline от сервера
        setState(() {
          _room = e.room;
          _updateTurn();
          _resetInput();
        });
        _startTurnTimer(turnDeadline: e.turnDeadline);
        break;




      case ErrorEvent e:
        _showSnackBar(e.message);
        break;

      default:
        break;
    }
  }

  void _closeTurnTimeoutDialog() {
    if (_turnTimeoutDialogContext != null) {
      try {
        Navigator.of(_turnTimeoutDialogContext!).pop();
      } catch (_) {}
      _turnTimeoutDialogContext = null;
    }
    setState(() {
      _showTurnTimeoutDialog = false;
    });
  }

  void _showTurnTimeoutDialogWidget(int turnDeadline) {

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _turnTimeoutDialogContext = ctx;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Text('Соперник не ходит'),
          content: const Text(
            'Соперник превысил лимит времени на ход.\n'
            'У вас есть 60 секунд, чтобы запросить победу.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _turnTimeoutForfeitRequested = true;
                widget.backend.sendForfeitRequest();
                _closeTurnTimeoutDialog();
              },
              child: const Text('Завершить игру (победа)'),
            ),
            TextButton(
              onPressed: () {
                _closeTurnTimeoutDialog();
              },
              child: const Text('Подождать'),
            ),
          ],
        );
      },
    );
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
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  void _showLegWonDialog(int winnerIndex) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Лег выигран!'),
        content: Text('${_room.players[winnerIndex].name} выиграл лег'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
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
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
              _goToLobby();
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('В лобби'),
          ),
        ],
      ),
    );
  }

  void _showOpponentForfeitDialog({required bool isWinner, required String reason}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(isWinner ? 'Победа!' : 'Поражение'),
        content: Text(
          isWinner
              ? 'Соперник прекратил игру. Ваша победа!'
              : 'Вы прекратили игру. Техническое поражение.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _goToLobby();
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('В лобби'),
          ),
        ],
      ),
    );
  }

  void _goToLobby() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LobbyPage(
          backend: widget.backend,
          displayName: widget.playerName,
        ),
      ),
      (route) => false,
    );
  }

  Future<bool> _onWillPop() async {
    if (_room.status == 'finished') return true;

    if (!mounted) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Покинуть игру?'),
        content: const Text(
          'Будет засчитано техническое поражение.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Покинуть игру'),
          ),
        ],
      ),
    );

    if (result == true) {
      widget.backend.leaveRoom();
      return true;
    }
    return false;
  }

  // ===================================================================
  // ВВОД (режим суммы)
  // ===================================================================

  void _onSumDigit(String digit) {
    if (!_isMyTurn) return;
    setState(() {
      if (_inputBuffer.length < 3) {
        _inputBuffer += digit;
      }
    });
  }

  void _onSumClear() {
    if (!_isMyTurn) return;
    setState(() {
      if (_inputBuffer.isNotEmpty) {
        _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
      }
    });
  }

  void _onQuickSum(int value) {
    if (!_isMyTurn) return;
    _submitThrow(value);
  }

  void _onSubmitSum() {
    if (!_isMyTurn) return;
    if (_inputBuffer.isEmpty) return;
    final value = int.tryParse(_inputBuffer);
    if (value == null) return;
    _submitThrow(value);
    setState(() {
      _inputBuffer = '';
    });
  }

  void _onRemainder() {
    if (!_isMyTurn) return;
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
        isSet: true,
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
    // Сохраняем результаты дротиков для отображения на табло
    _lastDartResults = List.from(_dartEntries);
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

    final myScore = _room.scores[_myIndex];
    final isLegWinning = score == myScore;

    if (isLegWinning) {
      // Показываем диалог выбора количества дротиков
      _showDartsUsedDialog(score);
    } else {
      _doSendThrow(score, null);
    }
  }

  void _showDartsUsedDialog(int score) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Закрытие лега'),
        content: const Text('Сколько дротиков использовано?'),
        actions: [
          for (int d = 1; d <= 3; d++)
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _doSendThrow(score, d);
              },
              child: Text('$d'),
            ),
        ],
      ),
    );
  }

  void _doSendThrow(int score, int? dartsUsed) {
    widget.backend.sendThrow(score, dartsUsed: dartsUsed);
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

    return PopScope(
      canPop: _room.status == 'finished',
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: isLandscape
              ? _buildLandscapeLayout(theme)
              : _buildPortraitLayout(theme),
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(ThemeData theme) {
    return Column(
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
    );
  }

  Widget _buildLandscapeLayout(ThemeData theme) {
    return Row(
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
    );
  }

  GameBoardState _buildBoardState() {
    return GameBoardState(
      players: _room.players.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        final darts = _room.dartsInLeg[i];
        final score = _room.scores[i];
        return PlayerBoardInfo(
          name: p.name,
          score: score,
          legsWon: _room.legsWon[i],
          average: darts > 0
              ? ((501 - score) / darts) * 3
              : null,
          lastApproach: _room.lastApproach[i],
          dartsInLeg: darts,
          isActive: _room.currentPlayerIndex == i,
          // Показываем результаты дротиков только для себя в per-dart режиме
          lastDartResults: (i == _myIndex && !_isSumMode)
              ? _lastDartResults
              : [],
        );
      }).toList(),
      currentPlayerIndex: _room.currentPlayerIndex,
      gameType: '501',
      isDoubleOut: true,
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Настройки игры',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Режим ввода',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _InputModeOption(
                      icon: Icons.numbers,
                      label: 'Сумма подхода',
                      isSelected: _isSumMode,
                      onTap: () {
                        setState(() { _isSumMode = true; });
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InputModeOption(
                      icon: Icons.sports_kabaddi,
                      label: 'Каждый бросок',
                      isSelected: !_isSumMode,
                      onTap: () {
                        setState(() { _isSumMode = false; });
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Закрыть'),
                ),
              ),
            ],
          ),
        );
      },
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
            onPressed: () {
              if (_room.status == 'finished') {
                Navigator.of(context).pop();
              } else {
                _onWillPop().then((shouldPop) {
                  if (shouldPop && mounted) {
                    Navigator.of(context).pop();
                  }
                });
              }
            },
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
          const SizedBox(width: 12),
          // Кнопка настроек
          IconButton(
            icon: const Icon(Icons.settings, size: 28),
            onPressed: _showSettingsSheet,
            tooltip: 'Настройки',
          ),
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

    // Всегда показываем панель ввода, даже если не наш ход
    return Column(
      children: [
        // Плашка таймера хода
        _buildTurnTimerBar(theme),
        // Строка бросков / быстрые суммы
        GameDartStatusBar(
          dartEntries: _dartEntries,
          currentDartIndex: _currentDartIndex,
          isSumMode: _isSumMode,
          onQuickSum: _isSumMode ? _onQuickSum : null,
        ),
        // Панель ввода
        Expanded(
          child: GameDartInputPanel(
            isSumMode: _isSumMode,
            inputBuffer: _inputBuffer,
            dartEntries: _dartEntries,
            currentDartIndex: _currentDartIndex,
            selectedModifier: _selectedModifier,
            currentScore: _room.scores[_myIndex],
            onDigit: _isSumMode ? _onSumDigit : _onDartDigit,
            onClear: _isSumMode ? _onSumClear : _onDartClear,
            onSubmit: _isSumMode ? _onSubmitSum : _onSubmitDart,
            onRemainder: _isSumMode ? _onRemainder : null,
            onUndo: null,
            onModifierSelect: _isSumMode ? null : _onModifierSelect,
          ),
        ),
      ],
    );
  }

  Widget _buildTurnTimerBar(ThemeData theme) {
    final minutes = _turnSecondsLeft ~/ 60;
    final seconds = _turnSecondsLeft % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    final isUrgent = _turnSecondsLeft < 30;
    final progress = _turnSecondsLeft / _turnTimeout;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isUrgent
          ? Colors.red.withValues(alpha: 0.12)
          : Colors.grey.withValues(alpha: 0.08),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isMyTurn ? Icons.sports_kabaddi : Icons.hourglass_empty,
                size: 16,
                color: isUrgent ? Colors.red : null,
              ),
              const SizedBox(width: 6),
              Text(
                _isMyTurn ? 'Ваш ход' : 'Ход соперника',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isUrgent ? Colors.red : null,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: isUrgent ? Colors.red : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          LinearProgressIndicator(
            value: progress,
            color: isUrgent ? Colors.red : null,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ
// ===================================================================

/// Виджет выбора режима ввода в BottomSheet
class _InputModeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _InputModeOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
