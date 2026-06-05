import 'package:flutter/material.dart';
import '../models/game_enums.dart';

// ===================================================================
// DATA CLASSES
// ===================================================================

/// Состояние одного сектора для одного игрока
class CricketSectorState {
  final int hits;
  bool get isClosed => hits >= 3;
  final int points;

  const CricketSectorState({this.hits = 0, this.points = 0});
}

/// Информация об одном игроке для доски Cricket
class CricketPlayerBoardInfo {
  final String name;
  final int legsWon;
  final int setsWon;
  final double? avgHitsPerTurn;
  final bool isActive;
  final int totalPoints;
  final Map<int, CricketSectorState> sectors;

  /// Строка последнего подхода: "20 - 6 | 19 - 3"
  final String? lastTurnSummary;

  const CricketPlayerBoardInfo({
    required this.name,
    this.legsWon = 0,
    this.setsWon = 0,
    this.avgHitsPerTurn,
    this.isActive = false,
    this.totalPoints = 0,
    required this.sectors,
    this.lastTurnSummary,
  });
}

/// Состояние доски Cricket
class CricketBoardState {
  final List<CricketPlayerBoardInfo> players;
  final int currentPlayerIndex;
  final int previousPlayerIndex;
  final CricketVariant variant;
  final int sets;
  final int legs;

  const CricketBoardState({
    required this.players,
    required this.currentPlayerIndex,
    this.previousPlayerIndex = -1,
    this.variant = CricketVariant.classic,
    this.sets = 1,
    this.legs = 3,
  });

  CricketPlayerBoardInfo get currentPlayer => players[currentPlayerIndex];
}

// ===================================================================
// CRICKET BOARD WIDGET
// ===================================================================

const List<int> cricketSectors = [20, 19, 18, 17, 16, 15, 25];

class CricketBoardWidget extends StatelessWidget {
  final CricketBoardState state;

  final void Function(int sector)? onSectorTap;
  final void Function()? onTripleTap;
  final void Function()? onDoubleTap;
  final void Function()? onOkTap;
  final void Function()? onEraseLastHit;
  final void Function()? onUndoOpponent;
  final bool canUndoOpponent;

  /// Хиты за текущий подход (для визуализации полосок и h/t)
  final Map<int, int> currentTurnHits;

  final bool isTripleMode;
  final bool isDoubleMode;

  const CricketBoardWidget({
    super.key,
    required this.state,
    this.onSectorTap,
    this.onTripleTap,
    this.onDoubleTap,
    this.onOkTap,
    this.onEraseLastHit,
    this.onUndoOpponent,
    this.canUndoOpponent = false,
    this.currentTurnHits = const {},
    this.isTripleMode = false,
    this.isDoubleMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAmerican = state.variant == CricketVariant.american;

    return Column(
      children: [
        // Верхняя панель: карточки игроков + счёт между ними
        _buildPlayerBar(theme),
        // Строка с суммой очков (только American)
        if (isAmerican) _buildTotalPointsBar(theme),
        // Основное поле: сектора — занимает всё оставшееся место
        Expanded(child: _buildBoard(theme, isAmerican)),
        // Нижняя панель: Triple / Double / OK
        _buildInputButtons(theme),
      ],
    );
  }

  // ===================================================================
  // ПАНЕЛЬ ИГРОКОВ + СЧЁТ
  // ===================================================================

  Widget _buildPlayerBar(ThemeData theme) {
    final playerCount = state.players.length;

    return Container(
      height: 90, // +25%
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          Expanded(child: _buildPlayerCard(theme, 0)),
          if (playerCount >= 2) ...[
            const SizedBox(width: 6),
            _buildScoreCenter(theme),
            const SizedBox(width: 6),
            Expanded(child: _buildPlayerCard(theme, 1)),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreCenter(ThemeData theme) {
    final p0 = state.players[0];
    final p1 = state.players[1];
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sets — крупно
          Text(
            'Sets',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${p0.setsWon} — ${p1.setsWon}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          // Legs — чуть меньше
          Text(
            'Legs',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${p0.legsWon} — ${p1.legsWon}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(ThemeData theme, int playerIndex) {
    final p = state.players[playerIndex];
    final isActive = p.isActive;
    final isPrevious = playerIndex == state.previousPlayerIndex;

    return Container(
      height: 80, // +25%
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade900 : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Имя + бейджи
          Row(
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildBadge(theme, '${p.setsWon}S',
                  theme.colorScheme.tertiaryContainer),
              const SizedBox(width: 4),
              _buildBadge(theme, '${p.legsWon}L',
                  theme.colorScheme.secondaryContainer),
            ],
          ),
          const SizedBox(height: 6),
          // Average
          Text(
            p.avgHitsPerTurn != null
                ? 'ср: ${p.avgHitsPerTurn!.toStringAsFixed(1)} h/t'
                : 'ср: - h/t',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          // Last turn summary (только у завершившего ход)
          if (!isActive && isPrevious && p.lastTurnSummary != null)
            Text(
              p.lastTurnSummary!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(ThemeData theme, String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  // ===================================================================
  // СТРОКА СУММЫ ОЧКОВ (American)
  // ===================================================================

  Widget _buildTotalPointsBar(ThemeData theme) {
    final p0 = state.players[0];
    final p1 = state.players.length >= 2 ? state.players[1] : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${p0.totalPoints}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: p0.isActive ? Colors.green.shade300 : Colors.white70,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            ':',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white54,
              fontSize: 18,
            ),
          ),
          const SizedBox(width: 12),
          if (p1 != null)
            Text(
              '${p1.totalPoints}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: p1.isActive ? Colors.green.shade300 : Colors.white70,
                fontSize: 18,
              ),
            ),
        ],
      ),
    );
  }

  // ===================================================================
  // ОСНОВНОЕ ПОЛЕ — СЕКТОРА
  // ===================================================================

  Widget _buildBoard(ThemeData theme, bool isAmerican) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        return ListView.builder(
          itemCount: cricketSectors.length,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          itemBuilder: (context, index) {
            final sector = cricketSectors[index];
            return _buildBoardRow(theme, sector, isAmerican, totalWidth);
          },
        );
      },
    );
  }

  Widget _buildBoardRow(
      ThemeData theme, int sector, bool isAmerican, double totalWidth) {
    final sectorLabel = sector == 25 ? 'Bull' : '$sector';
    final playerCount = state.players.length;

    final allClosed = state.players.every(
      (p) => (p.sectors[sector] ?? const CricketSectorState()).isClosed,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 15), // ~30% от 52
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // --- Левая половина: Игрок 1 ---
          if (playerCount >= 1) ...[
            // h/t колонка (только для активного игрока)
            _buildHTColumn(theme, sector, 0),
            // Колонка points (только American)
            if (isAmerican) _buildPointsColumn(theme, sector, 0),
            // Closure-ячейка
            Expanded(
              flex: isAmerican ? 3 : 4,
              child: _buildClosureCell(theme, sector, 0),
            ),
          ],

          // --- Центр: СЕКТОР ---
          Expanded(
            flex: 3,
            child: _buildSectorCell(theme, sector, sectorLabel, allClosed),
          ),

          // --- Правая половина: Игрок 2 ---
          if (playerCount >= 2) ...[
            // Closure-ячейка
            Expanded(
              flex: isAmerican ? 3 : 4,
              child: _buildClosureCell(theme, sector, 1),
            ),
            // Колонка points (только American)
            if (isAmerican) _buildPointsColumn(theme, sector, 1),
            // h/t колонка (только для активного игрока)
            _buildHTColumn(theme, sector, 1),
          ],
        ],
      ),
    );
  }

  // ===================================================================
  // h/t КОЛОНКА (хиты за текущий подход)
  // ===================================================================

  Widget _buildHTColumn(ThemeData theme, int sector, int playerIndex) {
    final p = state.players[playerIndex];
    if (!p.isActive) return const SizedBox(width: 24);

    final turnHits = currentTurnHits[sector] ?? 0;

    return SizedBox(
      width: 24,
      child: Center(
        child: turnHits > 0
            ? Text(
                '$turnHits',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              )
            : null,
      ),
    );
  }

  // ===================================================================
  // ЦЕНТРАЛЬНАЯ ЯЧЕЙКА СЕКТОРА
  // ===================================================================

  Widget _buildSectorCell(
      ThemeData theme, int sector, String label, bool allClosed) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: allClosed ? Colors.grey.shade700 : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: allClosed ? Colors.white38 : Colors.green.shade600,
          width: allClosed ? 1 : 2,
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: allClosed ? Colors.white : Colors.green.shade400,
            ),
          ),
        ),
      ),
    );
  }

  // ===================================================================
  // CLOSURE-ЯЧЕЙКА — ТРИ ГОРИЗОНТАЛЬНЫЕ ПОЛОСКИ
  // ===================================================================

  Widget _buildClosureCell(ThemeData theme, int sector, int playerIndex) {
    final p = state.players[playerIndex];
    final sectorState = p.sectors[sector] ?? const CricketSectorState();
    final hits = sectorState.hits;
    final isClosed = sectorState.isClosed;
    final isActive = p.isActive;

    // Хиты за текущий подход — только для активного игрока
    final turnHits = isActive ? (currentTurnHits[sector] ?? 0) : 0;

    // Можно ли тапать
    final canTap = isActive && !state.players.every(
      (pl) => (pl.sectors[sector] ?? const CricketSectorState()).isClosed,
    );

    // Закрыт ли сектор у оппонента
    final opponentClosed = state.players.length >= 2 &&
        state.players
            .where((pl) => pl != p)
            .every((pl) => (pl.sectors[sector] ?? const CricketSectorState()).isClosed);

    // Базовая заливка: розовая если сектор закрыт у оппонента, но не у нас
    final bgColor = (opponentClosed && !isClosed)
        ? Colors.pink.shade900.withValues(alpha: 0.5)
        : Colors.grey.shade900;

    return GestureDetector(
      onTap: canTap ? () => onSectorTap?.call(sector) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(4),
          border: isClosed
              ? Border.all(color: Colors.green.shade400, width: 1)
              : null,
        ),
        child: Column(
          children: [
            // Верхняя полоска (3-й хит)
            Expanded(
              child: _buildStripe(
                filled: hits + turnHits >= 3,
              ),
            ),
            // Средняя полоска (2-й хит)
            Expanded(
              child: _buildStripe(
                filled: hits + turnHits >= 2,
              ),
            ),
            // Нижняя полоска (1-й хит)
            Expanded(
              child: _buildStripe(
                filled: hits + turnHits >= 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStripe({required bool filled}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: filled ? Colors.green.shade500 : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ===================================================================
  // КОЛОНКА POINTS (только American)
  // ===================================================================

  Widget _buildPointsColumn(ThemeData theme, int sector, int playerIndex) {
    final p = state.players[playerIndex];
    final sectorState = p.sectors[sector] ?? const CricketSectorState();

    return SizedBox(
      width: 28,
      child: Center(
        child: sectorState.points > 0
            ? Text(
                '${sectorState.points}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              )
            : null,
      ),
    );
  }

  // ===================================================================
  // ПАНЕЛЬ ВВОДА: Triple / Double / OK
  // ===================================================================

  Widget _buildInputButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: TRIPLE | DOUBLE
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: isTripleMode
                      ? FilledButton(
                          onPressed: onTripleTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text('TRIPLE',
                              style: TextStyle(fontSize: 14)),
                        )
                      : OutlinedButton(
                          onPressed: onTripleTap,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text('TRIPLE',
                              style: TextStyle(fontSize: 14)),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: isDoubleMode
                      ? FilledButton(
                          onPressed: onDoubleTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text('DOUBLE',
                              style: TextStyle(fontSize: 14)),
                        )
                      : OutlinedButton(
                          onPressed: onDoubleTap,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text('DOUBLE',
                              style: TextStyle(fontSize: 14)),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Row 2: [НАЗАД] [ИСПРАВИТЬ] | [ОК]
          Row(
            children: [
              // НАЗАД (откат хода соперника)
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: canUndoOpponent ? onUndoOpponent : null,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    icon: const Icon(Icons.undo, size: 16),
                    label: const Text('НАЗАД',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // ИСПРАВИТЬ (стереть последний хит)
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: onEraseLastHit,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    icon: const Icon(Icons.backspace_outlined, size: 16),
                    label: const Text('ИСПРАВИТЬ',
                        style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ОК — половина ширины (2 Expanded)
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 44,
                  child: FilledButton(
                    onPressed: onOkTap,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Text('OK', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
