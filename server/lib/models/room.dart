/// Статус комнаты
enum RoomStatus { waiting, playing, finished }

/// Игрок в комнате
class RoomPlayer {
  final String userId;
  final String name;
  double avg;
  bool isConnected;
  DateTime lastHeartbeat;

  RoomPlayer({
    required this.userId,
    required this.name,
    this.avg = 0,
    this.isConnected = true,
    DateTime? lastHeartbeat,
  }) : lastHeartbeat = lastHeartbeat ?? DateTime.now();
}

/// Комната для онлайн-игры
class Room {
  final String id;
  final String code; // короткий код для приглашения
  final List<RoomPlayer> players;
  RoomStatus status;
  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? finishedAt;

  // Тип и параметры игры
  String gameType; // '501', 'cricket'
  Map<String, dynamic> gameParams; // { 'legs': 5, 'in': 'double', 'out': 'double' }

  // Приватная (по коду) или публичная (в лобби)
  bool isPrivate;

  // Игрок, запросивший присоединение (не добавлен, пока создатель не подтвердит)
  RoomPlayer? pendingPlayer;

  // Игровое состояние
  int currentPlayerIndex = 0;
  List<int> scores = [501, 501];
  List<List<int>> legHistory = [[], []];
  List<int> legsWon = [0, 0];
  List<int> dartsInLeg = [0, 0];
  List<int?> lastApproach = [null, null];

  Room({
    required this.id,
    required this.code,
    required this.players,
    this.status = RoomStatus.waiting,
    this.gameType = '501',
    Map<String, dynamic>? gameParams,
    this.isPrivate = false,
    DateTime? createdAt,
  }) : gameParams = gameParams ?? {'legs': 5, 'in': 'double', 'out': 'double'},
       createdAt = createdAt ?? DateTime.now();

  bool get isFull => players.length >= 2;
  bool get isEmpty => players.isEmpty;

  RoomPlayer? get creator => players.isNotEmpty ? players.first : null;

  RoomPlayer? playerByUserId(String userId) {
    try {
      return players.firstWhere((p) => p.userId == userId);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'players': players
            .map((p) => {
              'userId': p.userId,
              'name': p.name,
              'avg': p.avg,
            })
            .toList(),
        'status': status.name,
        'gameType': gameType,
        'gameParams': gameParams,
        'isPrivate': isPrivate,
        'currentPlayerIndex': currentPlayerIndex,
        'scores': scores,
        'legsWon': legsWon,
        'dartsInLeg': dartsInLeg,
        'lastApproach': lastApproach,
      };

  /// Для лобби — только публичная информация
  Map<String, dynamic> toLobbyJson() => {
        'id': id,
        'code': code,
        'creatorName': creator?.name ?? '',
        'creatorAvg': creator?.avg ?? 0,
        'gameType': gameType,
        'gameParams': gameParams,
        'playersCount': players.length,
      };
}
