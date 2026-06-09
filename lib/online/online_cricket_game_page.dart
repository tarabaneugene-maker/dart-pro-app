import 'dart:async';
import 'package:flutter/material.dart';
import 'services/backend_service.dart';
import 'services/websocket_backend.dart';
import '../game/cricket_board_widget.dart';
import '../models/game_enums.dart';
import 'lobby_page.dart';

/// Онлайн-игра Cricket
class OnlineCricketGamePage extends StatefulWidget {
  final BackendService backend;
  final RoomState roomState;
  final String playerName;
  final String? userId;
  final int initialTurnDeadline;

  const OnlineCricketGamePage({
    super.key,
    required this.backend,
    required this.roomState,
    required this.playerName,
    this.userId,
    this.initialTurnDeadline = 0,
  });

  @override
  State<OnlineCricketGamePage> createState() => _OnlineCricketGamePageState();
}

class _OnlineCricketGamePageState extends State<OnlineCricketGamePage>
    with WidgetsBindingObserver {
  late RoomState _room;
  StreamSubscription? _subscription;
  String? _winnerMessage;

  // Cricket-состояние
  late CricketVariant _variant;
  List<Map<int, int>> _cricketHits = [];
  List<Map<int, int>> _cricketPoints = [];
  List<int> _cricketTotalPoints = [];

  bool _isMyTurn = false;
  int _myIndex = 0;

  // Ввод
  bool _isTripleMode = false;
  final Map<int, int> _currentTurnHits = {};
  final List<_TurnHitEntry> _turnHistory = [];

  // Таймер хода
  Timer? _turnTimer;
  int _turnSecondsLeft = 120;
  static const int _turnTimeout = 120;

  // Диалог turn_timeout
  bool _showTurnTimeoutDialog = false;
  BuildContext? _turnTimeoutDialogContext;
  bool _turnTimeoutForfeitRequested = false;

  static const int _maxDartsPerTurn = 3;
  static const List<int> cricketSectors = [20, 19, 18, 17, 16, 15, 25];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _room = widget.roomState;

    // Определяем вариант Cricket
    final gt = _room.gameType;
    _variant = gt == 'cricket_american' ? CricketVariant.american : CricketVariant.classic;

    // Инициализируем Cricket-состояние
    _cricketHits = [
      <int, int>{},
      <int, int>{},
    ];
    _cricketPoints = [
      <int, int>{},
      <int, int>{},
    ];
    _cricketTotalPoints = [0, 0];

    // Ищем себя
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
      _turnTimer?.cancel();
      _turnTimer = null;
    } else if (state == AppLifecycleState.resumed) {
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
      case CricketThrowResultEvent e:
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
          _cricketHits = e.cricketHits;
          _cricketPoints = e.cricketPoints;
          _cricketTotalPoints = e.cricketTotalPoints;
          _updateTurn();
          _resetTurnInput();
        });
        _startTurnTimer(turnDeadline: e.turnDeadline);
        break;

      case CricketLegWonEvent e:
        setState(() {
          _room = RoomState(
            roomId: _room.roomId,
            code: _room.code,
            players: _room.players,
            status: _room.status,
            currentPlayerIndex: e.currentPlayerIndex,
            scores: _room.scores,
            legsWon: e.scores,
            dartsInLeg: [0, 0],
            lastApproach: [null, null],
          );
          _cricketHits = e.cricketHits;
          _cricketPoints = e.cricketPoints;
          _cricketTotalPoints = e.cricketTotalPoints;
          _updateTurn();
          _resetTurnInput();
        });
        _startTurnTimer(turnDeadline: e.turnDeadline);
        _showLegWonDialog(e.winnerIndex);
        break;

      case CricketMatchWonEvent e:
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
          _cricketHits = e.cricketHits;
          _cricketPoints = e.cricketPoints;
          _cricketTotalPoints = e.cricketTotalPoints;
        });
        _turnTimer?.cancel();
        _showMatchWonDialog(e.winnerIndex);
        break;

      case TurnTimeoutEvent e:
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
        setState(() {
          _room = e.room;
          _updateTurn();
          _resetTurnInput();
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

  void _resetTurnInput() {
    _currentTurnHits.clear();
    _turnHistory.clear();
    _isTripleMode = false;
  }

  int _getHitCount() => _isTripleMode ? 3 : 1;

  int _sectorMultiplier(int sector) => sector == 25 ? 2 : 3;

  int _usedVirtualDarts() {
    int total = 0;
    for (final entry in _currentTurnHits.entries) {
      final sector = entry.key;
      final hits = entry.value;
      final mult = _sectorMultiplier(sector);
      total += (hits / mult).ceil();
    }
    return total;
  }

  bool _wouldExceedSectorLimit(int sector, int hitsToAdd) {
    final currentHits = _currentTurnHits[sector] ?? 0;
    final newHits = currentHits + hitsToAdd;
    final mult = _sectorMultiplier(sector);
    final newVirtual = (newHits / mult).ceil();
    final otherVirtual = _usedVirtualDarts() -
        (currentHits > 0 ? (currentHits / mult).ceil() : 0);
    return otherVirtual + newVirtual > _maxDartsPerTurn;
  }

  bool _isSectorClosed(int playerIndex, int sector) {
    return (_cricketHits[playerIndex][sector] ?? 0) >= 3;
  }

  bool _canThrowIntoSector(int sector) {
    final allClosed = _isSectorClosed(0, sector) && _isSectorClosed(1, sector);
    if (allClosed) return false;

    final playerHits = _cricketHits[_myIndex][sector] ?? 0;
    final tentativeHits = playerHits + (_currentTurnHits[sector] ?? 0);
    if (tentativeHits >= 3) {
      if (_variant == CricketVariant.classic) return false;
      final opponent = _myIndex == 0 ? 1 : 0;
      if (_isSectorClosed(opponent, sector)) return false;
      return true;
    }
    return true;
  }

  void _onSectorTap(int sector) {
    if (!_isMyTurn) return;
    if (!_canThrowIntoSector(sector)) return;

    int hits = _getHitCount();
    if (sector == 25 && _isTripleMode) {
      hits = 1;
    }

    // Если соперник закрыл сектор — максимум хитов = сколько не хватает до закрытия
    final opponent = _myIndex == 0 ? 1 : 0;
    if (_isSectorClosed(opponent, sector)) {
      final currentTotal = (_cricketHits[_myIndex][sector] ?? 0) + (_currentTurnHits[sector] ?? 0);
      final maxNeeded = (3 - currentTotal).clamp(0, 3);
      if (hits > maxNeeded) hits = maxNeeded;
      if (hits <= 0) return;
    }

    if (_wouldExceedSectorLimit(sector, hits)) return;

    _currentTurnHits[sector] = (_currentTurnHits[sector] ?? 0) + hits;
    _turnHistory.add(_TurnHitEntry(sector: sector, hits: hits));
    _isTripleMode = false;

    setState(() {});
  }

  void _onEraseLastHit() {
    if (!_isMyTurn) return;
    if (_turnHistory.isEmpty) return;

    final last = _turnHistory.removeLast();
    final current = _currentTurnHits[last.sector] ?? 0;
    final newHits = current - last.hits;
    if (newHits <= 0) {
      _currentTurnHits.remove(last.sector);
    } else {
      _currentTurnHits[last.sector] = newHits;
    }

    setState(() {});
  }

  void _onOkTap() {
    if (!_isMyTurn) return;
    if (_currentTurnHits.isEmpty) {
      // Пустой подход — отправляем пустой Map
      _doSendCricketThrow({});
      return;
    }

    // Проверка: не больше 3 дротиков
    final totalVirtual = _usedVirtualDarts();
    if (totalVirtual > 3) return;

    _doSendCricketThrow(Map.from(_currentTurnHits));
  }

  void _doSendCricketThrow(Map<int, int> sectorHits) {
    if (widget.backend is WebSocketBackend) {
      (widget.backend as WebSocketBackend).sendCricketThrow(sectorHits);
    }
    setState(() {
      _resetTurnInput();
    });
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
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final variantLabel =
        _variant == CricketVariant.classic ? 'Classic' : 'American';

    // Строим CricketBoardState
    final diff0 = _cricketTotalPoints[0] - _cricketTotalPoints[1];
    final diff1 = _cricketTotalPoints[1] - _cricketTotalPoints[0];

    final boardState = CricketBoardState(
      players: _room.players.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        final sectors = <int, CricketSectorState>{};
        for (final s in cricketSectors) {
          sectors[s] = CricketSectorState(
            hits: _cricketHits[i][s] ?? 0,
            points: _cricketPoints[i][s] ?? 0,
          );
        }
        return CricketPlayerBoardInfo(
          name: p.name,
          legsWon: _room.legsWon[i],
          setsWon: 0,
          avgHitsPerTurn: null,
          isActive: _room.currentPlayerIndex == i,
          totalPoints: _cricketTotalPoints[i],
          sectors: sectors,
          lastTurnSummary: null,
          pointsDifference: i == 0 ? diff0 : diff1,
          lastTurnHits: {},
        );
      }).toList(),
      currentPlayerIndex: _room.currentPlayerIndex,
      previousPlayerIndex: -1,
      variant: _variant,
      sets: 1,
      legs: _room.gameParams['legs'] as int? ?? 3,
    );

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
          child: Column(
            children: [
              _buildStatusBar(theme, variantLabel),
              // Табло Cricket
              Expanded(
                flex: 4,
                child: CricketBoardWidget(
                  state: boardState,
                  onSectorTap: _onSectorTap,
                  onTripleTap: () {
                    setState(() {
                      _isTripleMode = !_isTripleMode;
                    });
                  },
                  onOkTap: _onOkTap,
                  onEraseLastHit: _onEraseLastHit,
                  currentTurnHits: _currentTurnHits,
                  isTripleMode: _isTripleMode,
                  onPointsToggle: null,
                ),
              ),
              // Нижняя часть
              Expanded(
                flex: 6,
                child: _buildBottomPanel(theme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar(ThemeData theme, String variantLabel) {
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
            '$variantLabel | ${_room.code}',
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

    return Column(
      children: [
        _buildTurnTimerBar(theme),
        // Информация о текущем вводе
        if (_currentTurnHits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Хиты: ${_currentTurnHits.entries.map((e) => '${e.key == 25 ? "Bull" : e.key}-${e.value}').join(" | ")}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        if (!_isMyTurn)
          const Expanded(
            child: Center(
              child: Text(
                'Ход соперника',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
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
// ВСПОМОГАТЕЛЬНЫЕ КЛАССЫ
// ===================================================================

class _TurnHitEntry {
  final int sector;
  final int hits;
  const _TurnHitEntry({required this.sector, required this.hits});
}
