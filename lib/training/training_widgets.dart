import 'package:flutter/material.dart';
import 'training_models.dart';

// ===================================================================
// ПЛИТКА РЕЖИМА ТРЕНИРОВКИ
// ===================================================================

class TrainingModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const TrainingModeCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 28, color: colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// ПАНЕЛЬ ИГРОКОВ (парный режим)
// ===================================================================

class TrainingPlayerBar extends StatelessWidget {
  final TrainingPlayerInfo player1;
  final TrainingPlayerInfo player2;
  final int currentPlayerIndex;
  final bool isPaired;

  const TrainingPlayerBar({
    super.key,
    required this.player1,
    required this.player2,
    required this.currentPlayerIndex,
    required this.isPaired,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _playerCard(theme, player1, currentPlayerIndex == 0),
              if (isPaired) ...[
                const SizedBox(width: 8),
                _playerCard(theme, player2, currentPlayerIndex == 1),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _playerCard(ThemeData theme, TrainingPlayerInfo p, bool isActive) {
    final delta = p.totalTurns > 0
        ? p.avgScore - p.previousAvgScore
        : 0.0;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? Colors.green.shade900 : Colors.grey.shade900,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Имя
            Text(
              p.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Очки
            Text(
              'Очки: ${p.totalScore}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            // Хиты
            Text(
              'Хиты: ${p.totalHits}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
            // Среднее + динамика
            Row(
              children: [
                Text(
                  'Ср: ${p.avgScore.toStringAsFixed(1)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                if (p.totalTurns > 1 && delta != 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    delta > 0 ? '(+${delta.toStringAsFixed(1)})' : '(${delta.toStringAsFixed(1)})',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: delta > 0 ? Colors.green.shade300 : Colors.red.shade300,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ===================================================================
// ПАНЕЛЬ ВВОДА (общий стиль)
// ===================================================================

class TrainingInputMenu extends StatelessWidget {
  final int maxValue;
  final bool disabled;
  final int? pendingInputValue;
  final bool isAutoOkEnabled;
  final Function(int) onValueSelected;
  final VoidCallback onConfirm;
  final VoidCallback onToggleAutoOk;
  final VoidCallback? onUndo;
  final VoidCallback? onClear;

  const TrainingInputMenu({
    super.key,
    required this.maxValue,
    required this.disabled,
    required this.pendingInputValue,
    required this.isAutoOkEnabled,
    required this.onValueSelected,
    required this.onConfirm,
    required this.onToggleAutoOk,
    this.onUndo,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final cappedMaxValue = maxValue.clamp(1, 9);
    final keypadValues =
        List<int>.generate(cappedMaxValue, (int index) => index + 1);
    final totalKeys = keypadValues.length + 1;

    final btnStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // AutoOk toggle
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            height: 32,
            child: isAutoOkEnabled
                ? FilledButton(
                    onPressed: disabled ? null : onToggleAutoOk,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('AutoOk: On', style: TextStyle(fontSize: 12)),
                  )
                : OutlinedButton(
                    onPressed: disabled ? null : onToggleAutoOk,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('AutoOk', style: TextStyle(fontSize: 12)),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        // Поле ввода
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: colors.primary, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Текущий подход',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onPrimaryContainer.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                pendingInputValue == null ? '-' : '$pendingInputValue',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: colors.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Клавиатура
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalKeys,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childAspectRatio: 2.9,
          ),
          itemBuilder: (BuildContext context, int index) {
            if (index < keypadValues.length) {
              final int value = keypadValues[index];
              return OutlinedButton(
                style: btnStyle,
                onPressed: disabled ? null : () => onValueSelected(value),
                child: Text('$value'),
              );
            }
            if (index == keypadValues.length) {
              return FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: disabled
                    ? null
                    : () {
                        if (pendingInputValue == null) {
                          onValueSelected(0);
                        }
                        onConfirm();
                      },
                child: const Text('Ок / 0'),
              );
            }
            return const SizedBox();
          },
        ),
        const SizedBox(height: 6),
        // Кнопки "Вернуть ход" и "Стереть"
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: disabled ? null : onUndo,
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Вернуть ход', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: disabled ? null : onClear,
                icon: const Icon(Icons.backspace, size: 16),
                label: const Text('Стереть', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ===================================================================
// ИНДИКАТОР РАУНДА / ПРОГРЕССА
// ===================================================================

class RoundIndicator extends StatelessWidget {
  final String label;
  final String value;

  const RoundIndicator({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
