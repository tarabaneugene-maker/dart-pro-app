import 'dart:async';
import 'package:flutter/material.dart';
import './training_models.dart';
import './training_widgets.dart';

class TrainingPage extends StatefulWidget {
  const TrainingPage({super.key});
  @override
  State<TrainingPage> createState() => _TrainingPageState();
}

class _TrainingPageState extends State<TrainingPage> {
  late TrainingState _state;
  Timer? _autoOkTimer;

  @override
  void initState() {
    super.initState();
    _state = TrainingState();
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
      _state = TrainingState();
    });
  }

  void _goBackToSetup() {
    _cancelAutoOkTimer();
    setState(() {
      _state = _state.copyWith(
        step: TrainingStep.setup,
        pendingInputValue: null,
      );
    });
  }

  void _startTraining() {
    _cancelAutoOkTimer();
    setState(() {
      _state = _state.copyWith(
        step: TrainingStep.process,
        pendingInputValue: null,
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
    _autoOkTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      _confirmPendingInput();
    });
  }

  void _confirmPendingInput() {
    final int? pendingValue = _state.pendingInputValue;
    if (_state.mode == null || pendingValue == null) return;

    bool accepted = false;
    setState(() {
      if (_state.mode == TrainingMode.sector) {
        if (pendingValue < 0 ||
            pendingValue > 9 ||
            _state.sectorAttempts.length >= TrainingState.maxSectorAttempts) {
          return;
        }

        final newAttempts = List<int>.from(_state.sectorAttempts)..add(pendingValue);
        _state = _state.copyWith(
          sectorAttempts: newAttempts,
          pendingInputValue: null,
        );
        accepted = true;
      }
      // Другие режимы будут добавлены позже
    });

    if (accepted) {
      _cancelAutoOkTimer();
    }
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
        pendingInputValue: null,
      );
    });
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
          description: 'Тренировка попадания в сектор',
          onTap: () => _openSetup(TrainingMode.sector),
        ),
        const SizedBox(height: 8),
        TrainingModeCard(
          icon: Icons.timer_outlined,
          title: 'Around the Clock',
          description: 'Проход по секторам с выбором сложности',
          onTap: () => _openSetup(TrainingMode.aroundTheClock),
        ),
        const SizedBox(height: 8),
        TrainingModeCard(
          icon: Icons.schedule,
          title: 'Around a Clock Classic',
          description: 'Классический проход 1→20→Bull',
          onTap: () => _openSetup(TrainingMode.aroundTheClockClassic),
        ),
      ],
    );
  }

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
              if (_state.mode == TrainingMode.sector) ...<Widget>[
                Text('Режим: Сектор',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('Выберите число:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: <int>[20, 19, 18]
                      .map(
                        (int value) => _rectButton(
                          label: '$value',
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
              ],
              if (_state.mode == TrainingMode.aroundTheClock) ...<Widget>[
                Text(
                  'Режим: Around the Clock',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
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
                              _state = _state.copyWith(aroundDifficulty: difficulty);
                            });
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
              if (_state.mode == TrainingMode.aroundTheClockClassic) ...<Widget>[
                Text(
                  'Режим: Around a Clock Classic',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Классический проход 1 -> 20 -> Bull без выбора сложности.',
                ),
              ],
              const SizedBox(height: 16),
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

  Widget _buildSectorProcess() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool isFinished = _state.sectorAttempts.length == TrainingState.maxSectorAttempts;
    final int totalScore =
        _state.sectorAttempts.fold<int>(0, (int sum, int v) => sum + v);
    final int maxScore = TrainingState.maxSectorAttempts * 9;
    final double accuracy = maxScore == 0 ? 0 : (totalScore / maxScore) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Процесс: Сектор', style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
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
              Text('Цель: сектор ${_state.selectedSector}'),
              Text(
                'Раунд ${(_state.sectorAttempts.length + 1).clamp(1, TrainingState.maxSectorAttempts)} '
                'из ${TrainingState.maxSectorAttempts}',
              ),
              Text('Текущий результат: $totalScore'),
              const SizedBox(height: 6),
              if (!isFinished) ...<Widget>[
                const Text('Выберите результат за подход (0..9):'),
                const SizedBox(height: 4),
                TrainingInputMenu(
                  maxValue: 9,
                  disabled: false,
                  pendingInputValue: _state.pendingInputValue,
                  isAutoOkEnabled: _state.isAutoOkEnabled,
                  onValueSelected: _selectInputValue,
                  onConfirm: _confirmPendingInput,
                  onToggleAutoOk: _toggleAutoOk,
                ),
              ],
              if (isFinished) ...<Widget>[
                Text(
                  'Результат: $totalScore из $maxScore очков '
                  '(${accuracy.toStringAsFixed(1)}%)',
                  style: theme.textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: 8),
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

  Widget _buildCurrentStep() {
    if (_state.step == TrainingStep.menu) return _buildModeMenu();
    if (_state.step == TrainingStep.setup) return _buildSetupStep();
    if (_state.mode == TrainingMode.sector) return _buildSectorProcess();
    // TODO: Добавить другие режимы
    return const SizedBox.shrink();
  }

  /// Прямоугольная кнопка-переключатель (замена ChoiceChip)
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
