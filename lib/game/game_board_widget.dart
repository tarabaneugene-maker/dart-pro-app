import 'package:flutter/material.dart';

// ===================================================================
// DATA CLASSES — единое представление состояния игры для виджетов
// ===================================================================

/// Информация об одном игроке для отображения на табло
class PlayerBoardInfo {
  final String name;
  final int score;
  final int legsWon;
  final int setsWon;
  final double? average;
  final int? lastApproach;
  final bool isActive;

  const PlayerBoardInfo({
    required this.name,
    required this.score,
    this.legsWon = 0,
    this.setsWon = 0,
    this.average,
    this.lastApproach,
    this.isActive = false,
  });
}

/// Состояние игры для виджетов
class GameBoardState {
  final List<PlayerBoardInfo> players;
  final int currentPlayerIndex;
  final String gameType; // '501', '301'
  final int sets;
  final int legs;
  final bool isDoubleOut;
  final bool isDoubleIn;

  const GameBoardState({
    required this.players,
    required this.currentPlayerIndex,
    this.gameType = '501',
    this.sets = 1,
    this.legs = 3,
    this.isDoubleOut = true,
    this.isDoubleIn = false,
  });

  PlayerBoardInfo get currentPlayer => players[currentPlayerIndex];
}

// ===================================================================
// SCOREBOARD — табло с двумя колонками игроков
// ===================================================================

class GameScoreBoard extends StatelessWidget {
  final GameBoardState state;

  const GameScoreBoard({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player0 = state.players[0];
    final player1 = state.players.length > 1 ? state.players[1] : null;

    return Column(
      children: [
        // Плашка активного игрока
        _buildActivePlayerBanner(theme, state.currentPlayer),
        // Две колонки игроков
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildPlayerColumn(theme, player0)),
              if (player1 != null) ...[
                Container(
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(child: _buildPlayerColumn(theme, player1)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivePlayerBanner(ThemeData theme, PlayerBoardInfo player) {
    final showCheckout = player.score <= 170 && player.score > 0;

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
                    _getCheckoutHint(player.score),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${player.score}',
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

  Widget _buildPlayerColumn(ThemeData theme, PlayerBoardInfo player) {
    return Container(
      // Изменение 2: фон колонки активного игрока подсвечен
      color: player.isActive
          ? theme.colorScheme.surfaceContainerHighest
          : null,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Имя + счётчик легов/сетов (всегда видны)
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
                      fontWeight:
                          player.isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Изменение 3: S/L всегда видны
                _buildBadge(theme, '${player.setsWon}S', theme.colorScheme.tertiaryContainer),
                const SizedBox(width: 4),
                _buildBadge(theme, '${player.legsWon}L', theme.colorScheme.secondaryContainer),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Average
          if (player.average != null)
            Text(
              'ср: ${player.average!.toStringAsFixed(1)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          // Счёт (крупно) — обычный цвет, без подсветки
          Expanded(
            child: Center(
              child: Text(
                '${player.score}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          // Последний подход
          if (player.lastApproach != null)
            Text(
              '← ${player.lastApproach}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(ThemeData theme, String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
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
}

// ===================================================================
// DART STATUS BAR — строка бросков / быстрые суммы
// ===================================================================

/// Информация об одном броске для отображения
class DartEntryDisplay {
  final String modifier; // 'S', 'D', 'T'
  final int number;
  bool get isEmpty => number == 0 && modifier == 'S';

  const DartEntryDisplay({this.modifier = 'S', this.number = 0});

  String get display {
    if (isEmpty) return '';
    if (number == 25 && modifier == 'S') return 'Bull';
    if (number == 25 && modifier == 'D') return 'DBull';
    // Изменение 6: убираем S-префикс, показываем только число
    if (modifier == 'S') return '$number';
    return '$modifier$number';
  }

  int get score {
    if (isEmpty) return 0;
    final mult = modifier == 'D' ? 2 : modifier == 'T' ? 3 : 1;
    return number * mult;
  }
}

class GameDartStatusBar extends StatelessWidget {
  final List<DartEntryDisplay> dartEntries;
  final int currentDartIndex;
  final bool isSumMode; // true = быстрые суммы, false = per-dart
  final void Function(int value)? onQuickSum;

  const GameDartStatusBar({
    super.key,
    this.dartEntries = const [],
    this.currentDartIndex = 0,
    this.isSumMode = false,
    this.onQuickSum,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isSumMode) {
      return _buildSumMode(theme);
    }

    return _buildDartMode(theme);
  }

  // Изменение 4: две строки быстрых сумм
  Widget _buildSumMode(ThemeData theme) {
    const row1 = [45, 60, 81, 85, 100, 140];
    const row2 = [41, 57, 79, 83, 95, 133];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: row1
                .map((v) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _QuickSumButton(
                          value: v,
                          onTap: () => onQuickSum?.call(v),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          Row(
            children: row2
                .map((v) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _QuickSumButton(
                          value: v,
                          onTap: () => onQuickSum?.call(v),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // Изменение 6: 3 равных блока без нумерации + строка суммы
  Widget _buildDartMode(ThemeData theme) {
    final total = dartEntries.fold<int>(0, (sum, e) => sum + e.score);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 3 равных блока
          Row(
            children: List.generate(3, (i) {
              final entry = dartEntries.length > i ? dartEntries[i] : const DartEntryDisplay();
              final isCurrent = i == currentDartIndex;
              return Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    border: Border(
                      right: i < 2
                          ? BorderSide(color: theme.colorScheme.outlineVariant)
                          : BorderSide.none,
                    ),
                  ),
                  child: Text(
                    entry.isEmpty ? '' : entry.display,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 2),
          // Строка суммы по центру
          Text(
            '= $total',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickSumButton extends StatelessWidget {
  final int value;
  final VoidCallback onTap;

  const _QuickSumButton({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text('$value', style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

// ===================================================================
// DART INPUT PANEL — панель ввода (оба режима)
// ===================================================================

class GameDartInputPanel extends StatefulWidget {
  /// Режим ввода: true = сумма подхода, false = каждый бросок
  final bool isSumMode;

  /// Текущий буфер ввода (для режима суммы)
  final String inputBuffer;

  /// Текущие броски (для per-dart режима)
  final List<DartEntryDisplay> dartEntries;

  /// Индекс текущего броска (для per-dart режима)
  final int currentDartIndex;

  /// Выбранный модификатор (для per-dart режима)
  final String selectedModifier;

  /// Текущий счёт игрока (для режима остатка)
  final int currentScore;

  // Callbacks
  final void Function(String digit)? onDigit;
  final void Function()? onClear;
  final void Function()? onSubmit;
  final void Function()? onRemainder;
  final void Function()? onUndo;
  final void Function(String modifier)? onModifierSelect;

  const GameDartInputPanel({
    super.key,
    this.isSumMode = true,
    this.inputBuffer = '',
    this.dartEntries = const [],
    this.currentDartIndex = 0,
    this.selectedModifier = 'S',
    this.currentScore = 501,
    this.onDigit,
    this.onClear,
    this.onSubmit,
    this.onRemainder,
    this.onUndo,
    this.onModifierSelect,
  });

  @override
  State<GameDartInputPanel> createState() => _GameDartInputPanelState();
}

class _GameDartInputPanelState extends State<GameDartInputPanel> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: const Border(
          top: BorderSide(width: 2),
        ),
      ),
      child: widget.isSumMode
          ? _buildSumInput(theme)
          : _buildDartInput(theme),
    );
  }

  // Изменение 5: новая раскладка "Сумма подхода"
  Widget _buildSumInput(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Отображение ввода
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Center(
            child: Text(
              widget.inputBuffer.isEmpty ? '0' : widget.inputBuffer,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Ряд 1: [Остаток] [OK]
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: widget.onRemainder,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('Остаток', style: TextStyle(fontSize: 14)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 44,
                child: FilledButton(
                  onPressed: widget.onSubmit,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: const Text('OK', style: TextStyle(fontSize: 14)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Ряд 2: [1] [2] [3]
        Row(
          children: [
            _numButton('1', () => widget.onDigit?.call('1')),
            const SizedBox(width: 8),
            _numButton('2', () => widget.onDigit?.call('2')),
            const SizedBox(width: 8),
            _numButton('3', () => widget.onDigit?.call('3')),
          ],
        ),
        const SizedBox(height: 8),
        // Ряд 3: [4] [5] [6]
        Row(
          children: [
            _numButton('4', () => widget.onDigit?.call('4')),
            const SizedBox(width: 8),
            _numButton('5', () => widget.onDigit?.call('5')),
            const SizedBox(width: 8),
            _numButton('6', () => widget.onDigit?.call('6')),
          ],
        ),
        const SizedBox(height: 8),
        // Ряд 4: [7] [8] [9]
        Row(
          children: [
            _numButton('7', () => widget.onDigit?.call('7')),
            const SizedBox(width: 8),
            _numButton('8', () => widget.onDigit?.call('8')),
            const SizedBox(width: 8),
            _numButton('9', () => widget.onDigit?.call('9')),
          ],
        ),
        const SizedBox(height: 8),
        // Ряд 5: [⌫] [0] [↩]
        Row(
          children: [
            _numButton('⌫', () => widget.onClear?.call()),
            const SizedBox(width: 8),
            _numButton('0', () => widget.onDigit?.call('0')),
            const SizedBox(width: 8),
            _numButton('↩', () => widget.onUndo?.call()),
          ],
        ),
      ],
    );
  }

  // Изменение 6: новая раскладка "Каждый бросок"
  Widget _buildDartInput(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ряд 1: [1] [2] [3] [4] [5] [6] [7]
        Row(
          children: [
            for (int i = 1; i <= 7; i++) ...[
              if (i > 1) const SizedBox(width: 4),
              Expanded(
                child: _numButton('$i', () => widget.onDigit?.call('$i')),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        // Ряд 2: [8] [9] [10] [11] [12] [13] [14]
        Row(
          children: [
            for (int i = 8; i <= 14; i++) ...[
              if (i > 8) const SizedBox(width: 4),
              Expanded(
                child: _numButton('$i', () => widget.onDigit?.call('$i')),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        // Ряд 3: [15] [16] [17] [18] [19] [20] [Bull]
        Row(
          children: [
            for (int i = 15; i <= 20; i++) ...[
              if (i > 15) const SizedBox(width: 4),
              Expanded(
                child: _numButton('$i', () => widget.onDigit?.call('$i')),
              ),
            ],
            const SizedBox(width: 4),
            Expanded(
              child: _numButton('Bull', () => widget.onDigit?.call('25'),
                  color: Colors.amber.shade700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Ряд 4: [0] [DOUBLE] [TRIPLE] [НАЗАД]
        Row(
          children: [
            Expanded(
              child: _numButton('0', () => widget.onDigit?.call('0')),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: _modifierButton('D', 'DOUBLE'),
            ),
            const SizedBox(width: 4),
            Expanded(
              flex: 2,
              child: _modifierButton('T', 'TRIPLE'),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _numButton('↩', () => widget.onUndo?.call()),
            ),
          ],
        ),
      ],
    );
  }

  // Изменение 1: кнопки прямоугольные
  Widget _numButton(String label, VoidCallback onPressed,
      {Color? color, Color? textColor}) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _modifierButton(String mod, String label) {
    final isSelected = widget.selectedModifier == mod;
    return SizedBox(
      height: 44,
      child: isSelected
          ? FilledButton(
              onPressed: () => widget.onModifierSelect?.call(mod),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Text(label, style: const TextStyle(fontSize: 13)),
            )
          : OutlinedButton(
              onPressed: () => widget.onModifierSelect?.call(mod),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
    );
  }
}
