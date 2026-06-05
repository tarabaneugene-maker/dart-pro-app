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

  /// Строка последнего подхода: "20-6 | 19-3"
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
  final void Function()? onOkTap;
  final void Function()? onEraseLastHit;

  /// Хиты за текущий подход (для визуализации полосок и h/t)
  final Map<int, int> currentTurnHits;

  final bool isTripleMode;

  const CricketBoardWidget({
    super.key,
    required this.state,
    this.onSectorTap,
    this.onTripleTap,
    this.onOkTap,
    this.onEraseLastHit,
    this.currentTurnHits = const {},
    this.isTripleMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAmerican = state.variant == CricketVariant.american;

    return Column(
      children: [
        // Верхняя панель: карточки игроков + счёт между ними
        _buildPlayerBar(theme),
        // Строка последнего подхода (вместо строки очков)
        _buildLastTurnBar(theme),
        // Основное поле: сектора — занимает всё оставшееся место
        Expanded(child: _buildBoard(theme, isAmerican)),
        // Нижняя панель: TRIPLE | ИСПРАВИТЬ | OK
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
      height: 90,
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
          Text(
            'Sets',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '${p0.setsWon} — ${p1.setsWon}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Legs',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '${p0.legsWon} — ${p1.legsWon}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerCard(ThemeData theme, int playerIndex) {
    final p = state.players[playerIndex];
    final isActive = p.isActive;
    final isAmerican = state.variant == CricketVariant.american;

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade900 : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: имя + бейджи SL
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
          const SizedBox(height: 4),
          // Average
          Text(
            p.avgHitsPerTurn != null
                ? 'ср: ${p.avgHitsPerTurn!.toStringAsFixed(1)} h/t'
                : 'ср: - h/t',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
          // TotalPoints (American) — правый нижний угол, крупно
          if (isAmerican)
            Expanded(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  '${p.totalPoints}',
                  style: TextStyle(
                    fontSize: 33,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.white : Colors.white54,
                  ),
                ),
              ),
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
  // СТРОКА ПОСЛЕДНЕГО ПОДХОДА (вместо строки очков)
  // ===================================================================

  Widget _buildLastTurnBar(ThemeData theme) {
    final p0 = state.players[0];
    final p1 = state.players.length >= 2 ? state.players[1] : null;

    final show0 = p0.lastTurnSummary != null;
    final show1 = p1?.lastTurnSummary != null;

    if (!show0 && !show1) {
      return const SizedBox(height: 0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
      ),
      child: Row(
        children: [
          // Игрок 0
          Expanded(
            child: show0
                ? Text(
                    p0.lastTurnSummary!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: p0.isActive
                          ? Colors.green.shade300
                          : Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                  )
                : const SizedBox.shrink(),
          ),
          // Разделитель
          if (show0 && show1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '|',
                style: TextStyle(
                  color: Colors.white24,
                  fontSize: 14,
                ),
              ),
            ),
          // Игрок 1
          Expanded(
            child: show1
                ? Text(
                    p1!.lastTurnSummary!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: p1.isActive
                          ? Colors.green.shade300
                          : Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // ОСНОВНОЕ ПОЛЕ — СЕКТОРА (без прокрутки, на всю высоту)
  // ===================================================================

  Widget _buildBoard(ThemeData theme, bool isAmerican) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        final gap = 3.0;
        final rowHeight =
            ((totalHeight - (cricketSectors.length - 1) * gap) /
                    cricketSectors.length)
                .clamp(36.0, double.infinity);

        return Column(
          children: cricketSectors.map((sector) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: sector == cricketSectors.last ? 0 : gap,
              ),
              child: SizedBox(
                height: rowHeight,
                child: _buildBoardRow(theme, sector, isAmerican, rowHeight),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildBoardRow(
      ThemeData theme, int sector, bool isAmerican, double rowHeight) {
    final sectorLabel = sector == 25 ? 'Bull' : '$sector';
    final playerCount = state.players.length;

    final allClosed = state.players.every(
      (p) => (p.sectors[sector] ?? const CricketSectorState()).isClosed,
    );

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // --- Левая половина: Игрок 1 ---
          if (playerCount >= 1)
            Expanded(
              child: Row(
                children: [
                  // info + closure — прижаты к левому краю
                  _buildInfoColumn(theme, sector, 0, isAmerican),
                  _buildClosureIndicators(theme, sector, 0),
                  const Spacer(),
                  // круг — по центру левой половины
                  _buildInputCircle(theme, sector, 0, rowHeight),
                  const Spacer(),
                ],
              ),
            ),

          // --- Центр: СЕКТОР (квадратный — ширина = высоте строки) ---
          SizedBox(
            width: rowHeight,
            height: rowHeight,
            child: _buildSectorCell(theme, sector, sectorLabel, allClosed),
          ),

          // --- Правая половина: Игрок 2 ---
          if (playerCount >= 2)
            Expanded(
              child: Row(
                children: [
                  const Spacer(),
                  // круг — по центру правой половины
                  _buildInputCircle(theme, sector, 1, rowHeight),
                  const Spacer(),
                  // closure + info — прижаты к правому краю
                  _buildClosureIndicators(theme, sector, 1),
                  _buildInfoColumn(theme, sector, 1, isAmerican),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ===================================================================
  // ОБЪЕДИНЁННАЯ КОЛОНКА: points (верх) + h/t (низ)
  // ===================================================================

  Widget _buildInfoColumn(
      ThemeData theme, int sector, int playerIndex, bool isAmerican) {
    final p = state.players[playerIndex];
    final sectorState = p.sectors[sector] ?? const CricketSectorState();
    final isActive = p.isActive;
    final turnHits = isActive ? (currentTurnHits[sector] ?? 0) : 0;

    return SizedBox(
      width: 28,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Верхняя строка: points (American)
          Expanded(
            child: Center(
              child: isAmerican && sectorState.points > 0
                  ? Text(
                      '${sectorState.points}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
          ),
          // Нижняя строка: h/t (хиты текущего подхода)
          Expanded(
            child: Center(
              child: turnHits > 0
                  ? Text(
                      '$turnHits',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  // ===================================================================
  // CLOSURE-ИНДИКАТОРЫ (квадратики, без тапа)
  // ===================================================================

  Widget _buildClosureIndicators(
      ThemeData theme, int sector, int playerIndex) {
    final p = state.players[playerIndex];
    final sectorState = p.sectors[sector] ?? const CricketSectorState();
    final hits = sectorState.hits;
    final isActive = p.isActive;
    final turnHits = isActive ? (currentTurnHits[sector] ?? 0) : 0;

    return SizedBox(
      width: 18,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 3-й хит
          _buildSquareIndicator(filled: hits + turnHits >= 3),
          const SizedBox(height: 2),
          // 2-й хит
          _buildSquareIndicator(filled: hits + turnHits >= 2),
          const SizedBox(height: 2),
          // 1-й хит
          _buildSquareIndicator(filled: hits + turnHits >= 1),
        ],
      ),
    );
  }

  Widget _buildSquareIndicator({required bool filled}) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: filled ? Colors.green.shade500 : Colors.grey.shade800,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ===================================================================
  // КРУГ-КНОПКА ДЛЯ ВВОДА (максимальный размер по высоте строки)
  // ===================================================================

  Widget _buildInputCircle(
      ThemeData theme, int sector, int playerIndex, double rowHeight) {
    final p = state.players[playerIndex];
    final sectorState = p.sectors[sector] ?? const CricketSectorState();
    final isActive = p.isActive;
    final isClosed = sectorState.isClosed;

    // Размер круга — максимально влезает по высоте строки
    final circleSize = (rowHeight - 6).clamp(24.0, 60.0);

    // Определяем цвет кнопки
    Color? fillColor;
    Color borderColor = Colors.white38;

    if (isActive) {
      // Активный игрок — кнопка с заливкой
      final opponent = state.players.length >= 2
          ? state.players[(playerIndex + 1) % state.players.length]
          : null;
      final opponentClosed = opponent != null
          ? (opponent.sectors[sector] ?? const CricketSectorState()).isClosed
          : false;

      if (isClosed && opponentClosed) {
        // У обоих закрыто — серый
        fillColor = Colors.grey.shade700;
        borderColor = Colors.grey.shade600;
      } else if (isClosed && !opponentClosed) {
        // У меня закрыто, у соперника нет — зелёный (могу набирать очки)
        fillColor = Colors.green.shade600;
        borderColor = Colors.green.shade400;
      } else if (!isClosed && opponentClosed) {
        // У соперника закрыто, у меня нет — светло-розовый
        fillColor = Colors.pink.shade200.withValues(alpha: 0.3);
        borderColor = Colors.pink.shade200;
      } else {
        // Оба не закрыты — светло-зелёный
        fillColor = Colors.green.shade200.withValues(alpha: 0.3);
        borderColor = Colors.green.shade300;
      }
    } else {
      // Неактивный игрок — только border
      fillColor = Colors.transparent;
      borderColor = Colors.white24;
    }

    // Если сектор закрыт у обоих — неактивен
    final allClosed = state.players.every(
      (pl) => (pl.sectors[sector] ?? const CricketSectorState()).isClosed,
    );
    final canTap = isActive && !allClosed;

    return GestureDetector(
      onTap: canTap ? () => onSectorTap?.call(sector) : null,
      child: Container(
        width: circleSize,
        height: circleSize,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          border: Border.all(color: borderColor, width: 1.5),
        ),
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
  // ПАНЕЛЬ ВВОДА: TRIPLE | ИСПРАВИТЬ | OK
  // ===================================================================

  Widget _buildInputButtons(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          // TRIPLE
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
          // ИСПРАВИТЬ
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
          // OK
          Expanded(
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
    );
  }
}
