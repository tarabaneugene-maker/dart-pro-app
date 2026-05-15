import 'dart:async';

/// Результат аутентификации
class AuthResult {
  final bool success;
  final String? userId;
  final String? login;
  final String? token;
  final String? error;

  AuthResult({
    required this.success,
    this.userId,
    this.login,
    this.token,
    this.error,
  });
}

/// Состояние комнаты
class RoomState {
  final String roomId;
  final String code;
  final List<RoomPlayerInfo> players;
  final String status;
  final int currentPlayerIndex;
  final List<int> scores;
  final List<int> legsWon;
  final List<int> dartsInLeg;
  final List<int?> lastApproach;
  final String gameType;
  final Map<String, dynamic> gameParams;
  final bool isPrivate;

  RoomState({
    required this.roomId,
    required this.code,
    required this.players,
    required this.status,
    required this.currentPlayerIndex,
    required this.scores,
    required this.legsWon,
    required this.dartsInLeg,
    required this.lastApproach,
    this.gameType = '501',
    Map<String, dynamic>? gameParams,
    this.isPrivate = false,
  }) : gameParams = gameParams ?? {};

  factory RoomState.fromJson(Map<String, dynamic> json) {
    final players = (json['players'] as List)
        .map((p) => RoomPlayerInfo.fromJson(p as Map<String, dynamic>))
        .toList();
    return RoomState(
      roomId: json['id'] as String,
      code: json['code'] as String,
      players: players,
      status: json['status'] as String,
      currentPlayerIndex: json['currentPlayerIndex'] as int? ?? 0,
      scores: (json['scores'] as List?)?.cast<int>() ?? [501, 501],
      legsWon: (json['legsWon'] as List?)?.cast<int>() ?? [0, 0],
      dartsInLeg: (json['dartsInLeg'] as List?)?.cast<int>() ?? [0, 0],
      lastApproach: (json['lastApproach'] as List?)
              ?.map((e) => e as int?)
              .toList() ??
          [null, null],
      gameType: json['gameType'] as String? ?? '501',
      gameParams: json['gameParams'] as Map<String, dynamic>? ?? {},
      isPrivate: json['isPrivate'] as bool? ?? false,
    );
  }
}

class RoomPlayerInfo {
  final String userId;
  final String name;
  final double avg;

  RoomPlayerInfo({required this.userId, required this.name, this.avg = 0});

  factory RoomPlayerInfo.fromJson(Map<String, dynamic> json) {
    return RoomPlayerInfo(
      userId: json['userId'] as String,
      name: json['name'] as String,
      avg: (json['avg'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Информация о комнате в лобби
class LobbyRoomInfo {
  final String id;
  final String code;
  final String creatorName;
  final double creatorAvg;
  final String gameType;
  final Map<String, dynamic> gameParams;
  final int playersCount;

  LobbyRoomInfo({
    required this.id,
    required this.code,
    required this.creatorName,
    required this.creatorAvg,
    required this.gameType,
    required this.gameParams,
    required this.playersCount,
  });

  factory LobbyRoomInfo.fromJson(Map<String, dynamic> json) {
    return LobbyRoomInfo(
      id: json['id'] as String,
      code: json['code'] as String,
      creatorName: json['creatorName'] as String,
      creatorAvg: (json['creatorAvg'] as num?)?.toDouble() ?? 0,
      gameType: json['gameType'] as String? ?? '501',
      gameParams: json['gameParams'] as Map<String, dynamic>? ?? {},
      playersCount: json['playersCount'] as int? ?? 1,
    );
  }
}

/// Событие от сервера
sealed class ServerEvent {}

class AuthOkEvent extends ServerEvent {
  final String userId;
  final String login;
  final String? token;
  AuthOkEvent({required this.userId, required this.login, this.token});
}

class ErrorEvent extends ServerEvent {
  final String message;
  ErrorEvent(this.message);
}

class RoomCreatedEvent extends ServerEvent {
  final String code;
  final RoomState room;
  RoomCreatedEvent({required this.code, required this.room});
}

class LobbyUpdateEvent extends ServerEvent {
  final List<LobbyRoomInfo> rooms;
  LobbyUpdateEvent(this.rooms);
}

class JoinRequestEvent extends ServerEvent {
  final String roomId;
  final RoomPlayerInfo player;
  JoinRequestEvent({required this.roomId, required this.player});
}

class JoinRequestedEvent extends ServerEvent {
  final String roomId;
  final String message;
  JoinRequestedEvent({required this.roomId, required this.message});
}

class JoinRejectedEvent extends ServerEvent {
  final String roomId;
  final String message;
  JoinRejectedEvent({required this.roomId, required this.message});
}

class GameStartedEvent extends ServerEvent {
  final RoomState room;
  GameStartedEvent(this.room);
}

class ThrowResultEvent extends ServerEvent {
  final int playerIndex;
  final int score;
  final int newScore;
  final int currentPlayerIndex;
  final List<int> dartsInLeg;
  final List<int?> lastApproach;

  ThrowResultEvent({
    required this.playerIndex,
    required this.score,
    required this.newScore,
    required this.currentPlayerIndex,
    required this.dartsInLeg,
    required this.lastApproach,
  });
}

class LegWonEvent extends ServerEvent {
  final int winnerIndex;
  final List<int> scores;
  LegWonEvent({required this.winnerIndex, required this.scores});
}

class MatchWonEvent extends ServerEvent {
  final int winnerIndex;
  final List<int> scores;
  MatchWonEvent({required this.winnerIndex, required this.scores});
}

class PlayerDisconnectedEvent extends ServerEvent {
  final String userId;
  PlayerDisconnectedEvent(this.userId);
}

class PlayerTimeoutEvent extends ServerEvent {
  final String userId;
  PlayerTimeoutEvent(this.userId);
}

class PongEvent extends ServerEvent {}

/// Абстрактный интерфейс бэкенда
abstract class BackendService {
  Future<void> connect(String url);
  void disconnect();

  Future<AuthResult> register(String login, String password);
  Future<AuthResult> login(String login, String password);
  Future<AuthResult> authWithToken(String token);

  Future<void> createRoom(String playerName,
      {bool isPrivate = false,
      String gameType = '501',
      Map<String, dynamic>? gameParams});
  Future<void> getLobby();
  Future<void> enterLobby();
  Future<void> leaveLobby();
  Future<void> requestJoin(String roomId, String playerName, {double avg = 0});
  Future<void> acceptJoin(String roomId);
  Future<void> rejectJoin(String roomId);
  Future<void> joinByCode(String code, String playerName, {double avg = 0});
  Future<void> leaveRoom();
  Future<void> sendThrow(int score);

  Stream<ServerEvent> get events;
  String? get savedToken;
  void saveToken(String token);
  void clearToken();
  void dispose();
}
