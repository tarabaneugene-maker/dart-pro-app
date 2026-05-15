/// Результат завершённого матча
class MatchResult {
  final String id;
  final String player1Id;
  final String player2Id;
  final int player1Score;
  final int player2Score;
  final double player1Avg;
  final double player2Avg;
  final String winnerId;
  final DateTime finishedAt;

  MatchResult({
    required this.id,
    required this.player1Id,
    required this.player2Id,
    required this.player1Score,
    required this.player2Score,
    required this.player1Avg,
    required this.player2Avg,
    required this.winnerId,
    required this.finishedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'player1Id': player1Id,
        'player2Id': player2Id,
        'player1Score': player1Score,
        'player2Score': player2Score,
        'player1Avg': player1Avg,
        'player2Avg': player2Avg,
        'winnerId': winnerId,
        'finishedAt': finishedAt.toIso8601String(),
      };
}
