import 'dart:async';
import 'package:flutter/material.dart';
import '../models/cricket_settings.dart';
import '../models/game_enums.dart';
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
  int totalPoints; // общие очки (American)

  _CricketPlayerState({
    required this.name,
    this.isBot = false,
    Map<int, int>? hitsPerSector,
    Map<int, int>? pointsPerSector,
    this.legsWon = 0,
    this.setsWon = 0,
    this.totalDarts = 0,
    this.totalHits = 0,
    this.totalPoints = 0,
  })  : hitsPerSector = hitsPerSector ??
            {20: 0, 19: 0, 18: 0, 17: 0, 16: 0, 15: 0, 25: 0},
        pointsPerSector = pointsPerSector ??
            {20: 0, 19: 0, 18: 0, 17: 0, 16: 0, 15: 0, 25: 0};

  bool isSectorClosed(int sector) => (hitsPerSector[sector] ?? 0) >= 3;

  double? get average {
    if (totalDarts == 0) return null;
    return (totalHits / totalDarts) * 100;
  }

  void addHits(int sector, int count) {
    final current = hitsPerSector[sector] ?? 0;
    hitsPerSector[sector] = current + count;
    totalHits += count;
    totalDarts += count; // каждый hit = 1 дротик
  }

  void addPoints(int sector, int points) {
    final current = pointsPerSector[sector] ?? 0;
    pointsPerSector[sector] = current + points;
    totalPoints += points;
  }

  void resetForNewLeg() {
    hitsPerSector.updateAll((_, __) => 0);
    pointsPerSector.updateAll((_, __) => 0);
    totalDarts = 0;
    totalHits = 0;
    totalPoints = 0;
  }

  CricketPlayerBoardInfo toBoardInfo({required bool isActive}) {
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
      average: average,
      isActive: isActive,
      totalPoints: totalPoints,
      sectors: sectors,
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
  late CricketVariant _variant;

  // Состояние ввода
  bool _isTripleMode = false;
  bool _isDoubleMode = false;

  /// hits за текущий подход (для подсказки)
  final Map<int, int> _currentTurnHits = {};

  /// Сколько дротиков использовано в текущем подходе
  int _dartsUsed = 0;

  /// Результаты последних 3 дротиков (для last approach)
  List<String> _lastDartResults = [];

  /// Максимум дротиков за подход
  static const int _maxDartsPerTurn = 3;

  @override
  void initState() {
    super.initState();
    _variant = widget.settings.cricketVariant;
    _currentPlayerIndex = widget.settings.startingPlayerIndex;
    _players = widget.settings.players.map((p) {
      return _CricketPlayerState(name: p.name, isBot: p.isBot);
    }).toList();
  }

  void _resetTurnInput() {
    _currentTurnHits.clear();
    _dartsUsed = 0;
    _isTripleMode = false;
    _isDoubleMode = false;
  }

  /// Проверка, можно ли ещё кидать
  bool get _canThrow => _dartsUsed < _maxDartsPerTurn;

  /// Проверка, можно ли кидать в сектор
  bool _canThrowIntoSector(int sector) {
    if (!_canThrow) return false;

    // Если сектор закрыт у всех — нельзя
    final allClosed = _players.every((p) => p.isSectorClosed(sector));
    if (allClosed) return false;

    return true;
  }

  /// Сколько hits добавится при текущем тапе
  int _getHitCount() {
    if (_isTripleMode) return 3;
    if (_isDoubleMode) return 2;
    return 1;
  }

  /// Проверка, не превысит ли лимит дротиков
  bool _wouldExceedDartLimit(int hitsToAdd) {
    return _dartsUsed + hitsToAdd > _maxDartsPerTurn;
  }

  /// Обработка тапа на сектор
  void _onSectorTap(int sector) {
    if (!_canThrowIntoSector(sector)) return;

    final hits = _getHitCount();
    if (_wouldExceedDartLimit(hits)) return;

    final player = _players[_currentPlayerIndex];
    final isClosed = player.isSectorClosed(sector);

    // Добавляем hits
    _currentTurnHits[sector] = (_currentTurnHits[sector] ?? 0) + hits;
    _dartsUsed += hits;

    // Формируем строку для last approach
    final sectorLabel = sector == 25 ? 'Bull' : '$sector';
    final modLabel = _isTripleMode
        ? 'T'
        : _isDoubleMode
            ? 'D'
            : '';
    _lastDartResults.add('$modLabel$sectorLabel');

    // Сбрасываем модификаторы
    _isTripleMode = false;
    _isDoubleMode = false;

    setState(() {});

    // Если использовали все дротики — автоматически подтверждаем
    if (_dartsUsed >= _maxDartsPerTurn) {
      _onOkTap();
    }
  }

  /// Подтверждение хода (OK)
  void _onOkTap() {
    if (_dartsUsed == 0) return;

    final player = _players[_currentPlayerIndex];

    // Применяем hits к состоянию игрока
    for (final entry in _currentTurnHits.entries) {
      final sector = entry.key;
      final hits = entry.value;

      // Сколько из этих hits — новые закрытия (до 3)
      final currentHits = player.hitsPerSector[sector] ?? 0;
      final hitsToClose = (currentHits < 3) ? (3 - currentHits).clamp(0, hits) : 0;
      final hitsForPoints = hits - hitsToClose;

      // Добавляем hits
      player.addHits(sector, hits);

      // Если American и есть hits сверх закрытия — начисляем очки
      if (_variant == CricketVariant.american && hitsForPoints > 0) {
        final sectorValue = sector == 25 ? 25 : sector;
        // Каждый hit сверх закрытия даёт очки по номиналу сектора
        // (если это был Triple — 3×, Double — 2×, Single — 1×)
        // Но hits уже разбиты на отдельные единицы, так что считаем по 1
        player.addPoints(sector, sectorValue * hitsForPoints);
      }
    }

    // Переход хода
    setState(() {
      _currentPlayerIndex = (_currentPlayerIndex + 1) % _players.length;
      _resetTurnInput();
    });

    // Проверка на победу
    _checkWinCondition();
  }

  /// Проверка условий победы
  void _checkWinCondition() {
    for (int i = 0; i < _players.length; i++) {
      final p = _players[i];
      final allClosed = cricketSectors.every((s) => p.isSectorClosed(s));

      if (allClosed) {
        if (_variant == CricketVariant.classic) {
          // Classic: кто первый закрыл все — победил
          _showLegWon(i);
          return;
        } else {
          // American: нужно ещё иметь >= очков соперника
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
      _resetTurnInput();
    });
  }

  // ===================================================================
  // BUILD
  // ===================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final boardState = CricketBoardState(
      players: _players
          .asMap()
          .entries
          .map((e) => e.value.toBoardInfo(isActive: e.key == _currentPlayerIndex))
          .toList(),
      currentPlayerIndex: _currentPlayerIndex,
      variant: _variant,
      sets: widget.settings.sets,
      legs: widget.settings.legs,
    );

    return PopScope(
      canPop: true,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _variant == CricketVariant.classic ? 'Classic Cricket' : 'American Cricket',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            // Доска Cricket
            Expanded(
              child: CricketBoardWidget(
                state: boardState,
                onSectorTap: _onSectorTap,
                onTripleTap: () {
                  setState(() {
                    _isTripleMode = !_isTripleMode;
                    _isDoubleMode = false;
                  });
                },
                onDoubleTap: () {
                  setState(() {
                    _isDoubleMode = !_isDoubleMode;
                    _isTripleMode = false;
                  });
                },
                onOkTap: _onOkTap,
                currentTurnHits: _currentTurnHits,
                lastDartResults: _lastDartResults,
                isTripleMode: _isTripleMode,
                isDoubleMode: _isDoubleMode,
              ),
            ),
            // Клавиатура секторов
            _buildSectorKeyboard(theme),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // КЛАВИАТУРА СЕКТОРОВ
  // ===================================================================

  Widget _buildSectorKeyboard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: const Border(
          top: BorderSide(width: 2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ряд 1: 1-7
          Row(
            children: List.generate(7, (i) {
              final sector = i + 1;
              return Expanded(
                child: _sectorKey(sector, theme),
              );
            }),
          ),
          const SizedBox(height: 4),
          // Ряд 2: 8-14
          Row(
            children: List.generate(7, (i) {
              final sector = i + 8;
              return Expanded(
                child: _sectorKey(sector, theme),
              );
            }),
          ),
          const SizedBox(height: 4),
          // Ряд 3: 15-20 + Bull
          Row(
            children: [
              for (int s = 15; s <= 20; s++)
                Expanded(child: _sectorKey(s, theme)),
              Expanded(
                child: _sectorKey(25, theme, label: 'Bull'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Ряд 4: 0 (мимо) + CLEAR
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: _canThrow
                        ? () {
                            _lastDartResults.add('0');
                            _dartsUsed++;
                            setState(() {});
                            if (_dartsUsed >= _maxDartsPerTurn) {
                              _onOkTap();
                            }
                          }
                        : null,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('0 (мимо)',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _resetTurnInput();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('CLEAR',
                        style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectorKey(int sector, ThemeData theme, {String? label}) {
    final canThrow = _canThrowIntoSector(sector);
    final displayLabel = label ?? '$sector';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SizedBox(
        height: 44,
        child: ElevatedButton(
          onPressed: canThrow ? () => _onSectorTap(sector) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canThrow ? null : Colors.grey.shade800,
            disabledBackgroundColor: Colors.grey.shade800,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Text(
            displayLabel,
            style: TextStyle(
              fontSize: 13,
              color: canThrow ? null : Colors.grey.shade500,
            ),
          ),
        ),
      ),
    );
  }
}
