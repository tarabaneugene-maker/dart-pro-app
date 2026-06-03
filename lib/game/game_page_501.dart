import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_settings.dart';
import '../models/game_enums.dart';
import '../bots/dart_bot_501.dart';
import '../bots/dart_throw_simulator.dart';
import '../utils/dart_utils.dart';
import 'game_board_widget.dart';

/// Состояние одного игрока в игре 501
class _PlayerGameState {
  int score;
  int legsWon;
  int setsWon;
  List<int> legHistory; // сумма каждого подхода
  int dartsInLeg; // количество брошенных дротиков в текущем леге
  int? lastApproach; // сумма последнего подхода
  double? average;
  int totalScore; // всего набрано очков за матч
  int totalDarts; // всего брошено дротиков за матч
  List<DartEntryDisplay> lastApproachDarts; // результаты дротиков последнего подхода

  _PlayerGameState({required int startScore})
      : score = startScore,
        legsWon = 0,
        setsWon = 0,
        legHistory = [],
        dartsInLeg = 0,
        lastApproach = null,
        average = null,
        totalScore = 0,
        totalDarts = 0,
        lastApproachDarts = [];
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

  // --- Состояние ввода (Режим Б: Каждый бросок) ---
  final List<DartEntryDisplay> _dartEntries = [
    const DartEntryDisplay(),
    const DartEntryDisplay(),
    const DartEntryDisplay(),
  ];
  int _currentDartIndex = 0;
  String _selectedModifier = 'S';

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

  void _applyBotDarts(List<ThrowResult> darts, int index) {
    if (index >= darts.length) {
      // Записываем сумму подхода (сумма всех дротиков в этом подходе)
      final state = _players[_currentPlayerIndex];
      final approachSum = darts.fold<int>(0, (sum, d) => sum + d.score);
      // Проверяем, не был ли bust (если bust — lastApproach уже 0)
      if (state.lastApproach == null || state.lastApproach != 0) {
        state.lastApproach = approachSum;
      }
      _botThinking = false;
      _nextPlayer();
      return;
    }
    _submitBotDart(darts[index]);
    _botTimer = Timer(const Duration(milliseconds: 600), () {
      _applyBotDarts(darts, index + 1);
    });
  }

  /// Преобразовать ThrowResult в DartEntryDisplay
  DartEntryDisplay _throwResultToDisplay(ThrowResult result) {
    if (result.score == 0) {
      return const DartEntryDisplay(isSet: true, number: 0, modifier: 'S');
    }
    String modifier;
    if (result.multiplier == 2) {
      modifier = 'D';
    } else if (result.multiplier == 3) {
      modifier = 'T';
    } else {
      modifier = 'S';
    }
    return DartEntryDisplay(
      modifier: modifier,
      number: result.segment,
      isSet: true,
    );
  }

  /// Применить один дротик бота (каждый дротик = +1 к счётчикам)
  void _submitBotDart(ThrowResult result) {
    final state = _players[_currentPlayerIndex];
    final currentScore = state.score;
    final value = result.score;

    // Если это первый дротик в подходе — очищаем lastApproachDarts
    if (state.legHistory.length % 3 == 0) {
      state.lastApproachDarts = [];
    }

    // Сохраняем для undo
    _undoStack.add(_UndoEntry(
      playerIndex: _currentPlayerIndex,
      previousScore: currentScore,
      previousLegHistory: List.from(state.legHistory),
      previousDartsInLeg: state.dartsInLeg,
      previousLastApproach: state.lastApproach,
      previousTotalScore: state.totalScore,
      previousTotalDarts: state.totalDarts,
      previousLastApproachDarts: List.from(state.lastApproachDarts),
    ));

    // Проверка bust: сумма > остатка
    if (value > currentScore) {
      // Бот bust — просто записываем 0
      setState(() {
        state.legHistory.add(0);
        state.lastApproach = 0;
        state.dartsInLeg += 1;
        state.totalDarts += 1;
        state.average = _calculateAverage(state);
        state.lastApproachDarts.add(_throwResultToDisplay(result));
      });
      return;
    }

    // Проверка bust: остаток 1 при Double Out
    if (widget.settings.finishType == FinishType.doubleOut &&
        currentScore - value == 1) {
      setState(() {
        state.legHistory.add(0);
        state.lastApproach = 0;
        state.dartsInLeg += 1;
        state.totalDarts += 1;
        state.average = _calculateAverage(state);
        state.lastApproachDarts.add(_throwResultToDisplay(result));
      });
      return;
    }

    setState(() {
      state.score = currentScore - value;
      state.legHistory.add(value);
      state.lastApproach = value;
      state.dartsInLeg += 1;
      state.totalScore += value;
      state.totalDarts += 1;
      state.average = _calculateAverage(state);
      state.lastApproachDarts.add(_throwResultToDisplay(result));
    });

    if (state.score == 0) {
      // Бот закрыл лег — считаем сколько дротиков использовано в этом подходе
      final dartsUsed = state.dartsInLeg;
      _finishLegWithDarts(dartsUsed);
    }
  }

  void _submitScore(int value, {required bool isBot, bool skipFinish = false}) {
    final state = _players[_currentPlayerIndex];
    final currentScore = state.score;

    // Сохраняем для undo
    _undoStack.add(_UndoEntry(
      playerIndex: _currentPlayerIndex,
      previousScore: currentScore,
      previousLegHistory: List.from(state.legHistory),
      previousDartsInLeg: state.dartsInLeg,
      previousLastApproach: state.lastApproach,
      previousTotalScore: state.totalScore,
      previousTotalDarts: state.totalDarts,
    ));

    // Проверка: сумма должна быть достижима тремя дротиками
    if (!isValidThreeDartScore(value)) {
      if (!isBot) {
        _showErrorDialog('Невозможная сумма ($value) для трёх дротиков');
      }
      return;
    }

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
      state.totalScore += value;
      state.totalDarts += 3;
      state.average = _calculateAverage(state);
      // В режиме суммы — сбрасываем per-dart результаты
      if (_currentInputMode == InputMode.threeDarts) {
        state.lastApproachDarts = [];
      }
    });

    if (state.score == 0) {
      if (skipFinish) {
        // В per-dart режиме _onSubmitDart сам вызовет _finishLegWithDarts
        return;
      }
      // Для бота или sum-mode — используем общее кол-во дротиков в леге
      _finishLegWithDarts(state.dartsInLeg);
      return;
    }

    if (!isBot && !skipFinish) _nextPlayer();
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Ошибка ввода'),
        content: Text(message),
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

  void _showBustDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('Bust!'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final state = _players[_currentPlayerIndex];
              setState(() {
                state.legHistory.add(0);
                state.lastApproach = 0;
                state.dartsInLeg += 3;
                state.totalDarts += 3;
                state.average = _calculateAverage(state);
              });
              _nextPlayer();
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

  void _finishLegWithDarts(int totalDartsInLeg) {
    final state = _players[_currentPlayerIndex];
    // Для человека: было +3 в _submitScore, откатываем и ставим правильное
    // Для бота: уже посчитано по +1 за дротик, корректируем
    if (!_isCurrentPlayerBot) {
      state.totalDarts -= 3;
      state.totalDarts += totalDartsInLeg;
    }
    state.average = _calculateAverage(state);
    _endLeg(dartsUsed: totalDartsInLeg);
  }

  void _endLeg({int dartsUsed = 3}) {
    final state = _players[_currentPlayerIndex];
    state.legsWon++;

    final legScores = _players
        .asMap()
        .map((i, p) => MapEntry(i, p.legsWon))
        .values
        .join('-');

    if (state.legsWon >= widget.settings.legs) {
      state.setsWon++;
      state.legsWon = 0;
    }

    if (state.setsWon >= widget.settings.sets) {
      _showMatchWonDialog(state.setsWon, legScores);
      return;
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

    _showLegWonDialog(legScores, dartsUsed: dartsUsed);
  }

  void _showLegWonDialog(String legScores, {int dartsUsed = 3}) {
    final winner = widget.settings.players[_currentPlayerIndex].name;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text('$winner закрыл лег за $dartsUsed дротика!'),
        content: Text('Счёт: $legScores'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _nextPlayer();
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

  void _showMatchWonDialog(int setsWon, String legScores) {
    final winner = widget.settings.players[_currentPlayerIndex].name;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text('🏆 $winner выиграл матч!'),
        content: Text('Счёт по легам: $legScores\nСетов выиграно: $setsWon'),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
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
      _resetInput();
    });
    _checkBotTurn();
  }

  void _resetInput() {
    _inputBuffer = '';
    for (int i = 0; i < 3; i++) {
      _dartEntries[i] = const DartEntryDisplay();
    }
    _currentDartIndex = 0;
    _selectedModifier = 'S';
    // Сбрасываем per-dart результаты при смене игрока
    _players[_currentPlayerIndex].lastApproachDarts = [];
  }

  double _calculateAverage(_PlayerGameState state) {
    if (state.totalDarts == 0) return 0;
    return (state.totalScore / state.totalDarts) * 3;
  }

  // ===================================================================
  // UNDO
  // ===================================================================

  void _undo() {
    if (_undoStack.isEmpty) return;
    final entry = _undoStack.removeLast();
    final state = _players[entry.playerIndex];
    setState(() {
      _currentPlayerIndex = entry.playerIndex;
      state.score = entry.previousScore;
      state.legHistory = entry.previousLegHistory;
      state.dartsInLeg = entry.previousDartsInLeg;
      state.lastApproach = entry.previousLastApproach;
      state.totalScore = entry.previousTotalScore;
      state.totalDarts = entry.previousTotalDarts;
      state.average = _calculateAverage(state);
      state.lastApproachDarts = List.from(entry.previousLastApproachDarts);
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

  void _onQuickSum(int value) {
    _submitScore(value, isBot: false);
  }

  void _onSubmitSum() {
    if (_inputBuffer.isEmpty) return;
    final value = int.tryParse(_inputBuffer);
    if (value == null) return;
    _submitScore(value, isBot: false);
    setState(() {
      _inputBuffer = '';
    });
  }

  void _onRemainder() {
    if (_inputBuffer.isEmpty) return;
    final value = int.tryParse(_inputBuffer);
    if (value == null) return;
    final state = _players[_currentPlayerIndex];
    final computed = state.score - value;
    if (computed > 0) {
      _submitScore(computed, isBot: false);
    }
    setState(() {
      _inputBuffer = '';
    });
  }

  // ===================================================================
  // ВВОД (Режим Б: Каждый бросок)
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
    // Считаем реальное количество непустых дротиков в этом подходе
    final realDartsCount = _dartEntries.where((e) => e.isSet).length;

    // Сохраняем результаты дротиков в состояние игрока
    final state = _players[_currentPlayerIndex];
    state.lastApproachDarts = List.from(_dartEntries);

    // Если закрытие — передаём реальное количество дротиков
    final wasLegClosed = state.score - total == 0;

    if (wasLegClosed && _currentInputMode == InputMode.oneDart) {
      // В per-dart режиме: _submitScore не будет вызывать _finishLegWithDarts
      // (skipFinish), мы сами скорректируем dartsInLeg и вызовем
      _submitScore(total, isBot: false, skipFinish: true);
      final stateAfter = _players[_currentPlayerIndex];
      if (stateAfter.score == 0) {
        // _submitScore добавил +3, откатываем и ставим реальное
        stateAfter.totalDarts -= 3;
        stateAfter.totalDarts += realDartsCount;
        stateAfter.dartsInLeg -= 3;
        stateAfter.dartsInLeg += realDartsCount;
        stateAfter.average = _calculateAverage(stateAfter);
        _finishLegWithDarts(stateAfter.dartsInLeg);
      }
    } else {
      _submitScore(total, isBot: false);
    }

    setState(() {
      for (int i = 0; i < 3; i++) {
        _dartEntries[i] = const DartEntryDisplay();
      }
      _currentDartIndex = 0;
      _selectedModifier = 'S';
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
            Expanded(
              flex: 3,
              child: GameScoreBoard(state: _buildBoardState()),
            ),
            GameDartStatusBar(
              dartEntries: _dartEntries,
              currentDartIndex: _currentDartIndex,
              isSumMode: _currentInputMode == InputMode.threeDarts,
              onQuickSum: _currentInputMode == InputMode.threeDarts
                  ? _onQuickSum
                  : null,
            ),
            Expanded(
              flex: 6,
              child: _currentInputMode == InputMode.threeDarts
                  ? GameDartInputPanel(
                      isSumMode: true,
                      inputBuffer: _inputBuffer,
                      dartEntries: _dartEntries,
                      currentDartIndex: _currentDartIndex,
                      selectedModifier: _selectedModifier,
                      currentScore: _players[_currentPlayerIndex].score,
                      onDigit: _onNumpadDigit,
                      onClear: _onNumpadClear,
                      onSubmit: _onSubmitSum,
                      onRemainder: _onRemainder,
                      onUndo: _undo,
                      onModifierSelect: _onModifierSelect,
                    )
                  : GameDartInputPanel(
                      isSumMode: false,
                      inputBuffer: _inputBuffer,
                      dartEntries: _dartEntries,
                      currentDartIndex: _currentDartIndex,
                      selectedModifier: _selectedModifier,
                      currentScore: _players[_currentPlayerIndex].score,
                      onDigit: _onDartDigit,
                      onClear: _onDartClear,
                      onSubmit: _onSubmitDart,
                      onRemainder: _onRemainder,
                      onUndo: _onDartClear,
                      onModifierSelect: _onModifierSelect,
                    ),
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
                  GameDartStatusBar(
                    dartEntries: _dartEntries,
                    currentDartIndex: _currentDartIndex,
                    isSumMode: _currentInputMode == InputMode.threeDarts,
                    onQuickSum: _currentInputMode == InputMode.threeDarts
                        ? _onQuickSum
                        : null,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 6,
              child: _currentInputMode == InputMode.threeDarts
                  ? GameDartInputPanel(
                      isSumMode: true,
                      inputBuffer: _inputBuffer,
                      dartEntries: _dartEntries,
                      currentDartIndex: _currentDartIndex,
                      selectedModifier: _selectedModifier,
                      currentScore: _players[_currentPlayerIndex].score,
                      onDigit: _onNumpadDigit,
                      onClear: _onNumpadClear,
                      onSubmit: _onSubmitSum,
                      onRemainder: _onRemainder,
                      onUndo: _undo,
                      onModifierSelect: _onModifierSelect,
                    )
                  : GameDartInputPanel(
                      isSumMode: false,
                      inputBuffer: _inputBuffer,
                      dartEntries: _dartEntries,
                      currentDartIndex: _currentDartIndex,
                      selectedModifier: _selectedModifier,
                      currentScore: _players[_currentPlayerIndex].score,
                      onDigit: _onDartDigit,
                      onClear: _onDartClear,
                      onSubmit: _onSubmitDart,
                      onRemainder: _onRemainder,
                      onUndo: _onDartClear,
                      onModifierSelect: _onModifierSelect,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  GameBoardState _buildBoardState() {
    return GameBoardState(
      players: widget.settings.players.asMap().entries.map((entry) {
        final i = entry.key;
        final p = entry.value;
        final state = _players[i];
        return PlayerBoardInfo(
          name: p.name,
          score: state.score,
          legsWon: state.legsWon,
          setsWon: state.setsWon,
          average: state.average,
          lastApproach: state.lastApproach,
          dartsInLeg: state.dartsInLeg,
          isActive: _currentPlayerIndex == i,
          lastDartResults: state.lastApproachDarts,
        );
      }).toList(),
      currentPlayerIndex: _currentPlayerIndex,
      gameType: widget.settings.gameType.name,
      sets: widget.settings.sets,
      legs: widget.settings.legs,
      isDoubleOut: widget.settings.finishType == FinishType.doubleOut,
      isDoubleIn: widget.settings.startType == StartType.doubleIn,
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
            '${widget.settings.gameType.name} | '
            '${widget.settings.sets}с | '
            '${widget.settings.legs}л | '
            '${widget.settings.finishType == FinishType.doubleOut ? "DO" : "SO"}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undoStack.isEmpty ? null : _undo,
            tooltip: 'Отменить ход',
          ),
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
}

/// Вспомогательный класс для undo
class _UndoEntry {
  final int playerIndex;
  final int previousScore;
  final List<int> previousLegHistory;
  final int previousDartsInLeg;
  final int? previousLastApproach;
  final int previousTotalScore;
  final int previousTotalDarts;
  final List<DartEntryDisplay> previousLastApproachDarts;

  _UndoEntry({
    required this.playerIndex,
    required this.previousScore,
    required this.previousLegHistory,
    required this.previousDartsInLeg,
    required this.previousLastApproach,
    required this.previousTotalScore,
    required this.previousTotalDarts,
    this.previousLastApproachDarts = const [],
  });
}
