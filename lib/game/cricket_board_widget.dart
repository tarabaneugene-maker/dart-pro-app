import 'package:flutter/material.dart';
import '../models/game_enums.dart';

// ===================================================================
// DATA CLASSES
// ===================================================================

/// Состояние одного сектора для одного игрока
class CricketSectorState {
  /// Количество попаданий (0-3+)
  final int hits;

  /// Закрыт ли сектор (hits >= 3)
  bool get isClosed => hits >= 3;

  /// Очки, набранные в этом секторе (только American)
  final int points;

  const CricketSectorState({this.hits = 0, this.points = 0});
}

/// Информация об одном игроке для доски Cricket
class CricketPlayerBoardInfo {
  final String name;
  final int legsWon;
  final int setsWon;
  final double? average; // % попаданий
  final bool isActive;
  final int totalPoints; // общие очки (American)
  final Map<int, CricketSectorState> sectors; // 20,19,18,17,16,15,25(Bull)

  const CricketPlayerBoardInfo({
    required this.name,
    this.legsWon = 0,
    this.setsWon = 0,
    this.average,
    this.isActive = false,
    this.totalPoints = 0,
    required this.sectors,
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

/// Сектора для Cricket: 20, 19, 18, 17, 16, 15, Bull(25)
const List<int> cricketSectors = [20, 19, 18, 17, 16, 15, 25];

class CricketBoardWidget extends StatelessWidget {
  final CricketBoardState state;

  /// Callback при тапе на сектор (для ввода)
  final void Function(int sector)? onSectorTap;

  /// Callback при тапе на Triple
  final void Function()? onTripleTap;

  /// Callback при тапе на Double
  final void Function()? onDoubleTap;

  /// Callback при тапе на OK
  final void Function()? onOkTap;

  /// Текущие hits за подход (для отображения подсказки)
  final Map<int, int> currentTurnHits;

  /// Результаты последних 3 дротиков (для last approach)
  final List<String> lastDartResults;

  /// Выбран ли режим Triple
  final bool isTripleMode;

  /// Выбран ли режим Double
  final bool isDoubleMode;

  const CricketBoardWidget({
    super.key,
    required this.state,
    this.onSectorTap,
    this.onTripleTap,
    this.onDoubleTap,
    this.onOkTap,
    this.currentTurnHits = const {},
    this.lastDartResults = const [],
    this.isTripleMode = false,
    this.isDoubleMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAmerican = state.variant == CricketVariant.american;

    return Column(
      children: [
        // Верхняя часть: карточки игроков
        _buildPlayerCards(theme),
        const Divider(height: 1),
        // Сектора
        Expanded(
          child: _buildSectors(theme, isAmerican),
        ),
        // Last approach (горизонтально)
        _buildLastApproach(theme),
        const Divider(height: 1),
        // Score block (только American)
        if (isAmerican) _buildScoreBlock(theme),
        // Панель ввода: Triple / Double / OK
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
                  if (p.average != null)
                    Text(
                      'ср: ${p.average!.toStringAsFixed(1)}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
  // СЕКТОРА
  // ===================================================================

  Widget _buildSectors(ThemeData theme, bool isAmerican) {
    return ListView.builder(
      itemCount: cricketSectors.length,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      itemBuilder: (context, index) {
        final sector = cricketSectors[index];
        return _buildSectorRow(theme, sector, isAmerican);
      },
    );
  }

  Widget _buildSectorRow(ThemeData theme, int sector, bool isAmerican) {
    final sectorLabel = sector == 25 ? 'Bull' : '$sector';
    final playerCount = state.players.length;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Для каждого игрока — его колонка
          ...List.generate(playerCount, (i) {
            final p = state.players[i];
            final sectorState = p.sectors[sector] ?? const CricketSectorState();
            final turnHits = currentTurnHits[sector] ?? 0;
            return Expanded(
              child: _buildPlayerSectorCell(
                theme, sector, sectorState, turnHits, isAmerican, p.isActive,
              ),
            );
          }),
          // Центральная плашка с названием сектора
          GestureDetector(
            onTap: () => onSectorTap?.call(sector),
            child: Container(
              width: 48,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _getSectorColor(theme, sector),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                sectorLabel,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getSectorColor(ThemeData theme, int sector) {
    // Определяем, может ли активный игрок кидать в этот сектор
    final activePlayer = state.currentPlayer;
    final activeSector = activePlayer.sectors[sector] ?? const CricketSectorState();

    // Если сектор закрыт у всех — серый
    final allClosed = state.players.every(
      (p) => (p.sectors[sector] ?? const CricketSectorState()).isClosed,
    );
    if (allClosed) return Colors.grey.shade700;

    // Если активный игрок ещё не закрыл — зелёный (можно кидать)
    if (!activeSector.isClosed) return Colors.green.shade700;

    // Если закрыл только активный — оранжевый (можно набирать очки в American)
    return Colors.orange.shade700;
  }

  Widget _buildPlayerSectorCell(
    ThemeData theme,
    int sector,
    CricketSectorState sectorState,
    int turnHits,
    bool isAmerican,
    bool isActive,
  ) {
    final marker = _getMarker(sectorState.hits);
    final isClosed = sectorState.isClosed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Маркер закрытия
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isClosed
                  ? Colors.grey.shade800
                  : (isActive ? Colors.green.shade900 : null),
              borderRadius: BorderRadius.circular(4),
              border: isClosed
                  ? Border.all(color: Colors.grey.shade600, width: 2)
                  : null,
            ),
            child: Center(
              child: Text(
                marker,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isClosed ? Colors.white : Colors.grey.shade400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Подсказка hits за текущий подход (обнуляется после OK)
          if (turnHits > 0)
            Text(
              '$turnHits',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
              ),
            ),
          // Очки (только American)
          if (isAmerican && sectorState.points > 0)
            Text(
              '${sectorState.points}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
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
  // LAST APPROACH
  // ===================================================================

  Widget _buildLastApproach(ThemeData theme) {
    if (lastDartResults.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('← ', style: TextStyle(fontSize: 13)),
          ...lastDartResults.map((dart) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  dart,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  // ===================================================================
  // SCORE BLOCK (только American)
  // ===================================================================

  Widget _buildScoreBlock(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: state.players.map((p) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                p.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${p.totalPoints}',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: p.isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          );
        }).toList(),
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
        border: const Border(
          top: BorderSide(width: 2),
        ),
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
