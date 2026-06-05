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
  final double? avgHitsPerTurn; // среднее hits за подход
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
  final int previousPlayerIndex; // кто только что бросил
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

  /// Хиты за текущий подход (для визуализации полосок)
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
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          // Левый игрок
          Expanded(child: _buildPlayerCard(theme, 0)),
          // Счёт между плашками
          if (playerCount >= 2) ...[
            const SizedBox(width: 4),
            _buildScoreCenter(theme),
            const SizedBox(width: 4),
            // Правый игрок
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
      width: 56,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${p0.setsWon}S - ${p1.setsWon}S',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          Text(
            '${p0.legsWon}L - ${p1.legsWon}L',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
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
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildBadge(theme, '${p.setsWon}S',
                  theme.colorScheme.tertiaryContainer),
              const SizedBox(width: 3),
              _buildBadge(theme, '${p.legsWon}L',
                  theme.colorScheme.secondaryContainer),
            ],
          ),
          const SizedBox(height: 2),
          // avg h/t
          Text(
            p.avgHitsPerTurn != null
                ? 'ср: ${p.avgHitsPerTurn!.toStringAsFixed(1)} h/t'
                : 'ср: - h/t',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          // Last turn — только у завершившего ход (не активного)
          if (!isActive && isPrevious && p.lastTurnSummary != null)
            Text(
              p.lastTurnSummary!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(ThemeData theme, String text, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
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

    // Определяем состояние сектора
    final allClosed = state.players.every(
      (p) => (p.sectors[sector] ?? const CricketSectorState()).isClosed,
    );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      height: 52,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // --- Левая половина: Игрок 1 ---
          if (playerCount >= 1) ...[
            // Колонка points (только American)
            if (isAmerican)
              _buildPointsColumn(theme, sector, 0),
            // Closure-ячейка (три полоски)
            Expanded(
              flex: isAmerican ? 3 : 4,
              child: _buildClosureCell(theme, sector, 0),
            ),
          ],

          // --- Центр: СЕКТОР ---
          _buildSectorCell(theme, sector, sectorLabel, allClosed),

          // --- Правая половина: Игрок 2 ---
          if (playerCount >= 2) ...[
            // Closure-ячейка
            Expanded(
              flex: isAmerican ? 3 : 4,
              child: _buildClosureCell(theme, sector, 1),
            ),
            // Колонка points (только American)
            if (isAmerican)
              _buildPointsColumn(theme, sector, 1),
          ],
        ],
      ),
    );
  }

  // ===================================================================
  // ЦЕНТРАЛЬНАЯ ЯЧЕЙКА СЕКТОРА
  // ===================================================================

  Widget _buildSectorCell(
      ThemeData theme, int sector, String label, bool allClosed) {
    return Container(
      width: 64,
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

    // Хиты за текущий подход (для визуализации тапа)
    final turnHits = currentTurnHits[sector] ?? 0;

    // Можно ли тапать: активный игрок и сектор не закрыт у всех
    final canTap = isActive && !state.players.every(
      (pl) => (pl.sectors[sector] ?? const CricketSectorState()).isClosed,
    );

    // Определяем, закрыт ли сектор у оппонента (для розовой подсветки)
    final opponentClosed = state.players.length >= 2 &&
        state.players
            .where((pl) => pl != p)
            .every((pl) => (pl.sectors[sector] ?? const CricketSectorState()).isClosed);

    // Цвет полосок
    Color stripeColor;
    if (opponentClosed && !isClosed) {
      stripeColor = Colors.pink.shade300; // розовый — проблема
    } else {
      stripeColor = Colors.green.shade500;
    }

    return GestureDetector(
      onTap: canTap ? () => onSectorTap?.call(sector) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
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
                color: stripeColor,
              ),
            ),
            // Средняя полоска (2-й хит)
            Expanded(
              child: _buildStripe(
                filled: hits + turnHits >= 2,
                color: stripeColor,
              ),
            ),
            // Нижняя полоска (1-й хит)
            Expanded(
              child: _buildStripe(
                filled: hits + turnHits >= 1,
                color: stripeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStripe({required bool filled, required Color color}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: filled ? color : Colors.grey.shade800,
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
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
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
              height: 48,
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
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: onOkTap,
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
    );
  }
}
