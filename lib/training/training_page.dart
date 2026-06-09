import 'dart:async';
import 'package:flutter/material.dart';
import '../online/services/backend_service.dart';
import './training_models.dart';
import './training_widgets.dart';

class TrainingPage extends StatefulWidget {
  final BackendService? backend;

  const TrainingPage({super.key, this.backend});

  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  late TrainingState _state;
  Timer? _autoOkTimer;

  @override
  void initState() {
    super.initState();
    final defaultName = _resolvePlayer1Name();
    _state = TrainingState(
      player1: TrainingPlayerInfo(name: defaultName),
    );
  }

  String _resolvePlayer1Name() {
    return 'Игрок1';
  }

  @override
  void dispose() {
    _cancelAutoOkTimer();
    super.dispose();
  }

  void _cancelAutoOkTimer() {
    _autoOkTimer?.cancel();
    _autoOkTimer = null;
  }

  void _openSetup(TrainingMode mode) {
    _cancelAutoOkTimer();
    setState(() {
      _state = _state.copyWith(
        mode: mode,
        step: TrainingStep.setup,
        pendingInputValue: null,
      );
    });
  }

  void _goToMenu() {
    _cancelAutoOkTimer();
    setState(() {
      _state = TrainingState(
        player1: TrainingPlayerInfo(name: _state.player1.name),
        player1Finished: false,
        player2Finished: false,
      );
    });
  }

  void _goBackToSetup() {
    _cancelAutoOkTimer();
    setState(() {
      _state = _state.copyWith(
        step: TrainingStep.setup,
        pendingInputValue: null,
        player1Finished: false,
        player2Finished: false,
      );
    });
  }

  void _startTraining() {
    _cancelAutoOkTimer();
    setState(() {
      _state = _state.copyWith(
        step: TrainingStep.process,
        pendingInputValue: null,
        // Сброс состояния режима
        sectorAttempts: [],
        aroundTarget: 1,
        aroundTotalScore: 0,
        bob27Score: TrainingState.bob27StartScore,
        bob27CurrentSector: 1,
        shanghaiCurrentSector: 1,
        shanghaiDartsInSector: 0,
        shanghaiFinished: false,
        currentPlayerIndex: 0,
        player1Finished: false,
        player2Finished: false,
        player1: _state.player1.copyWith(
          totalScore: 0,
          totalHits: 0,
          totalTurns: 0,
        ),
        player2: _state.player2.copyWith(
          totalScore: 0,
          totalHits: 0,
          totalTurns: 0,
        ),
      );
    });
  }

  void _selectInputValue(int value) {
    setState(() {
      _state = _state.copyWith(pendingInputValue: value);
    });
    _scheduleAutoOkIfNeeded();
  }

  void _scheduleAutoOkIfNeeded() {
    _cancelAutoOkTimer();
    if (!_state.isAutoOkEnabled || _state.pendingInputValue == null) return;
    _autoOkTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _confirmPendingInput();
    });
  }

  void _confirmPendingInput() {
    final int? pendingValue = _state.pendingInputValue;
    if (_state.mode == null || pendingValue == null) return;

    // Сохраняем ссылку на старый pendingInputValue перед вызовом _process*
    // _process* методы сами обновляют _state через setState
    setState(() {
      switch (_state.mode) {
        case TrainingMode.sector:
          _processSector(pendingValue);
          break;
        case TrainingMode.aroundTheClock:
          _processAroundTheClock(pendingValue);
          break;
        case TrainingMode.aroundTheClockClassic:
          _processAroundTheClock(pendingValue);
          break;
        case TrainingMode.bob27:
          _processBob27(pendingValue);
          break;
        case TrainingMode.shanghai:
          _processShanghai(pendingValue);
          break;
        case null:
          break;
      }
      // Сбрасываем pendingInputValue (не перезаписывая изменения из _process*)
      // Важно: сохраняем step, который мог быть изменён в _switchOrFinish()
      _state = _state.copyWith(
        pendingInputValue: null,
        step: _state.step,
      );
    });

    _cancelAutoOkTimer();
  }

  // ===================================================================
  // ЛОГИКА РЕЖИМОВ
  // ===================================================================

  void _processSector(int value) {
    if (value < 0 || value > 9 ||
        _state.sectorAttempts.length >= TrainingState.maxSectorAttempts) {
      return;
    }
    final newAttempts = List<int>.from(_state.sectorAttempts)..add(value);
    final isFinished = newAttempts.length >= TrainingState.maxSectorAttempts;

    _state = _state.copyWith(sectorAttempts: newAttempts);

    // Очки = номинал сектора × количество попаданий
    final sectorValue = _state.selectedSector; // 20, 19, 18, 17, 16, 15, 25
    final points = sectorValue * value;
    _addScoreToCurrentPlayer(points, hits: value);

    if (isFinished) {
      _switchOrFinish();
    } else if (_state.isPaired) {
      _switchOrFinish();
    }
  }

  void _processAroundTheClock(int value) {
    if (_state.isAroundFinished) return;

    // value = количество попаданий (0-9)
    // Для Around: засчитываем только если value > 0
    if (value > 0) {
      final sectorValue = _state.isBullTarget ? 25 : _state.aroundTarget;
      final multiplier = _getAroundMultiplier();
      final points = sectorValue * multiplier;
      _addScoreToCurrentPlayer(points);
      _state = _state.copyWith(
        aroundTarget: _state.aroundTarget + 1,
        aroundTotalScore: _state.aroundTotalScore + points,
      );
    } else {
      // Промах — ход переходит
      _state = _state.copyWith(aroundTarget: _state.aroundTarget + 1);
    }

    if (_state.isAroundFinished) {
      _switchOrFinish();
    } else if (_state.isPaired) {
      // В парном режиме — переключаем игрока после каждого подхода
      _switchOrFinish();
    }
  }

  int _getAroundMultiplier() {
    if (_state.mode == TrainingMode.aroundTheClockClassic) return 1;
    switch (_state.aroundDifficulty) {
      case AroundDifficulty.single:
        return 1;
      case AroundDifficulty.double:
        return 2;
      case AroundDifficulty.triple:
        return 3;
    }
  }

  void _processBob27(int value) {
    // value = количество попаданий (0-9)
    // Bob27: +1 за Single, +2 за Double, +3 за Triple
    // Но у нас value — это количество попаданий, а не номинал.
    // Интерпретируем: value = 0 → промах, 1-3 = Single, 4-6 = Double, 7-9 = Triple
    int points;
    if (value == 0) {
      points = 0;
    } else if (value <= 3) {
      points = value; // Single
    } else if (value <= 6) {
      points = (value - 3) * 2; // Double
    } else {
      points = (value - 6) * 3; // Triple
    }

    _state = _state.copyWith(
      bob27Score: _state.bob27Score + points,
      bob27CurrentSector: _state.bob27CurrentSector + 1,
    );
    _addScoreToCurrentPlayer(points);

    if (_state.bob27CurrentSector > 20) {
      _switchOrFinish();
    } else if (_state.isPaired) {
      // В парном режиме — переключаем игрока после каждого подхода
      _switchOrFinish();
    }
  }

  void _processShanghai(int value) {
    if (_state.shanghaiFinished) return;

    // value = количество попаданий (0-9)
    // Shanghai: 3 дротика в сектор, очки = номинал * попадания
    final sectorValue = _state.shanghaiCurrentSector;
    final points = sectorValue * value;
    _addScoreToCurrentPlayer(points);

    _state = _state.copyWith(
      shanghaiDartsInSector: _state.shanghaiDartsInSector + 1,
    );

    // Проверка Shanghai (S+D+T за один подход — мгновенная победа)
    if (value >= 6) {
      // 6+ попаданий = как минимум Double+Triple или Single+Double+Triple
      _state = _state.copyWith(shanghaiFinished: true);
      _switchOrFinish();
      return;
    }

    if (_state.shanghaiDartsInSector >= 3) {
      _state = _state.copyWith(
        shanghaiCurrentSector: _state.shanghaiCurrentSector + 1,
        shanghaiDartsInSector: 0,
      );
      if (_state.shanghaiCurrentSector > TrainingState.shanghaiMaxSector) {
        _switchOrFinish();
      } else if (_state.isPaired) {
        // В парном режиме — переключаем игрока после каждого сектора (3 дротика)
        _switchOrFinish();
      }
    } else if (_state.isPaired) {
      // В парном режиме — переключаем игрока после каждого дротика
      _switchOrFinish();
    }
  }

  // ===================================================================
  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ===================================================================

  void _addScoreToCurrentPlayer(int points, {int hits = 0}) {
    final p = _state.currentPlayer;
    // Сохраняем предыдущее среднее для расчёта динамики
    final prevAvg = p.avgScore;
    final updated = p.copyWith(
      totalScore: p.totalScore + points,
      totalHits: p.totalHits + hits,
      totalTurns: p.totalTurns + 1,
      previousAvgScore: prevAvg,
    );
    if (_state.currentPlayerIndex == 0) {
      _state = _state.copyWith(player1: updated);
    } else {
      _state = _state.copyWith(player2: updated);
    }
  }

  /// Возвращает максимальное количество подходов для текущего режима
  int _maxTurnsForMode() {
    switch (_state.mode) {
      case TrainingMode.sector:
        return TrainingState.maxSectorAttempts;
      case TrainingMode.aroundTheClock:
      case TrainingMode.aroundTheClockClassic:
        return 21; // 1-20 + Bull
      case TrainingMode.bob27:
        return 20; // сектора 1-20
      case TrainingMode.shanghai:
        return TrainingState.shanghaiMaxSector * 3; // 7 секторов * 3 дротика
      case null:
        return 0;
    }
  }

  void _switchOrFinish() {
    if (!_state.isPaired) {
      // Одиночный режим — возврат в меню (через флаг, без вложенного setState)
      _state = _state.copyWith(
        step: TrainingStep.setup,
        pendingInputValue: null,
        player1Finished: false,
        player2Finished: false,
      );
      return;
    }

    // Парный режим: отмечаем текущего игрока как завершившего подход
    final maxTurns = _maxTurnsForMode();
    final currentPlayer = _state.currentPlayer;
    final isPlayerDone = currentPlayer.totalTurns >= maxTurns;

    if (_state.currentPlayerIndex == 0) {
      _state = _state.copyWith(player1Finished: isPlayerDone);
    } else {
      _state = _state.copyWith(player2Finished: isPlayerDone);
    }

    // Проверяем, завершили ли оба игрока
    final bothDone = _state.player1Finished && _state.player2Finished;
    if (bothDone) {
      // Оба завершили — показываем результат
      return; // _isModeFinished() вернёт true, покажется _buildResultBlock()
    }

    // Переключаем на другого игрока
    _state.switchPlayer();

    // Сброс состояния режима для следующего игрока
    _state = _state.copyWith(
      sectorAttempts: [],
      aroundTarget: 1,
      aroundTotalScore: 0,
      bob27Score: TrainingState.bob27StartScore,
      bob27CurrentSector: 1,
      shanghaiCurrentSector: 1,
      shanghaiDartsInSector: 0,
      shanghaiFinished: false,
    );
  }

  void _undoLastTurn() {
    // Пока не реализовано — заглушка
    // В будущем: откат последнего подтверждённого хода
  }

  void _clearInput() {
    setState(() {
      _state = _state.copyWith(pendingInputValue: null);
    });
    _cancelAutoOkTimer();
  }

  void _toggleAutoOk() {
    setState(() {
      _state = _state.copyWith(isAutoOkEnabled: !_state.isAutoOkEnabled);
    });
    if (_state.isAutoOkEnabled) {
      _scheduleAutoOkIfNeeded();
    } else {
      _cancelAutoOkTimer();
    }
  }

  void _finishEarly() {
    _cancelAutoOkTimer();
    _goBackToSetup();
  }

  void _restartCurrentMode() {
    _cancelAutoOkTimer();
    setState(() {
      _state = _state.copyWith(
        sectorAttempts: [],
        aroundTarget: 1,
        aroundTotalScore: 0,
        bob27Score: TrainingState.bob27StartScore,
        bob27CurrentSector: 1,
        shanghaiCurrentSector: 1,
        shanghaiDartsInSector: 0,
        shanghaiFinished: false,
        pendingInputValue: null,
        player1: _state.player1.copyWith(
          totalScore: 0,
          totalHits: 0,
          totalTurns: 0,
        ),
        player2: _state.player2.copyWith(
          totalScore: 0,
          totalHits: 0,
          totalTurns: 0,
        ),
        currentPlayerIndex: 0,
        player1Finished: false,
        player2Finished: false,
      );
    });
  }

  int _inputMaxValue() {
    // Для Bull (25) максимум 6 (double*3), для остальных секторов — 9
    if (_state.mode == TrainingMode.sector && _state.selectedSector == 25) {
      return 6;
    }
    return 9;
  }

  String _difficultyLabel(AroundDifficulty difficulty) {
    switch (difficulty) {
      case AroundDifficulty.single:
        return 'Single';
      case AroundDifficulty.double:
        return 'Double';
      case AroundDifficulty.triple:
        return 'Triple';
    }
  }

  // ===================================================================
  // BUILD — МЕНЮ
  // ===================================================================

  Widget _buildModeMenu() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Выбор режима', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        TrainingModeCard(
          icon: Icons.circle_outlined,
          title: 'Сектор',
          description: '10 попыток попасть в выбранный сектор',
          onTap: () => _openSetup(TrainingMode.sector),
        ),
        const SizedBox(height: 8),
        TrainingModeCard(
          icon: Icons.timer_outlined,
          title: 'Around the Clock',
          description: 'Проход по секторам 1→20→Bull с выбором сложности',
          onTap: () => _openSetup(TrainingMode.aroundTheClock),
        ),
        const SizedBox(height: 8),
        TrainingModeCard(
          icon: Icons.schedule,
          title: 'Around a Clock Classic',
          description: 'Классический проход 1→20→Bull (только Single)',
          onTap: () => _openSetup(TrainingMode.aroundTheClockClassic),
        ),
        const SizedBox(height: 8),
        TrainingModeCard(
          icon: Icons.exposure_plus_1_outlined,
          title: 'Bob 27',
          description: 'Начни с 27 очков, набирай на секторах 1→20',
          onTap: () => _openSetup(TrainingMode.bob27),
        ),
        const SizedBox(height: 8),
        TrainingModeCard(
          icon: Icons.shuffle,
          title: 'Shanghai',
          description: '3 дротика в сектора 1→7. Shanghai = мгновенная победа',
          onTap: () => _openSetup(TrainingMode.shanghai),
        ),
      ],
    );
  }

  // ===================================================================
  // BUILD — НАСТРОЙКИ
  // ===================================================================

  Widget _buildSetupStep() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_state.mode == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Настройка', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Название режима
              Text(
                _modeTitle(_state.mode!),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),

              // Параметры режима
              if (_state.mode == TrainingMode.sector) ..._buildSectorSetup(),
              if (_state.mode == TrainingMode.aroundTheClock)
                ..._buildAroundSetup(),
              if (_state.mode == TrainingMode.aroundTheClockClassic)
                ..._buildAroundClassicSetup(),
              if (_state.mode == TrainingMode.bob27) ..._buildBob27Setup(),
              if (_state.mode == TrainingMode.shanghai) ..._buildShanghaiSetup(),

              const SizedBox(height: 16),

              // Парный режим
              _buildPairedToggle(),

              const SizedBox(height: 16),

              // Кнопки
              Row(
                children: <Widget>[
                  OutlinedButton(
                    onPressed: _goToMenu,
                    style: _rectOutlinedStyle,
                    child: const Text('Назад'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: _startTraining,
                    style: _rectFilledStyle,
                    child: const Text('Начать'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _modeTitle(TrainingMode mode) {
    switch (mode) {
      case TrainingMode.sector:
        return 'Режим: Сектор';
      case TrainingMode.aroundTheClock:
        return 'Режим: Around the Clock';
      case TrainingMode.aroundTheClockClassic:
        return 'Режим: Around a Clock Classic';
      case TrainingMode.bob27:
        return 'Режим: Bob 27';
      case TrainingMode.shanghai:
        return 'Режим: Shanghai';
    }
  }

  List<Widget> _buildSectorSetup() {
    return [
      const Text('Выберите сектор:'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: <int>[20, 19, 18, 17, 16, 15, 25]
            .map(
              (int value) => _rectButton(
                label: value == 25 ? 'Bull' : '$value',
                selected: _state.selectedSector == value,
                onTap: () {
                  setState(() {
                    _state = _state.copyWith(selectedSector: value);
                  });
                },
              ),
            )
            .toList(),
      ),
    ];
  }

  List<Widget> _buildAroundSetup() {
    return [
      const Text('Выберите сложность:'),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: AroundDifficulty.values
            .map(
              (AroundDifficulty difficulty) => _rectButton(
                label: _difficultyLabel(difficulty),
                selected: _state.aroundDifficulty == difficulty,
                onTap: () {
                  setState(() {
                    _state =
                        _state.copyWith(aroundDifficulty: difficulty);
                  });
                },
              ),
            )
            .toList(),
      ),
    ];
  }

  List<Widget> _buildAroundClassicSetup() {
    return [
      const Text('Классический проход 1 → 20 → Bull без выбора сложности.'),
    ];
  }

  List<Widget> _buildBob27Setup() {
    return [
      const Text('Стартовые очки: 27'),
      const SizedBox(height: 4),
      const Text('Сектора: 1 → 20. Single = +1, Double = +2, Triple = +3.'),
    ];
  }

  List<Widget> _buildShanghaiSetup() {
    return [
      const Text('Сектора: 1 → 7. 3 дротика в каждый.'),
      const SizedBox(height: 4),
      const Text(
          'Shanghai (S+D+T одного сектора за подход) = мгновенная победа.'),
    ];
  }

  Widget _buildPairedToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Парная тренировка'),
              const Spacer(),
              Switch(
                value: _state.isPaired,
                onChanged: (val) {
                  setState(() {
                    _state = _state.copyWith(isPaired: val);
                  });
                },
              ),
            ],
          ),
          if (_state.isPaired) ...[
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Имя второго игрока',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              controller: TextEditingController(text: _state.player2.name),
              onChanged: (val) {
                setState(() {
                  _state = _state.copyWith(
                    player2: _state.player2.copyWith(
                      name: val.isEmpty ? 'Игрок2' : val,
                    ),
                  );
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  // ===================================================================
  // BUILD — ПРОЦЕСС (универсальный)
  // ===================================================================

  Widget _buildProcess() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Панель игроков
        TrainingPlayerBar(
          player1: _state.player1,
          player2: _state.player2,
          currentPlayerIndex: _state.currentPlayerIndex,
          isPaired: _state.isPaired,
        ),
        const SizedBox(height: 8),

        // Информация о режиме
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Заголовок режима
              Text(
                _modeTitle(_state.mode!),
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),

              // Специфичная информация
              ..._buildModeProcessInfo(),

              const SizedBox(height: 12),

              // Панель ввода
              if (!_isModeFinished()) ...[
                TrainingInputMenu(
                  maxValue: _inputMaxValue(),
                  disabled: false,
                  pendingInputValue: _state.pendingInputValue,
                  isAutoOkEnabled: _state.isAutoOkEnabled,
                  onValueSelected: _selectInputValue,
                  onConfirm: _confirmPendingInput,
                  onToggleAutoOk: _toggleAutoOk,
                  onUndo: _undoLastTurn,
                  onClear: _clearInput,
                ),
              ],

              if (_isModeFinished()) ...[
                _buildResultBlock(),
              ],

              const SizedBox(height: 12),

              // Кнопки управления
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: _finishEarly,
                    style: _rectOutlinedStyle,
                    child: const Text('Завершить досрочно'),
                  ),
                  OutlinedButton(
                    onPressed: _restartCurrentMode,
                    style: _rectOutlinedStyle,
                    child: const Text('Начать заново'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isModeFinished() {
    // В парном режиме — оба игрока должны завершить
    if (_state.isPaired) {
      return _state.player1Finished && _state.player2Finished;
    }
    // В одиночном — проверяем по состоянию режима
    switch (_state.mode) {
      case TrainingMode.sector:
        return _state.sectorAttempts.length >= TrainingState.maxSectorAttempts;
      case TrainingMode.aroundTheClock:
      case TrainingMode.aroundTheClockClassic:
        return _state.isAroundFinished;
      case TrainingMode.bob27:
        return _state.bob27CurrentSector > 20;
      case TrainingMode.shanghai:
        return _state.shanghaiFinished ||
            _state.shanghaiCurrentSector > TrainingState.shanghaiMaxSector;
      case null:
        return true;
    }
  }

  List<Widget> _buildModeProcessInfo() {
    switch (_state.mode) {
      case TrainingMode.sector:
        return [
          Text('Цель: сектор ${_state.selectedSector}'),
          const SizedBox(height: 4),
          Text(
            'Раунд ${(_state.sectorAttempts.length + 1).clamp(1, TrainingState.maxSectorAttempts)} '
            'из ${TrainingState.maxSectorAttempts}',
          ),
          const SizedBox(height: 4),
          Text('Текущий результат: ${_state.currentPlayer.totalScore}'),
        ];
      case TrainingMode.aroundTheClock:
      case TrainingMode.aroundTheClockClassic:
        final target = _state.isBullTarget ? 'Bull' : '${_state.aroundTarget}';
        return [
          Text('Текущая цель: $target'),
          const SizedBox(height: 4),
          Text('Очки: ${_state.currentPlayer.totalScore}'),
        ];
      case TrainingMode.bob27:
        return [
          Text('Текущий сектор: ${_state.bob27CurrentSector}'),
          const SizedBox(height: 4),
          Text('Очки: ${_state.currentPlayer.totalScore}'),
        ];
      case TrainingMode.shanghai:
        return [
          Text('Текущий сектор: ${_state.shanghaiCurrentSector}'),
          const SizedBox(height: 4),
          Text('Дротик ${_state.shanghaiDartsInSector + 1} из 3'),
          const SizedBox(height: 4),
          Text('Очки: ${_state.currentPlayer.totalScore}'),
        ];
      case null:
        return [];
    }
  }

  Widget _buildResultBlock() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade900.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.green.shade600),
      ),
      child: Column(
        children: [
          Text(
            'Результат',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.green.shade300,
            ),
          ),
          const SizedBox(height: 8),
          if (_state.isPaired) ...[
            Text(
              '${_state.player1.name}: ${_state.player1.totalScore}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_state.player2.name}: ${_state.player2.totalScore}',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _state.player1.totalScore > _state.player2.totalScore
                  ? '${_state.player1.name} победил!'
                  : _state.player2.totalScore > _state.player1.totalScore
                      ? '${_state.player2.name} победил!'
                      : 'Ничья!',
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.amber.shade300,
                fontWeight: FontWeight.bold,
              ),
            ),
          ] else ...[
            Text(
              '${_state.player1.name}: ${_state.player1.totalScore} очков',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===================================================================
  // BUILD — ДИСПЕТЧЕР
  // ===================================================================

  Widget _buildCurrentStep() {
    if (_state.step == TrainingStep.menu) return _buildModeMenu();
    if (_state.step == TrainingStep.setup) return _buildSetupStep();
    return _buildProcess();
  }

  // ===================================================================
  // СТИЛИ КНОПОК
  // ===================================================================

  Widget _rectButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    if (selected) {
      return FilledButton(
        onPressed: onTap,
        style: _rectFilledStyle,
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onTap,
      style: _rectOutlinedStyle,
      child: Text(label),
    );
  }

  static final ButtonStyle _rectFilledStyle = FilledButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
  );

  static final ButtonStyle _rectOutlinedStyle = OutlinedButton.styleFrom(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Тренировка')),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Padding(
            key: ValueKey<TrainingStep>(_state.step),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: _buildCurrentStep(),
            ),
          ),
        ),
      ),
    );
  }
}
