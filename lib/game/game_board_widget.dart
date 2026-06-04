import 'package:flutter/material.dart';
import '../data/checkouts.dart';
import '../widgets/checkouts_page.dart';

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
  final int dartsInLeg;
  final bool isActive;
  final List<DartEntryDisplay> lastDartResults;

  const PlayerBoardInfo({
    required this.name,
    required this.score,
    this.legsWon = 0,
    this.setsWon = 0,
    this.average,
    this.lastApproach,
    this.dartsInLeg = 0,
    this.isActive = false,
    this.lastDartResults = const [],
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
        _buildActivePlayerBanner(context, theme, state.currentPlayer),
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

  Widget _buildActivePlayerBanner(BuildContext context, ThemeData theme, PlayerBoardInfo player) {
    final showCheckout = player.score <= 170 && player.score > 0;
    final checkout = showCheckout ? getCheckout(player.score) : null;

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
          // Имя игрока слева
          Expanded(
            child: Text(
              player.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Чекаут / CheckOuts + счёт справа
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const CheckOutsPage(),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (checkout != null)
                  Text(
                    [checkout.first, checkout.second, checkout.third]
                        .where((s) => s != null)
                        .join(' - '),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    'CheckOuts',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
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
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerColumn(ThemeData theme, PlayerBoardInfo player) {
    return Container(
      // Подсветка активного игрока — тёмно-зелёный
      color: player.isActive
          ? Colors.green.shade900
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
          // Счёт (крупно, по центру колонки) + avg + результаты бросков (поверх)
          Expanded(
            child: Stack(
              children: [
                // Счёт — идеально по центру всей колонки игрока
                Center(
                  child: Text(
                    '${player.score}',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                // Average — сверху слева, поверх счёта, не влияет на layout
                if (player.average != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Text(
                      'ср: ${player.average!.toStringAsFixed(1)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                // Результаты дротиков последнего подхода — слева внизу, поверх счёта
                if (player.lastDartResults.isNotEmpty)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final d in player.lastDartResults)
                            Text(
                              d.isEmpty ? '' : d.display,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                height: 1.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Нижняя строка: последний подход слева, дротики справа
          Row(
            children: [
              // Последний подход
              if (player.lastApproach != null)
                Text(
                  '← ${player.lastApproach}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const Spacer(),
              // Счётчик дротиков
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.north_east,
                    size: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${player.dartsInLeg}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
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

}

// ===================================================================
// DART STATUS BAR — строка бросков / быстрые суммы
// ===================================================================

/// Информация об одном броске для отображения
class DartEntryDisplay {
  final String modifier; // 'S', 'D', 'T'
  final int number;
  final bool isSet; // true = игрок ввёл значение (включая 0-мимо)
  bool get isEmpty => !isSet;

  const DartEntryDisplay({this.modifier = 'S', this.number = 0, this.isSet = false});

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
            Expanded(child: _numButton('1', () => widget.onDigit?.call('1'))),
            const SizedBox(width: 8),
            Expanded(child: _numButton('2', () => widget.onDigit?.call('2'))),
            const SizedBox(width: 8),
            Expanded(child: _numButton('3', () => widget.onDigit?.call('3'))),
          ],
        ),
        const SizedBox(height: 4),
        // Ряд 3: [4] [5] [6]
        Row(
          children: [
            Expanded(child: _numButton('4', () => widget.onDigit?.call('4'))),
            const SizedBox(width: 8),
            Expanded(child: _numButton('5', () => widget.onDigit?.call('5'))),
            const SizedBox(width: 8),
            Expanded(child: _numButton('6', () => widget.onDigit?.call('6'))),
          ],
        ),
        const SizedBox(height: 4),
        // Ряд 4: [7] [8] [9]
        Row(
          children: [
            Expanded(child: _numButton('7', () => widget.onDigit?.call('7'))),
            const SizedBox(width: 8),
            Expanded(child: _numButton('8', () => widget.onDigit?.call('8'))),
            const SizedBox(width: 8),
            Expanded(child: _numButton('9', () => widget.onDigit?.call('9'))),
          ],
        ),
        const SizedBox(height: 4),
        // Ряд 5: [⌫] [0] [↩]
        Row(
          children: [
            Expanded(child: _numButton('⌫', () => widget.onClear?.call())),
            const SizedBox(width: 8),
            Expanded(child: _numButton('0', () => widget.onDigit?.call('0'))),
            const SizedBox(width: 8),
            Expanded(child: _numButton('↩', () => widget.onUndo?.call())),
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
        // Ряд 4: [0] [DOUBLE] [TRIPLE] [OK] [↩]
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
              child: FilledButton(
                onPressed: widget.onSubmit,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('OK', style: TextStyle(fontSize: 13)),
              ),
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
