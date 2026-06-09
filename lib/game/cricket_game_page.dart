import 'dart:async';
import 'package:flutter/material.dart';
import '../models/cricket_settings.dart';
import '../models/game_enums.dart';
import '../bots/dart_bot_cricket.dart';
import '../services/bot_service.dart';
import 'cricket_board_widget.dart';

// ===================================================================
// СОСТОЯНИЕ ИГРОКА В CRICKET
// ===================================================================

class _CricketPlayerState {
  final String name;
  final bool isBot;

  /// hits per sector: 20,19,18,17,16,15,25(Bull)
  final Map<int, int> hitsPerSector;

  /// points per sector (только American)
  final Map<int, int> pointsPerSector;

  int legsWon;
  int setsWon;
  int totalDarts;
  int totalHits;
  int totalTurns;
  int totalPoints;

  /// Строка последнего подхода: "20 - 6 | 19 - 3"
  String? lastTurnSummary;

  /// Хиты последнего подхода (для отображения серым у неактивного игрока)
  Map<int, int> lastTurnHits;

  _CricketPlayerState({
    required this.name,
    this.isBot = false,
    Map<int, int>? hitsPerSector,
    Map<int, int>? pointsPerSector,
  })  : legsWon = 0,
        setsWon = 0,
        totalDarts = 0,
        totalHits = 0,
        totalTurns = 0,
        totalPoints = 0,
        lastTurnSummary = null,
        lastTurnHits = {},
        hitsPerSector = hitsPerSector ??
            {20: 0, 19: 0, 18: 0, 17: 0, 16: 0, 15: 0, 25: 0},
        pointsPerSector = pointsPerSector ??
            {20: 0, 19: 0, 18: 0, 17: 0, 16: 0, 15: 0, 25: 0};

  bool isSectorClosed(int sector) => (hitsPerSector[sector] ?? 0) >= 3;

  double? get avgHitsPerTurn {
    if (totalTurns == 0) return null;
    return totalHits / totalTurns;
  }

  void addHits(int sector, int count) {
    final current = hitsPerSector[sector] ?? 0;
    hitsPerSector[sector] = current + count;
    totalHits += count;
    totalDarts += count;
  }

  void removeHits(int sector, int count) {
    final current = hitsPerSector[sector] ?? 0;
    hitsPerSector[sector] = (current - count).clamp(0, 999);
    totalHits = (totalHits - count).clamp(0, 9999);
    totalDarts = (totalDarts - count).clamp(0, 9999);
  }

  void addPoints(int sector, int points) {
    final current = pointsPerSector[sector] ?? 0;
    pointsPerSector[sector] = current + points;
    totalPoints += points;
  }

  void removePoints(int sector, int points) {
    final current = pointsPerSector[sector] ?? 0;
    pointsPerSector[sector] = (current - points).clamp(0, 9999);
    totalPoints = (totalPoints - points).clamp(0, 99999);
  }

  void resetForNewLeg() {
    hitsPerSector.updateAll((_, _) => 0);
    pointsPerSector.updateAll((_, _) => 0);
    totalDarts = 0;
    totalHits = 0;
    totalTurns = 0;
    totalPoints = 0;
    lastTurnSummary = null;
  }

  CricketPlayerBoardInfo toBoardInfo({
    required bool isActive,
    int? pointsDifference,
    int? projectedPoints,
  }) {
    final sectors = <int, CricketSectorState>{};
    for (final s in cricketSectors) {
      sectors[s] = CricketSectorState(
        hits: hitsPerSector[s] ?? 0,
        points: pointsPerSector[s] ?? 0,
      );
    }
    return CricketPlayerBoardInfo(
      name: name,
      legsWon: legsWon,
      setsWon: setsWon,
      avgHitsPerTurn: avgHitsPerTurn,
      isActive: isActive,
      totalPoints: projectedPoints ?? totalPoints,
      sectors: sectors,
      lastTurnSummary: lastTurnSummary,
      pointsDifference: pointsDifference,
      lastTurnHits: lastTurnHits,
    );
  }
}

// ===================================================================
// СТРАНИЦА ИГРЫ CRICKET
// ===================================================================

class CricketGamePage extends StatefulWidget {
  final CricketSettings settings;

  const CricketGamePage({super.key, required this.settings});

  @override
  State<CricketGamePage> createState() => _CricketGamePageState();
}

class _CricketGamePageState extends State<CricketGamePage> {
  late List<_CricketPlayerState> _players;
  late int _currentPlayerIndex;
  int _previousPlayerIndex = -1;
  late CricketVariant _variant;

  bool _isTripleMode = false;

  /// hits за текущий подход
  final Map<int, int> _currentTurnHits = {};

  /// История тапов в текущем подходе: sector + hits
  final List<_TurnHitEntry> _turnHistory = [];

  /// Снапшот состояния соперника перед его ходом (для undo)
  _PlayerSnapshot? _opponentSnapshot;

  /// Показывать разницу очков вместо тотала (по умолчанию true)
  bool _showDifference = true;

  /// Бот сейчас "думает" — блокируем ввод
  bool _isBotThinking = false;

  /// Кэш ботов по индексу игрока
  final Map<int, DartBotCricket> _botCache = {};

  static const int _maxDartsPerTurn = 3;

  @override
  void initState() {
    super.initState();
    _variant = widget.settings.cricketVariant;
    _currentPlayerIndex = widget.settings.startingPlayerIndex;
    _players = widget.settings.players.map((p) {
      return _CricketPlayerState(name: p.name, isBot: p.isBot);
    }).toList();

    // Если первый игрок — бот, запускаем его ход после сборки
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerBotTurnIfNeeded();
    });
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

  /// Считает projected очки для игрока с учётом текущего ввода (live preview)
  int _getProjectedPoints(int playerIndex) {
    final p = _players[playerIndex];
    if (playerIndex != _currentPlayerIndex || _currentTurnHits.isEmpty) {
      return p.totalPoints;
    }
    int projected = p.totalPoints;
    for (final entry in _currentTurnHits.entries) {
      final sector = entry.key;
      final hits = entry.value;
      final currentHits = p.hitsPerSector[sector] ?? 0;
      final opponent = _players[(_currentPlayerIndex + 1) % _players.length];
      final opponentClosed = opponent.isSectorClosed(sector);

      if (_variant == CricketVariant.american) {
        final hitsToClose =
            (currentHits < 3) ? (3 - currentHits).clamp(0, hits) : 0;
        final hitsForPoints = hits - hitsToClose;
        if (hitsForPoints > 0 && !opponentClosed) {
          final sectorValue = sector == 25 ? 25 : sector;
          projected += sectorValue * hitsForPoints;
        }
      }
    }
    return projected;
  }

  bool _canThrowIntoSector(int sector) {
    final allClosed = _players.every((p) => p.isSectorClosed(sector));
    if (allClosed) return false;

    final player = _players[_currentPlayerIndex];
    final tentativeHits =
        (player.hitsPerSector[sector] ?? 0) + (_currentTurnHits[sector] ?? 0);
    if (tentativeHits >= 3) {
      // Уже закрыто с учётом текущего подхода
      if (_variant == CricketVariant.classic) return false; // Classic — очков нет
      final opponent = _players[(_currentPlayerIndex + 1) % _players.length];
      if (opponent.isSectorClosed(sector)) return false; // Соперник закрыл → очков не будет
      // American, соперник не закрыл — можно тапать для очков
      return true;
    }
    return true;
  }

  void _onSectorTap(int sector) {
    if (_isBotThinking) return;
    if (!_canThrowIntoSector(sector)) return;

    int hits = _getHitCount();

    // Triple не работает с Bull
    if (sector == 25 && _isTripleMode) {
      hits = 1;
    }

    // Если соперник закрыл сектор — максимум хитов = сколько не хватает до закрытия
    final opponent = _players[(_currentPlayerIndex + 1) % _players.length];
    if (opponent.isSectorClosed(sector)) {
      final player = _players[_currentPlayerIndex];
      final currentTotal = (player.hitsPerSector[sector] ?? 0) + (_currentTurnHits[sector] ?? 0);
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
    if (_isBotThinking) return;
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

  void _onUndoOpponent() {
    if (_opponentSnapshot == null) return;

    final snapshot = _opponentSnapshot!;
    final opponent = _players[snapshot.playerIndex];

    opponent.hitsPerSector
        ..clear()
        ..addAll(snapshot.hitsPerSector);
    opponent.pointsPerSector
        ..clear()
        ..addAll(snapshot.pointsPerSector);
    opponent.totalHits = snapshot.totalHits;
    opponent.totalDarts = snapshot.totalDarts;
    opponent.totalPoints = snapshot.totalPoints;
    opponent.totalTurns = snapshot.totalTurns;
    opponent.lastTurnSummary = snapshot.lastTurnSummary;

    setState(() {
      _previousPlayerIndex = _currentPlayerIndex;
      _currentPlayerIndex = snapshot.playerIndex;
      _resetTurnInput();
    });

    _opponentSnapshot = null;
  }

  void _saveOpponentSnapshot() {
    final oppIndex = (_currentPlayerIndex + 1) % _players.length;
    final opp = _players[oppIndex];
    _opponentSnapshot = _PlayerSnapshot(
      playerIndex: oppIndex,
      hitsPerSector: Map.from(opp.hitsPerSector),
      pointsPerSector: Map.from(opp.pointsPerSector),
      totalHits: opp.totalHits,
      totalDarts: opp.totalDarts,
      totalPoints: opp.totalPoints,
      totalTurns: opp.totalTurns,
      lastTurnSummary: opp.lastTurnSummary,
    );
  }

  void _onOkTap() {
    if (_isBotThinking) return;
    final player = _players[_currentPlayerIndex];

    if (_currentTurnHits.isNotEmpty) {
      final parts = <String>[];
      for (final entry in _currentTurnHits.entries) {
        final sector = entry.key;
        final hits = entry.value;
        final sectorLabel = sector == 25 ? 'Bull' : '$sector';
        parts.add('$sectorLabel-$hits');
      }
      player.lastTurnSummary = parts.join(' | ');

      for (final entry in _currentTurnHits.entries) {
        final sector = entry.key;
        final hits = entry.value;

        final currentHits = player.hitsPerSector[sector] ?? 0;
        final opponent = _players[(_currentPlayerIndex + 1) % _players.length];
        final opponentClosed = opponent.isSectorClosed(sector);
        final myClosed = currentHits >= 3;

        // Определяем, сколько хитов идёт в зачёт (totalHits/totalDarts/avg)
        int hitsForStats;
        if (myClosed && opponentClosed) {
          // Оба закрыли — ни очков, ни хитов
          hitsForStats = 0;
        } else if (opponentClosed && !myClosed) {
          // Соперник закрыл, я нет — в зачёт идёт MIN(осталось до закрытия, сколько сделал)
          final needToClose = 3 - currentHits;
          hitsForStats = needToClose.clamp(0, hits);
        } else {
          // Сектор открыт (у обоих или только у меня закрыт) — все хиты в зачёт
          hitsForStats = hits;
        }

        player.addHits(sector, hitsForStats);

        // Очки (American): начисляются за хиты сверх 3, если я закрыл, а соперник — нет
        if (_variant == CricketVariant.american) {
          final hitsToClose =
              (currentHits < 3) ? (3 - currentHits).clamp(0, hits) : 0;
          final hitsForPoints = hits - hitsToClose;
          if (hitsForPoints > 0 && !opponentClosed) {
            final sectorValue = sector == 25 ? 25 : sector;
            player.addPoints(sector, sectorValue * hitsForPoints);
          }
        }
      }

      player.totalTurns++;
    } else {
      player.lastTurnSummary = '0';
      player.totalTurns++;
      player.totalDarts += 3;
    }

    // Сохраняем хиты подхода для отображения серым у неактивного игрока
    player.lastTurnHits = Map.from(_currentTurnHits);

    _saveOpponentSnapshot();

    setState(() {
      _previousPlayerIndex = _currentPlayerIndex;
      _currentPlayerIndex = (_currentPlayerIndex + 1) % _players.length;
      _resetTurnInput();
    });

    _checkWinCondition();
    _triggerBotTurnIfNeeded();
  }

  /// Запустить ход бота, если следующий игрок — бот
  void _triggerBotTurnIfNeeded() {
    if (_isBotThinking) return;
    final nextPlayer = _players[_currentPlayerIndex];
    if (!nextPlayer.isBot) return;

    _isBotThinking = true;

    // Небольшая пауза, чтобы игрок увидел смену хода
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _executeBotTurn();
    });
  }

  /// Выполнить ход бота
  void _executeBotTurn() {
    final botPlayer = _players[_currentPlayerIndex];
    if (!botPlayer.isBot) {
      _isBotThinking = false;
      return;
    }

    // Получаем или создаём бота
    final bot = _botCache.putIfAbsent(
      _currentPlayerIndex,
      () {
        final config = widget.settings.players[_currentPlayerIndex];
        return BotService.createBotCricket(config.botLevel ?? BotLevel.amateur45_55);
      },
    );

    final opponent = _players[(_currentPlayerIndex + 1) % _players.length];

    // Бот делает бросок
    final botResult = bot.throwTurnWithContext(
      myHits: botPlayer.hitsPerSector,
      opponentHits: opponent.hitsPerSector,
      variant: _variant,
    );

    // Заполняем _currentTurnHits результатом бота
    _currentTurnHits
      ..clear()
      ..addAll(botResult);

    // Сохраняем историю для erase (не используется для бота, но для консистентности)
    _turnHistory.clear();
    for (final entry in botResult.entries) {
      _turnHistory.add(_TurnHitEntry(sector: entry.key, hits: entry.value));
    }

    _isBotThinking = false;

    // Вызываем _onOkTap для обработки хода
    _onOkTap();
  }

  void _checkWinCondition() {
    for (int i = 0; i < _players.length; i++) {
      final p = _players[i];
      final allClosed = cricketSectors.every((s) => p.isSectorClosed(s));

      if (allClosed) {
        if (_variant == CricketVariant.classic) {
          _showLegWon(i);
          return;
        } else {
          final opponent = _players[1 - i];
          if (p.totalPoints >= opponent.totalPoints) {
            _showLegWon(i);
            return;
          }
        }
      }
    }
  }

  void _showLegWon(int winnerIndex) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Лег выигран!'),
        content: Text('${_players[winnerIndex].name} выиграл лег'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startNewLeg();
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }

  void _startNewLeg() {
    setState(() {
      for (final p in _players) {
        p.resetForNewLeg();
      }
      _currentPlayerIndex = (_currentPlayerIndex + 1) % _players.length;
      _previousPlayerIndex = -1;
      _opponentSnapshot = null;
      _resetTurnInput();
    });
    _triggerBotTurnIfNeeded();
  }

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final sets = widget.settings.sets;
    final legs = widget.settings.legs;
    final variantLabel =
        _variant == CricketVariant.classic ? 'Classic' : 'American';

    // Считаем разницу очков для каждого игрока
    final diff0 = _players.length >= 2
        ? _players[0].totalPoints - _players[1].totalPoints
        : 0;
    final diff1 = _players.length >= 2
        ? _players[1].totalPoints - _players[0].totalPoints
        : 0;

    final boardState = CricketBoardState(
      players: _players
          .asMap()
          .entries
          .map((e) => e.value.toBoardInfo(
                isActive: e.key == _currentPlayerIndex,
                pointsDifference:
                    _showDifference ? (e.key == 0 ? diff0 : diff1) : null,
                projectedPoints: _getProjectedPoints(e.key),
              ))
          .toList(),
      currentPlayerIndex: _currentPlayerIndex,
      previousPlayerIndex: _previousPlayerIndex,
      variant: _variant,
      sets: sets,
      legs: legs,
    );

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              '$variantLabel • $sets set${sets > 1 ? 's' : ''}, $legs leg${legs > 1 ? 's' : ''}'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              onPressed: _opponentSnapshot != null ? _onUndoOpponent : null,
              tooltip: 'Откатить ход соперника',
            ),
          ],
        ),
        body: CricketBoardWidget(
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
          onPointsToggle: () {
            setState(() {
              _showDifference = !_showDifference;
            });
          },
        ),
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

class _PlayerSnapshot {
  final int playerIndex;
  final Map<int, int> hitsPerSector;
  final Map<int, int> pointsPerSector;
  final int totalHits;
  final int totalDarts;
  final int totalPoints;
  final int totalTurns;
  final String? lastTurnSummary;

  const _PlayerSnapshot({
    required this.playerIndex,
    required this.hitsPerSector,
    required this.pointsPerSector,
    required this.totalHits,
    required this.totalDarts,
    required this.totalPoints,
    required this.totalTurns,
    this.lastTurnSummary,
  });
}
