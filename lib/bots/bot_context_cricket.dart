import '../models/game_enums.dart';

/// Контекст для принятия решений ботом в Cricket
class CricketBotContext {
  /// hitsPerSector бота
  final Map<int, int> myHits;

  /// hitsPerSector соперника
  final Map<int, int> opponentHits;

  /// Вариант Cricket (Classic / American)
  final CricketVariant variant;

  const CricketBotContext({
    required this.myHits,
    required this.opponentHits,
    required this.variant,
  });

  /// Сектора в порядке приоритета (от большего номинала к меньшему)
  static const List<int> sectorPriority = [20, 19, 18, 17, 16, 15, 25];

  /// Сектора, которые бот ещё не закрыл (hits < 3)
  List<int> get unclosedSectors =>
      sectorPriority.where((s) => (myHits[s] ?? 0) < 3).toList();

  /// Сектора, которые соперник уже закрыл, а бот — нет (розовый приоритет)
  List<int> get opponentClosedSectors =>
      sectorPriority.where((s) {
        final my = myHits[s] ?? 0;
        final opp = opponentHits[s] ?? 0;
        return opp >= 3 && my < 3;
      }).toList();

  /// Сектора, которые бот закрыл, а соперник — нет (можно набирать очки в American)
  List<int> get myClosedSectors =>
      sectorPriority.where((s) {
        final my = myHits[s] ?? 0;
        final opp = opponentHits[s] ?? 0;
        return my >= 3 && opp < 3;
      }).toList();

  /// Сектора, открытые у обоих (можно бить, но без очков)
  List<int> get bothOpenSectors =>
      sectorPriority.where((s) {
        final my = myHits[s] ?? 0;
        final opp = opponentHits[s] ?? 0;
        return my < 3 && opp < 3;
      }).toList();

  /// Сектора, закрытые у обоих (бесполезны)
  List<int> get bothClosedSectors =>
      sectorPriority.where((s) {
        final my = myHits[s] ?? 0;
        final opp = opponentHits[s] ?? 0;
        return my >= 3 && opp >= 3;
      }).toList();
}
