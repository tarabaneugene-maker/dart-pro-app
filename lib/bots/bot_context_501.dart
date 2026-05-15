/// Контекст для бота в игре 501
/// Содержит информацию о текущем состоянии игры
class BotContext501 {
  final int remainingScore;
  final int opponentRemaining;
  final int dartsThrownInLeg;
  final bool isDoubleIn;
  final bool isDoubleOut;
  final bool isFirstDartOfLeg;

  BotContext501({
    required this.remainingScore,
    required this.opponentRemaining,
    required this.dartsThrownInLeg,
    required this.isDoubleIn,
    required this.isDoubleOut,
    required this.isFirstDartOfLeg,
  });

  /// Проверить, нужно ли выполнять Double In
  bool get needsDoubleIn => isDoubleIn && isFirstDartOfLeg;

  /// Проверить, находится ли бот в фазе финиша
  bool get isInCheckoutPhase => isDoubleOut && remainingScore <= 170;

  /// Проверить, является ли это прямым финишем
  bool get isDirectCheckoutAttempt => remainingScore <= 40;

  /// Проверить, находится ли бот в фазе setup
  bool get isInSetupPhase =>
      isDoubleOut && remainingScore > 40 && remainingScore <= 170;

  /// Получить количество оставшихся дротиков в подходе
  int get dartsLeftInTurn => 3 - (dartsThrownInLeg % 3);

  @override
  String toString() {
    return 'BotContext501{remainingScore: $remainingScore, '
        'opponentRemaining: $opponentRemaining, '
        'dartsThrownInLeg: $dartsThrownInLeg, '
        'isDoubleIn: $isDoubleIn, isDoubleOut: $isDoubleOut, '
        'isFirstDartOfLeg: $isFirstDartOfLeg}';
  }
}