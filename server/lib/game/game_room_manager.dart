import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/room.dart';

/// Менеджер игровых комнат
class GameRoomManager {
  final Map<String, Room> _roomsById = {};
  final Map<String, String> _roomsByCode = {}; // code -> roomId
  final Map<String, String> _playerRoom = {}; // userId -> roomId
  final Uuid _uuid = const Uuid();
  final Random _random = Random();

  /// Создать новую комнату
  Room createRoom(String userId, String userName,
      {bool isPrivate = false,
      String gameType = '501',
      Map<String, dynamic>? gameParams}) {
    final id = _uuid.v4();
    final code = _generateCode();

    final room = Room(
      id: id,
      code: code,
      players: [
        RoomPlayer(userId: userId, name: userName),
      ],
      isPrivate: isPrivate,
      gameType: gameType,
      gameParams: gameParams,
    );

    _roomsById[id] = room;
    _roomsByCode[code] = id;
    _playerRoom[userId] = id;

    return room;
  }

  /// Получить публичные комнаты (для лобби)
  List<Room> getPublicRooms() {
    return _roomsById.values
        .where((r) => r.status == RoomStatus.waiting && !r.isPrivate)
        .toList();
  }

  /// Запросить присоединение к комнате
  /// Возвращает (Room?, errorMessage)
  (Room?, String?) requestJoin(String roomId, String userId, String userName,
      {double avg = 0}) {
    final room = _roomsById[roomId];
    if (room == null) {
      return (null, 'Комната не найдена');
    }
    if (room.status != RoomStatus.waiting) {
      return (null, 'Игра уже началась');
    }
    if (room.isFull) {
      return (null, 'Комната заполнена');
    }
    if (room.playerByUserId(userId) != null) {
      return (null, 'Вы уже в этой комнате');
    }
    if (room.pendingPlayer != null) {
      return (null, 'Уже есть запрос на присоединение');
    }

    room.pendingPlayer = RoomPlayer(userId: userId, name: userName, avg: avg);
    return (room, null);
  }

  /// Принять запрос на присоединение (только создатель)
  /// Возвращает (Room?, errorMessage)
  (Room?, String?) acceptJoin(String roomId, String creatorUserId) {
    final room = _roomsById[roomId];
    if (room == null) return (null, 'Комната не найдена');
    if (room.creator?.userId != creatorUserId) {
      return (null, 'Только создатель может принять игрока');
    }
    if (room.pendingPlayer == null) {
      return (null, 'Нет запроса на присоединение');
    }

    // Добавляем игрока
    room.players.add(room.pendingPlayer!);
    _playerRoom[room.pendingPlayer!.userId] = roomId;
    room.pendingPlayer = null;

    // Начинаем игру
    room.status = RoomStatus.playing;
    room.startedAt = DateTime.now();

    return (room, null);
  }

  /// Отклонить запрос на присоединение (только создатель)
  /// Возвращает (Room?, errorMessage)
  (Room?, String?) rejectJoin(String roomId, String creatorUserId) {
    final room = _roomsById[roomId];
    if (room == null) return (null, 'Комната не найдена');
    if (room.creator?.userId != creatorUserId) {
      return (null, 'Только создатель может отклонить игрока');
    }
    if (room.pendingPlayer == null) {
      return (null, 'Нет запроса на присоединение');
    }

    final rejectedUserId = room.pendingPlayer!.userId;
    room.pendingPlayer = null;

    return (room, rejectedUserId);
  }

  /// Присоединиться к комнате по коду (приватной)
  /// Возвращает (Room?, errorMessage)
  (Room?, String?) joinRoomByCode(
      String code, String userId, String userName,
      {double avg = 0}) {
    final roomId = _roomsByCode[code.toUpperCase()];
    if (roomId == null) {
      return (null, 'Комната не найдена');
    }

    final room = _roomsById[roomId]!;
    if (room.status != RoomStatus.waiting) {
      return (null, 'Игра уже началась');
    }
    if (room.isFull) {
      return (null, 'Комната заполнена');
    }
    if (room.playerByUserId(userId) != null) {
      return (null, 'Вы уже в этой комнате');
    }

    // Для приватных комнат — сразу добавляем
    if (room.isPrivate) {
      room.players.add(RoomPlayer(userId: userId, name: userName, avg: avg));
      _playerRoom[userId] = roomId;
      room.status = RoomStatus.playing;
      room.startedAt = DateTime.now();
      return (room, null);
    }

    // Для публичных — через заявку
    return requestJoin(roomId, userId, userName, avg: avg);
  }

  /// Получить комнату по ID
  Room? getRoom(String roomId) => _roomsById[roomId];

  /// Получить комнату по коду
  Room? getRoomByCode(String code) {
    final roomId = _roomsByCode[code.toUpperCase()];
    if (roomId == null) return null;
    return _roomsById[roomId];
  }

  /// Получить комнату игрока
  Room? getPlayerRoom(String userId) {
    final roomId = _playerRoom[userId];
    if (roomId == null) return null;
    return _roomsById[roomId];
  }

  /// Обработать ход игрока
  Map<String, dynamic>? processThrow(
      String userId, int score, int legsToWin) {
    final room = getPlayerRoom(userId);
    if (room == null) return null;
    if (room.status != RoomStatus.playing) return null;

    final playerIndex = room.players.indexWhere((p) => p.userId == userId);
    if (playerIndex != room.currentPlayerIndex) return null;

    final currentScore = room.scores[playerIndex];

    if (score > currentScore) {
      return {
        'type': 'bust',
        'message': 'Сумма превышает остаток ($currentScore)',
      };
    }

    room.scores[playerIndex] = currentScore - score;
    room.legHistory[playerIndex].add(score);
    room.lastApproach[playerIndex] = score;
    room.dartsInLeg[playerIndex] += 3;

    if (room.scores[playerIndex] == 0) {
      room.legsWon[playerIndex]++;

      if (room.legsWon[playerIndex] >= legsToWin) {
        room.status = RoomStatus.finished;
        room.finishedAt = DateTime.now();
        return {
          'type': 'match_won',
          'winnerIndex': playerIndex,
          'scores': room.legsWon,
          'legHistory': room.legHistory,
        };
      }

      for (int i = 0; i < room.scores.length; i++) {
        room.scores[i] = 501;
        room.legHistory[i].clear();
        room.dartsInLeg[i] = 0;
        room.lastApproach[i] = null;
      }

      return {
        'type': 'leg_won',
        'winnerIndex': playerIndex,
        'scores': room.legsWon,
      };
    }

    room.currentPlayerIndex = (playerIndex + 1) % room.players.length;

    return {
      'type': 'throw_result',
      'playerIndex': playerIndex,
      'score': score,
      'newScore': room.scores[playerIndex],
      'currentPlayerIndex': room.currentPlayerIndex,
      'legHistory': room.legHistory,
      'dartsInLeg': room.dartsInLeg,
      'lastApproach': room.lastApproach,
    };
  }

  void updateHeartbeat(String userId) {
    final room = getPlayerRoom(userId);
    if (room == null) return;
    final player = room.playerByUserId(userId);
    if (player != null) {
      player.lastHeartbeat = DateTime.now();
    }
  }

  void checkTimeouts({Duration timeout = const Duration(seconds: 45)}) {
    final now = DateTime.now();
    for (final entry in _roomsById.entries) {
      final room = entry.value;
      for (final player in room.players) {
        if (player.isConnected &&
            now.difference(player.lastHeartbeat) > timeout) {
          player.isConnected = false;
        }
      }
    }
  }

  void removePlayer(String userId) {
    final room = getPlayerRoom(userId);
    if (room == null) return;

    room.players.removeWhere((p) => p.userId == userId);
    _playerRoom.remove(userId);

    if (room.isEmpty) {
      _roomsById.remove(room.id);
      _roomsByCode.remove(room.code);
    }
  }

  void removeRoom(String roomId) {
    final room = _roomsById.remove(roomId);
    if (room != null) {
      _roomsByCode.remove(room.code);
      for (final p in room.players) {
        _playerRoom.remove(p.userId);
      }
    }
  }

  List<Room> get activeRooms =>
      _roomsById.values.where((r) => r.status != RoomStatus.finished).toList();

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    String code;
    do {
      code = List.generate(6, (_) => chars[_random.nextInt(chars.length)]).join();
    } while (_roomsByCode.containsKey(code));
    return code;
  }
}
