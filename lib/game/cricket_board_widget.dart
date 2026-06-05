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
  final CricketVariant variant;
  final int sets;
  final int legs;

  const CricketBoardState({
    required this.players,
    required this.currentPlayerIndex,
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

  /// Callback при тапе на closure-ячейку сектора
  final void Function(int sector)? onSectorTap;

  final void Function()? onTripleTap;
  final void Function()? onDoubleTap;
  final void Function()? onOkTap;

  /// Хиты за текущий подход (для подсветки в колонке h/t)
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
        // Верхняя панель: карточки игроков
        _buildPlayerCards(theme),
        const Divider(height: 1, thickness: 2),
        // Основное поле: сектора
        Expanded(child: _buildBoard(theme, isAmerican)),
        const Divider(height: 1, thickness: 2),
        // Нижняя панель: Triple / Double / OK
        _buildInputButtons(theme),
      ],
    );
  }

  // ===================================================================
  // КАРТОЧКИ ИГРОКОВ
  // ===================================================================

  Widget _buildPlayerCards(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: state.players.map((p) {
          final isActive = p.isActive;
          return Expanded(
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.shade900 : null,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight:
                                isActive ? FontWeight.bold : FontWeight.normal,
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
                  const SizedBox(height: 2),
                  // Среднее hits per turn
                  if (p.avgHitsPerTurn != null)
                    Text(
                      'ср: ${p.avgHitsPerTurn!.toStringAsFixed(1)} h/t',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  // Last turn summary
                  if (p.lastTurnSummary != null && p.lastTurnSummary!.isNotEmpty)
                    Text(
                      p.lastTurnSummary!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
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

  // ===================================================================
  // ОСНОВНОЕ ПОЛЕ — 10 КОЛОНОК
  // ===================================================================
  //
  //  Для 2 игроков:
  //  Колонки: 1=h/t, 2=points, 3-4=closure, 5-6=СЕКТОР, 7-8=closure, 9=points, 10=h/t
  //  Для Classic: колонки 2 и 9 скрыты, closure растянут
  //  Для 1 игрока: левая половина — игрок, правая — оппонент (без ввода)
  //
  // ===================================================================

  Widget _buildBoard(ThemeData theme, bool isAmerican) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // Пропорции колонок (доли от ширины)
        // h/t: 0.08, points: 0.10, closure: 0.20, sector: 0.24, closure: 0.20, points: 0.10, h/t: 0.08
        // Для Classic: h/t: 0.10, closure: 0.28, sector: 0.24, closure: 0.28, h/t: 0.10
        return ListView.builder(
          itemCount: cricketSectors.length,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          itemBuilder: (context, index) {
            final sector = cricketSectors[index];
            return _buildBoardRow(theme, sector, isAmerican, totalWidth);
          },
        );
      },
    );
  }

  Widget _buildBoardRow(ThemeData theme, int sector, bool isAmerican, double totalWidth) {
    final sectorLabel = sector == 25 ? 'Bull' : '$sector';
    final playerCount = state.players.length;

    // Определяем цвета сектора
    final activePlayer = state.currentPlayer;
    final activeSector = activePlayer.sectors[sector] ?? const CricketSectorState();
    final allClosed = state.players.every(
      (p) => (p.sectors[sector] ?? const CricketSectorState()).isClosed,
    );

    Color sectorColor;
    if (allClosed) {
      sectorColor = Colors.grey.shade700;
    } else if (!activeSector.isClosed) {
      sectorColor = Colors.green.shade700;
    } else {
      sectorColor = Colors.orange.shade700;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // --- Левая половина: Игрок 1 ---
          if (playerCount >= 1) ...[
            // Колонка 1: h/t (хиты за текущий подход)
            _buildHTColumn(theme, sector, 0),
            // Колонка 2: points (только American)
            if (isAmerican) _buildPointsColumn(theme, sector, 0),
            // Колонки 3-4: closure
            Expanded(
              flex: isAmerican ? 2 : 3,
              child: _buildClosureCell(theme, sector, 0),
            ),
          ],

          // --- Центр: СЕКТОР ---
          GestureDetector(
            onTap: () => onSectorTap?.call(sector),
            child: Container(
              width: totalWidth * 0.24,
              decoration: BoxDecoration(
                color: sectorColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Center(
                child: Text(
                  sectorLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // --- Правая половина: Игрок 2 (или оппонент) ---
          if (playerCount >= 2) ...[
            // Колонки 7-8: closure
            Expanded(
              flex: isAmerican ? 2 : 3,
              child: _buildClosureCell(theme, sector, 1),
            ),
            // Колонка 9: points (только American)
            if (isAmerican) _buildPointsColumn(theme, sector, 1),
            // Колонка 10: h/t
            _buildHTColumn(theme, sector, 1),
          ],
        ],
      ),
    );
  }

  // ===================================================================
  // ЯЧЕЙКИ
  // ===================================================================

  /// Колонка h/t (хиты за текущий подход)
  Widget _buildHTColumn(ThemeData theme, int sector, int playerIndex) {
    final turnHits = currentTurnHits[sector] ?? 0;

    return SizedBox(
      width: 28,
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

  /// Колонка points (только American)
  Widget _buildPointsColumn(ThemeData theme, int sector, int playerIndex) {
    final p = state.players[playerIndex];
    final sectorState = p.sectors[sector] ?? const CricketSectorState();

    return SizedBox(
      width: 32,
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

  /// Ячейка closure (тапабельная)
  Widget _buildClosureCell(ThemeData theme, int sector, int playerIndex) {
    final p = state.players[playerIndex];
    final sectorState = p.sectors[sector] ?? const CricketSectorState();
    final marker = _getMarker(sectorState.hits);
    final isClosed = sectorState.isClosed;
    final isActive = p.isActive;

    // Можно ли тапать: активный игрок и сектор не закрыт у всех
    final canTap = isActive && !state.players.every(
      (pl) => (pl.sectors[sector] ?? const CricketSectorState()).isClosed,
    );

    return GestureDetector(
      onTap: canTap ? () => onSectorTap?.call(sector) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isClosed
              ? Colors.grey.shade800
              : (isActive ? Colors.green.shade900 : Colors.grey.shade900),
          borderRadius: BorderRadius.circular(4),
          border: isClosed
              ? Border.all(color: Colors.grey.shade600, width: 1)
              : null,
        ),
        child: Center(
          child: Text(
            marker,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isClosed ? Colors.white : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  /// Маркер закрытия: пусто → / → X → ■
  String _getMarker(int hits) {
    if (hits <= 0) return '';
    if (hits == 1) return '/';
    if (hits == 2) return 'X';
    return '■';
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
