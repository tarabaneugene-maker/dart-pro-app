import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_settings.dart';
import '../models/game_enums.dart';
import '../models/player_config.dart';
import '../bots/dart_bot_501.dart';

/// Состояние одного игрока в игре 501
class _PlayerGameState {
  int score;
  int legsWon;
  int setsWon;
  List<int> legHistory; // сумма каждого подхода
  int dartsInLeg; // количество брошенных дротиков в текущем леге
  int? lastApproach; // сумма последнего подхода
  double? average;

  _PlayerGameState({required int startScore})
      : score = startScore,
        legsWon = 0,
        setsWon = 0,
        legHistory = [],
        dartsInLeg = 0,
        lastApproach = null,
        average = null;
}

/// Страница игры 501/301
class GamePage501 extends StatefulWidget {
  final GameSettings settings;
  const GamePage501({super.key, required this.settings});

  @override
  State<GamePage501> createState() => _GamePage501State();
}

class _GamePage501State extends State<GamePage501> {
  late List<_PlayerGameState> _players;
  late int _currentPlayerIndex;
  late List<DartBot501?> _bots;
  Timer? _botTimer;
  bool _botThinking = false;

  // --- Состояние ввода (Режим А: Сумма подхода) ---
  String _inputBuffer = '';
  bool _remainderMode = false;

  // --- Состояние ввода (Режим Б: Каждый бросок) ---
  final List<_DartEntry> _dartEntries = [
    _DartEntry(),
    _DartEntry(),
    _DartEntry(),
  ];
  int _currentDartIndex = 0;
  String _selectedModifier = 'S'; // S, D, T

  // --- Undo стек ---
  final List<_UndoEntry> _undoStack = [];

  @override
  void initState() {
    super.initState();
    _currentPlayerIndex = widget.settings.startingPlayerIndex;
    final startScore = widget.settings.startingScore;
    _players = List.generate(
      widget.settings.players.length,
      (_) => _PlayerGameState(startScore: startScore),
    );
    _bots = widget.settings.players.map((p) {
      if (p.isBot) {
        return DartBot501(p.botLevel ?? BotLevel.amateur45_55);
      }
      return null;
    }).toList();
    _checkBotTurn();
  }

  @override
  void dispose() {
    _botTimer?.cancel();
    _botTimer = null;
    super.dispose();
  }

  // ===================================================================
  // ЛОГИКА ИГРЫ
  // ===================================================================

  bool get _isCurrentPlayerBot =>
      widget.settings.players[_currentPlayerIndex].isBot;

  InputMode get _currentInputMode =>
      widget.settings.players[_currentPlayerIndex].inputMode;

  void _checkBotTurn() {
    if (_isCurrentPlayerBot && !_botThinking) _startBotTurn();
  }

  void _startBotTurn() {
    _botThinking = true;
    _botTimer?.cancel();
    _botTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _executeBotThrow();
    });
  }

  void _executeBotThrow() {
    final bot = _bots[_currentPlayerIndex]!;
    final state = _players[_currentPlayerIndex];
    final opponentScores = _players
        .asMap()
        .entries
        .where((e) => e.key != _currentPlayerIndex)
        .map((e) => e.value.score);
    final opponentRemaining = opponentScores.isNotEmpty
        ? opponentScores.reduce((a, b) => a < b ? a : b)
        : state.score;

    final results = bot.throwDarts(
      remainingScore: state.score,
      isDoubleIn: widget.settings.startType == StartType.doubleIn,
      isDoubleOut: widget.settings.finishType == FinishType.doubleOut,
      isFirstDartOfLeg: state.legHistory.isEmpty,
      dartsThrownInLeg: state.legHistory.length,
      opponentRemaining: opponentRemaining,
    );

    _applyBotDarts(results, 0);
  }

  void _applyBotDarts(List<int> darts, int index) {
    if (index >= darts.length) {
      _botThinking = false;
      _nextPlayer();
      return;
    }
    _submitScore(darts[index], isBot: true);
    _botTimer = Timer(const Duration(milliseconds: 600), () {
      _applyBotDarts(darts, index + 1);
    });
  }

  void _submitScore(int value, {required bool isBot}) {
    final state = _players[_currentPlayerIndex];
    final currentScore = state.score;

    // Сохраняем для undo
    _undoStack.add(_UndoEntry(
      playerIndex: _currentPlayerIndex,
      previousScore: currentScore,
      previousLegHistory: List.from(state.legHistory),
      previousDartsInLeg: state.dartsInLeg,
      previousLastApproach: state.lastApproach,
    ));

    // Проверка bust: сумма > остатка
    if (value > currentScore) {
      if (!isBot) {
        _showBustDialog('Сумма превышает остаток ($currentScore)');
      }
      return;
    }

    // Проверка bust: остаток 1 при Double Out
    if (widget.settings.finishType == FinishType.doubleOut &&
        currentScore - value == 1) {
      if (!isBot) {
        _showBustDialog('Остаток 1 — невозможно закрыть при Double Out');
      }
      return;
    }

    // Проверка: при Double Out последний бросок должен быть даблом
    if (widget.settings.finishType == FinishType.doubleOut &&
        currentScore - value == 0 &&
        _currentInputMode == InputMode.oneDart) {
      // Проверяем, что последний введённый бросок — дабл
      final lastEntry = _dartEntries[_currentDartIndex > 0 ? _currentDartIndex - 1 : 0];
      if (!lastEntry.isEmpty && lastEntry.modifier != 'D') {
        if (!isBot) {
          _showBustDialog('Закрытие должно быть Double!');
        }
        return;
      }
    }

    setState(() {
      state.score = currentScore - value;
      state.legHistory.add(value);
      state.lastApproach = value;
      state.dartsInLeg += 3;
      state.average = _calculateAverage(state);
    });

    if (state.score == 0) {
      _endLeg();
      return;
    }

    if (!isBot) _nextPlayer();
  }

  void _showBustDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bust!'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Подтверждаем bust — передаём ход
              final state = _players[_currentPlayerIndex];
              setState(() {
                state.legHistory.add(0);
                state.lastApproach = 0;
                state.dartsInLeg += 3;
              });
              _nextPlayer();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _endLeg() {
    final state = _players[_currentPlayerIndex];
    state.legsWon++;

    // Собираем счёт легов
    final legScores = _players
        .asMap()
        .map((i, p) => MapEntry(i, p.legsWon))
        .values
        .join('-');

    // Проверка на выигрыш матча (по сетам)
    if (widget.settings.sets > 0 && state.setsWon + 1 >= widget.settings.sets) {
      state.setsWon++;
      _showMatchWonDialog(state.setsWon, legScores);
      return;
    }

    // Проверка на выигрыш сета
    if (state.legsWon >= widget.settings.legs) {
      state.setsWon++;
      state.legsWon = 0;
    }

    setState(() {
      final startScore = widget.settings.startingScore;
      for (final p in _players) {
        p.score = startScore;
        p.legHistory.clear();
        p.dartsInLeg = 0;
        p.lastApproach = null;
      }
    });

    _showLegWonDialog(legScores);
  }

  void _showLegWonDialog(String legScores) {
    final winner = widget.settings.players[_currentPlayerIndex].name;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('$winner выиграл лег!'),
        content: Text('Счёт: $legScores'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _nextPlayer();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMatchWonDialog(int setsWon, String legScores) {
    final winner = widget.settings.players[_currentPlayerIndex].name;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('🏆 $winner выиграл матч!'),
        content: Text('Счёт по легам: $legScores\nСетов выиграно: $setsWon'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // Выход из игры
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  void _nextPlayer() {
    setState(() {
      _currentPlayerIndex =
          (_currentPlayerIndex + 1) % widget.settings.players.length;
      _inputBuffer = '';
      _remainderMode = false;
      for (int i = 0; i < 3; i++) {
        _dartEntries[i] = _DartEntry();
      }
      _currentDartIndex = 0;
      _selectedModifier = 'S';
    });
    _checkBotTurn();
  }

  double _calculateAverage(_PlayerGameState state) {
    if (state.legHistory.isEmpty) return 0;
    final total = state.legHistory.fold<int>(0, (a, b) => a + b);
    return total / state.legHistory.length;
  }

  // ===================================================================
  // UNDO
  // ===================================================================

  void _undo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    final state = _players[entry.playerIndex];
    setState(() {
      state.score = entry.previousScore;
      state.legHistory = entry.previousLegHistory;
      state.dartsInLeg = entry.previousDartsInLeg;
      state.lastApproach = entry.previousLastApproach;
      state.average = _calculateAverage(state);
    });
  }

  // ===================================================================
  // ВВОД (Режим А: Сумма подхода)
  // ===================================================================

  void _onNumpadDigit(String digit) {
    setState(() {
      if (_inputBuffer.length < 3) {
        _inputBuffer += digit;
      }
    });
  }

  void _onNumpadClear() {
    setState(() {
      if (_inputBuffer.isNotEmpty) {
        _inputBuffer = _inputBuffer.substring(0, _inputBuffer.length - 1);
      }
    });
  }

  void _onRemainderMode() {
    setState(() {
      _remainderMode = !_remainderMode;
    });
  }

  void _onQuickSum(int value) {
    _submitScore(value, isBot: false);
  }

  void _onSubmitSum() {
    if (_inputBuffer.isEmpty) return;
    final value = int.tryParse(_inputBuffer);
    if (value == null) return;

    if (_remainderMode) {
      // Режим "Остаток": введена разница, вычисляем сумму
      final state = _players[_currentPlayerIndex];
      final computed = state.score - value;
      if (computed > 0) {
        _submitScore(computed, isBot: false);
      }
    } else {
      _submitScore(value, isBot: false);
    }
    setState(() {
      _inputBuffer = '';
      _remainderMode = false;
    });
  }

  // ===================================================================
  // ВВОД (Режим Б: Каждый бросок)
  // ===================================================================

  void _onDartDigit(String digit) {
    final number = int.tryParse(digit);
    if (number == null || number < 0 || number > 25) return;
    if (_currentDartIndex >= 3) return;

    // Bull (25) может быть только Single или Double, не Triple
    final modifier = (number == 25 && _selectedModifier == 'T') ? 'S' : _selectedModifier;

    setState(() {
      // Фиксируем бросок с текущим модификатором
      _dartEntries[_currentDartIndex] = _DartEntry(
        modifier: modifier,
        number: number,
      );
      // Переходим к следующему броску, сбрасываем модификатор
      if (_currentDartIndex < 2) {
        _currentDartIndex++;
        _selectedModifier = 'S';
      }
    });
  }

  void _onDartClear() {
    setState(() {
      if (_currentDartIndex > 0 || !_dartEntries[_currentDartIndex].isEmpty) {
        // Стираем последний введённый бросок
        if (!_dartEntries[_currentDartIndex].isEmpty) {
          _dartEntries[_currentDartIndex] = _DartEntry();
        } else if (_currentDartIndex > 0) {
          _currentDartIndex--;
          _dartEntries[_currentDartIndex] = _DartEntry();
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
    // Проверяем, что хотя бы один бросок введён
    if (_dartEntries.every((e) => e.isEmpty)) return;

    final total = _calculateDartTotal();
    _submitScore(total, isBot: false);

    setState(() {
      for (int i = 0; i < 3; i++) {
        _dartEntries[i] = _DartEntry();
      }
      _currentDartIndex = 0;
      _selectedModifier = 'S';
    });
  }

  int _calculateDartTotal() {
    int total = 0;
    for (final entry in _dartEntries) {
      if (!entry.isEmpty) {
        total += entry.score;
      }
    }
    return total;
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
            // Верхняя часть: плашка + колонки + строка бросков/быстрые суммы
            Expanded(
              flex: 4,
              child: _buildInfoBlock(theme),
            ),
            // Нижняя часть: блок ввода
            Expanded(
              flex: 6,
              child: _currentInputMode == InputMode.threeDarts
                  ? _buildSumInputPanel(theme)
                  : _buildDartInputPanel(theme),
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
                  Expanded(child: _buildInfoBlock(theme)),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: _currentInputMode == InputMode.threeDarts
                  ? _buildSumInputPanel(theme)
                  : _buildDartInputPanel(theme),
            ),
          ],
        ),
      ),
    );
  }

  // ===================================================================
  // СТРОКА СТАТУСА
  // ===================================================================

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
          // Кнопка назад
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Выйти из игры',
          ),
          const SizedBox(width: 4),
          // Параметры игры
          Text(
            '${widget.settings.gameType.name} | '
            '${widget.settings.sets}с | '
            '${widget.settings.legs}л | '
            '${widget.settings.finishType == FinishType.doubleOut ? "DO" : "SO"}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Статистика (заглушка)
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: () {
              // TODO: открыть страницу статистики
            },
            tooltip: 'Статистика',
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // БЛОК ИНФОРМАЦИИ (верхняя половина)
  // ===================================================================

  Widget _buildInfoBlock(ThemeData theme) {
    final activeState = _players[_currentPlayerIndex];
    final activePlayer = widget.settings.players[_currentPlayerIndex];
    final opponentIndex = _currentPlayerIndex == 0 ? 1 : 0;
    final opponentState = _players[opponentIndex];
    final opponentPlayer = widget.settings.players[opponentIndex];

    return Column(
      children: [
        // Плашка активного игрока (компактная)
        _buildActivePlayerBanner(theme, activePlayer, activeState),
        // Две колонки игроков
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _buildPlayerColumn(
                  theme, activePlayer, activeState, true,
                ),
              ),
              Container(
                width: 1,
                color: theme.colorScheme.outlineVariant,
              ),
              Expanded(
                child: _buildPlayerColumn(
                  theme, opponentPlayer, opponentState, false,
                ),
              ),
            ],
          ),
        ),
        // Строка бросков (для Режима Б) или быстрые суммы (для Режима А)
        _buildDartStatusBar(theme),
      ],
    );
  }

  Widget _buildActivePlayerBanner(
    ThemeData theme,
    PlayerConfig player,
    _PlayerGameState state,
  ) {
    final showCheckout = state.score <= 170 && state.score > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  player.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (showCheckout)
                  Text(
                    _getCheckoutHint(state.score),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${state.score}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  String _getCheckoutHint(int score) {
    const checkouts = {
      170: 'T20-T20-DBull',
      167: 'T20-T19-DBull',
      164: 'T20-T18-DBull',
      161: 'T20-T17-DBull',
      160: 'T20-T20-D20',
      158: 'T20-T20-D19',
      157: 'T20-T19-D20',
      156: 'T20-T20-D18',
      155: 'T20-T19-D19',
      154: 'T20-T18-D20',
      153: 'T20-T19-D18',
      152: 'T20-T20-D16',
      151: 'T20-T17-D20',
      150: 'T20-T18-D18',
      149: 'T20-T19-D16',
      148: 'T20-T20-D14',
      147: 'T20-T17-D18',
      146: 'T20-T18-D16',
      145: 'T20-T15-D20',
      144: 'T20-T20-D12',
      143: 'T20-T17-D16',
      142: 'T20-T14-D20',
      141: 'T20-T15-D18',
      140: 'T20-T20-D10',
      139: 'T19-T14-D20',
      138: 'T20-T18-D12',
      137: 'T20-T19-D10',
      136: 'T20-T20-D8',
      135: 'T20-T15-D20',
      134: 'T20-T14-D16',
      133: 'T20-T19-D8',
      132: 'T20-T16-D12',
      131: 'T20-T13-D20',
      130: 'T20-T20-D5',
      129: 'T19-T16-D12',
      128: 'T18-T14-D16',
      127: 'T19-T14-D20',
      126: 'T19-T15-D12',
      125: 'T18-T13-D20',
      124: 'T20-T16-D8',
      123: 'T19-T14-D12',
      122: 'T18-T16-D10',
      121: 'T20-T11-D20',
      120: 'T20-S20-D20',
      119: 'T19-T12-D13',
      118: 'T20-S18-D20',
      117: 'T20-S17-D20',
      116: 'T20-S16-D20',
      115: 'T20-S15-D20',
      114: 'T20-S14-D20',
      113: 'T20-S13-D20',
      112: 'T20-S12-D20',
      111: 'T20-S11-D20',
      110: 'T20-S10-D20',
      109: 'T20-S9-D20',
      108: 'T20-S8-D20',
      107: 'T19-S10-D20',
      106: 'T20-S6-D20',
      105: 'T20-S5-D20',
      104: 'T20-S4-D20',
      103: 'T20-S3-D20',
      102: 'T20-S2-D20',
      101: 'T17-DBull',
      100: 'T20-D20',
      99: 'T19-D21',
      98: 'T20-D19',
      97: 'T19-D20',
      96: 'T20-D18',
      95: 'T19-D19',
      94: 'T18-D20',
      93: 'T19-D18',
      92: 'T20-D16',
      91: 'T17-D20',
      90: 'T20-D15',
      89: 'T19-D16',
      88: 'T20-D14',
      87: 'T17-D18',
      86: 'T18-D16',
      85: 'T15-D20',
      84: 'T20-D12',
      83: 'T17-D16',
      82: 'T14-D20',
      81: 'T19-D12',
      80: 'T20-D10',
      79: 'T19-D11',
      78: 'T18-D12',
      77: 'T19-D10',
      76: 'T20-D8',
      75: 'T17-D12',
      74: 'T14-D16',
      73: 'T19-D8',
      72: 'T16-D12',
      71: 'T13-D16',
      70: 'T20-D5',
      69: 'T19-D6',
      68: 'T20-D4',
      67: 'T17-D8',
      66: 'T10-D18',
      65: 'T15-D10',
      64: 'T16-D8',
      63: 'T13-D12',
      62: 'T10-D16',
      61: 'T15-D8',
      60: 'S20-D20',
      59: 'S19-D20',
      58: 'S18-D20',
      57: 'S17-D20',
      56: 'S16-D20',
      55: 'S15-D20',
      54: 'S14-D20',
      53: 'S13-D20',
      52: 'S12-D20',
      51: 'S11-D20',
      50: 'S10-D20',
      49: 'S9-D20',
      48: 'S8-D20',
      47: 'S7-D20',
      46: 'S6-D20',
      45: 'S5-D20',
      44: 'S4-D20',
      43: 'S3-D20',
      42: 'S2-D20',
      41: 'S1-D20',
      40: 'D20',
      39: 'S7-D16',
      38: 'D19',
      37: 'S5-D16',
      36: 'D18',
      35: 'S3-D16',
      34: 'D17',
      33: 'S1-D16',
      32: 'D16',
      31: 'S15-D8',
      30: 'D15',
      29: 'S13-D8',
      28: 'D14',
      27: 'S11-D8',
      26: 'D13',
      25: 'S9-D8',
      24: 'D12',
      23: 'S7-D8',
      22: 'D11',
      21: 'S5-D8',
      20: 'D10',
      19: 'S3-D8',
      18: 'D9',
      17: 'S1-D8',
      16: 'D8',
      15: 'S7-D4',
      14: 'D7',
      13: 'S5-D4',
      12: 'D6',
      11: 'S3-D4',
      10: 'D5',
      9: 'S1-D4',
      8: 'D4',
      7: 'S3-D2',
      6: 'D3',
      5: 'S1-D2',
      4: 'D2',
      3: 'S1-D1',
      2: 'D1',
    };
    return checkouts[score] ?? 'Закрытие';
  }

  /// Строка бросков (Режим Б) или быстрые суммы (Режим А) — в одну строку
  Widget _buildDartStatusBar(ThemeData theme) {
    if (_currentInputMode == InputMode.threeDarts) {
      // Быстрые суммы в одну строку
      const sums = [45, 60, 81, 85, 100, 140];
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: sums
              .map((v) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _QuickSumButton(
                        value: v,
                        onTap: () => _onQuickSum(v),
                      ),
                    ),
                  ))
              .toList(),
        ),
      );
    } else {
      // Строка бросков в одну строку: 1:__  2:__  3:__  = 0
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            for (int i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Text(
                '${i + 1}:${_dartEntries[i].display}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      i == _currentDartIndex ? FontWeight.bold : FontWeight.normal,
                  color: i == _currentDartIndex
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
            const Spacer(),
            Text(
              '= ${_calculateDartTotal()}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildPlayerColumn(
    ThemeData theme,
    PlayerConfig player,
    _PlayerGameState state,
    bool isActive,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Имя + счётчик легов
          GestureDetector(
            onTap: () {
              // TODO: тоггл average
            },
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    player.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (state.legsWon > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${state.legsWon}л',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Average
          if (state.average != null)
            Text(
              'ср: ${state.average!.toStringAsFixed(1)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const Spacer(),
          // Остаток крупно
          Row(
            children: [
              Text(
                '${state.score}',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: isActive ? theme.colorScheme.primary : null,
                  height: 1.0,
                ),
              ),
              const Spacer(),
              // Дротиков в леге
              Text(
                '⚡${state.dartsInLeg}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Последний подход
          if (state.lastApproach != null)
            Text(
              '← ${state.lastApproach}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  // ===================================================================
  // ПАНЕЛЬ ВВОДА — Режим А: Сумма подхода
  // ===================================================================

  Widget _buildSumInputPanel(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Строка ввода
          _buildInputRow(theme),
          const SizedBox(height: 8),
          // Numpad (крупнее)
          Expanded(
            child: _buildNumpad(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(ThemeData theme) {
    final state = _players[_currentPlayerIndex];
    final displayValue = _remainderMode && _inputBuffer.isNotEmpty
        ? '${state.score} - $_inputBuffer = ${state.score - int.parse(_inputBuffer)}'
        : _inputBuffer.isNotEmpty
            ? _inputBuffer
            : 'Ввод';

    return Row(
      children: [
        // Кнопка Остаток (равноширокая с numpad)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _ActionButton(
              label: 'Ост.',
              isActive: _remainderMode,
              onTap: _onRemainderMode,
              theme: theme,
            ),
          ),
        ),
        // Поле ввода (равноширокое)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                displayValue,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _inputBuffer.isEmpty
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        // Стереть (равноширокий)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _ActionButton(
              label: '⌫',
              isActive: false,
              onTap: _onNumpadClear,
              theme: theme,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNumpad(ThemeData theme) {
    return Column(
      children: [
        // Ряд 1-3
        for (int row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                for (int col = 1; col <= 3; col++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _NumpadButton(
                        label: '${row * 3 + col}',
                        onTap: () => _onNumpadDigit('${row * 3 + col}'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        // Ряд 4: Вернуть, 0, OK
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _ActionButton(
                    label: '↩ Вернуть',
                    isActive: false,
                    onTap: _undo,
                    theme: theme,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _NumpadButton(
                    label: '0',
                    onTap: () => _onNumpadDigit('0'),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _ActionButton(
                    label: 'OK',
                    isActive: true,
                    onTap: _onSubmitSum,
                    theme: theme,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===================================================================
  // ПАНЕЛЬ ВВОДА — Режим Б: Каждый бросок
  // ===================================================================

  Widget _buildDartInputPanel(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Модификаторы
          _buildModifierRow(theme),
          const SizedBox(height: 8),
          // Numpad 1-20 + 25 (крупнее)
          Expanded(
            child: _buildDartNumpad(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildModifierRow(ThemeData theme) {
    return Row(
      children: [
        for (final mod in ['S', 'D', 'T'])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _ActionButton(
                label: mod == 'S'
                    ? 'Single'
                    : mod == 'D'
                        ? 'Double'
                        : 'Triple',
                isActive: _selectedModifier == mod,
                onTap: () => _onModifierSelect(mod),
                theme: theme,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDartNumpad(ThemeData theme) {
    return Column(
      children: [
        // 4 ряда × 5 кнопок (1-20)
        for (int row = 0; row < 4; row++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  for (int col = 0; col < 5; col++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _NumpadButton(
                          label: '${row * 5 + col + 1}',
                          onTap: () => _onDartDigit('${row * 5 + col + 1}'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        // Последний ряд: ↩, 25, 0, Bull, OK
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _ActionButton(
                      label: '↩',
                      isActive: false,
                      onTap: _onDartClear,
                      theme: theme,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _NumpadButton(
                      label: '25',
                      onTap: () => _onDartDigit('25'),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _NumpadButton(
                      label: '0',
                      onTap: () => _onDartDigit('0'),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _NumpadButton(
                      label: 'Bull',
                      onTap: () => _onDartDigit('25'),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _ActionButton(
                      label: 'OK',
                      isActive: true,
                      onTap: _onSubmitDart,
                      theme: theme,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===================================================================
// ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ
// ===================================================================

/// Один бросок в режиме "Каждый бросок"
class _DartEntry {
  String modifier; // 'S', 'D', 'T'
  int number; // 1-25, -1 = не введён (0 — валидное значение)

  _DartEntry({this.modifier = 'S', this.number = -1});

  bool get isEmpty => number == -1;
  int get score {
    switch (modifier) {
      case 'D':
        return number * 2;
      case 'T':
        return number * 3;
      default:
        return number;
    }
  }

  String get display => isEmpty ? '___' : '$modifier$number';
}

class _UndoEntry {
  final int playerIndex;
  final int previousScore;
  final List<int> previousLegHistory;
  final int previousDartsInLeg;
  final int? previousLastApproach;

  _UndoEntry({
    required this.playerIndex,
    required this.previousScore,
    required this.previousLegHistory,
    required this.previousDartsInLeg,
    required this.previousLastApproach,
  });
}

class _QuickSumButton extends StatelessWidget {
  final int value;
  final VoidCallback onTap;

  const _QuickSumButton({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 32,
      child: Material(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NumpadButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NumpadButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 44,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ActionButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Material(
        color: isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isActive
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
