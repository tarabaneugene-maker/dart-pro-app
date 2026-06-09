import 'dart:math';
import 'package:uuid/uuid.dart';
import '../models/room.dart';
import '../utils/dart_utils.dart';

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
    // Проверяем, нет ли уже заявки от этого игрока
    if (room.pendingPlayers.any((p) => p.userId == userId)) {
      return (null, 'Вы уже отправили запрос');
    }

    room.pendingPlayers.add(RoomPlayer(userId: userId, name: userName, avg: avg));
    _playerRoom[userId] = roomId;
    return (room, null);
  }

  /// Принять запрос на присоединение (только создатель)
  /// Возвращает (Room?, errorMessage)
  (Room?, String?) acceptJoin(String roomId, String creatorUserId, String targetUserId) {
    final room = _roomsById[roomId];
    if (room == null) return (null, 'Комната не найдена');
    if (room.creator?.userId != creatorUserId) {
      return (null, 'Только создатель может принять игрока');
    }

    final index = room.pendingPlayers.indexWhere((p) => p.userId == targetUserId);
    if (index == -1) {
      return (null, 'Запрос от этого игрока не найден');
    }

    // Добавляем игрока
    final player = room.pendingPlayers.removeAt(index);
    room.players.add(player);
    _playerRoom[player.userId] = roomId;

    // Начинаем игру
    room.status = RoomStatus.playing;
    room.startedAt = DateTime.now();
    room.turnStartTime = DateTime.now();

    return (room, null);
  }

  /// Отклонить запрос на присоединение (только создатель)
  /// Возвращает (Room?, errorMessage)
  (Room?, String?) rejectJoin(String roomId, String creatorUserId, String targetUserId) {
    final room = _roomsById[roomId];
    if (room == null) return (null, 'Комната не найдена');
    if (room.creator?.userId != creatorUserId) {
      return (null, 'Только создатель может отклонить игрока');
    }

    final index = room.pendingPlayers.indexWhere((p) => p.userId == targetUserId);
    if (index == -1) {
      return (null, 'Запрос от этого игрока не найден');
    }

    room.pendingPlayers.removeAt(index);
    return (room, targetUserId);
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
      room.turnStartTime = DateTime.now();
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

  /// Инициализировать Cricket-состояние для комнаты
  void _initCricketState(Room room) {
    final isAmerican = room.gameType == 'cricket_american';
    room.cricketVariant = isAmerican ? 'american' : 'classic';
    room.cricketHits = [
      <int, int>{},
      <int, int>{},
    ];
    room.cricketPoints = [
      <int, int>{},
      <int, int>{},
    ];
    room.cricketTotalPoints = [0, 0];
  }

  /// Обработать ход в Cricket
  /// [sectorHits] — Map<сектор, количество_хитов> за подход
  Map<String, dynamic>? processCricketThrow(
      String userId, Map<int, int> sectorHits, int legsToWin) {
    final room = getPlayerRoom(userId);
    if (room == null) return null;
    if (room.status != RoomStatus.playing) return null;

    final playerIndex = room.players.indexWhere((p) => p.userId == userId);
    if (playerIndex != room.currentPlayerIndex) return null;

    // Инициализируем Cricket-состояние если нужно
    if (room.cricketHits.isEmpty) {
      _initCricketState(room);
    }

    final opponentIndex = playerIndex == 0 ? 1 : 0;
    final isAmerican = room.cricketVariant == 'american';

    // Валидация: не больше 3 дротиков
    final totalHits = sectorHits.values.fold<int>(0, (a, b) => a + b);
    if (totalHits > 3) return null;

    // Обновляем хиты и очки
    for (final entry in sectorHits.entries) {
      final sector = entry.key;
      final hits = entry.value;

      // Пропускаем некорректные сектора
      if (sector < 15 && sector != 25) continue;
      if (sector > 25) continue;

      // Сколько уже хитов у игрока в этом секторе
      final currentHits = room.cricketHits[playerIndex][sector] ?? 0;
      final newHits = currentHits + hits;

      // Сколько хитов у соперника
      final opponentHits = room.cricketHits[opponentIndex][sector] ?? 0;

      // Если сектор уже закрыт у обоих — хиты не идут
      if (currentHits >= 3 && opponentHits >= 3) continue;

      // Если сектор закрыт у игрока — лишние хиты не идут
      if (currentHits >= 3) continue;

      // Сколько нужно до закрытия
      final needed = 3 - currentHits;
      final actualHits = hits.clamp(0, needed);

      // Обновляем хиты
      room.cricketHits[playerIndex][sector] = currentHits + actualHits;

      // Если сектор закрыт у соперника, а у нас нет — очки не начисляются
      // Если сектор закрыт у нас — лишние хиты не идут (уже обработано выше)
      // Если сектор не закрыт у соперника — excess хиты идут в очки (American)
      if (isAmerican && opponentHits >= 3 && currentHits < 3) {
        // Сектор закрыт соперником, у нас нет — excess не даёт очков
        // (только до закрытия)
      } else if (isAmerican && currentHits + actualHits >= 3) {
        // Excess хиты после закрытия — в очки
        final excess = hits - actualHits;
        if (excess > 0) {
          final points = excess * _sectorValue(sector);
          room.cricketPoints[playerIndex][sector] =
              (room.cricketPoints[playerIndex][sector] ?? 0) + points;
          room.cricketTotalPoints[playerIndex] += points;
        }
      }
    }

    room.lastApproach[playerIndex] = totalHits;
    room.dartsInLeg[playerIndex] += 3;
    room.turnStartTime = DateTime.now();

    // Проверка победы
    final winnerIndex = _checkCricketWin(room);
    if (winnerIndex != null) {
      room.legsWon[winnerIndex]++;

      if (room.legsWon[winnerIndex] >= legsToWin) {
        room.status = RoomStatus.finished;
        room.finishedAt = DateTime.now();
        return {
          'type': 'cricket_match_won',
          'winnerIndex': winnerIndex,
          'scores': room.legsWon,
          'cricketHits': room.cricketHits,
          'cricketPoints': room.cricketPoints,
          'cricketTotalPoints': room.cricketTotalPoints,
        };
      }

      // Новый лег — сброс Cricket-состояния
      for (int i = 0; i < room.players.length; i++) {
        room.cricketHits[i] = <int, int>{};
        room.cricketPoints[i] = <int, int>{};
        room.cricketTotalPoints[i] = 0;
        room.dartsInLeg[i] = 0;
        room.lastApproach[i] = null;
      }
      room.currentPlayerIndex = (winnerIndex + 1) % room.players.length;

      return {
        'type': 'cricket_leg_won',
        'winnerIndex': winnerIndex,
        'currentPlayerIndex': room.currentPlayerIndex,
        'scores': room.legsWon,
        'cricketHits': room.cricketHits,
        'cricketPoints': room.cricketPoints,
        'cricketTotalPoints': room.cricketTotalPoints,
      };
    }

    room.currentPlayerIndex = (playerIndex + 1) % room.players.length;

    return {
      'type': 'cricket_throw_result',
      'playerIndex': playerIndex,
      'sectorHits': sectorHits,
      'currentPlayerIndex': room.currentPlayerIndex,
      'cricketHits': room.cricketHits,
      'cricketPoints': room.cricketPoints,
      'cricketTotalPoints': room.cricketTotalPoints,
      'lastApproach': room.lastApproach,
      'dartsInLeg': room.dartsInLeg,
    };
  }

  /// Проверить, есть ли победитель в Cricket
  int? _checkCricketWin(Room room) {
    final isAmerican = room.cricketVariant == 'american';
    const sectors = [15, 16, 17, 18, 19, 20, 25];

    for (int p = 0; p < room.players.length; p++) {
      // Все сектора закрыты?
      bool allClosed = true;
      for (final s in sectors) {
        if ((room.cricketHits[p][s] ?? 0) < 3) {
          allClosed = false;
          break;
        }
      }
      if (!allClosed) continue;

      // Для American — нужно ещё иметь points >= opponent
      if (isAmerican) {
        final opponent = p == 0 ? 1 : 0;
        if (room.cricketTotalPoints[p] < room.cricketTotalPoints[opponent]) {
          continue;
        }
      }

      return p;
    }
    return null;
  }

  int _sectorValue(int sector) {
    if (sector == 25) return 25;
    return sector;
  }

  /// Обработать ход игрока (501)
  Map<String, dynamic>? processThrow(
      String userId, int score, int legsToWin,
      {int? dartsUsed}) {
    final room = getPlayerRoom(userId);
    if (room == null) return null;
    if (room.status != RoomStatus.playing) return null;

    final playerIndex = room.players.indexWhere((p) => p.userId == userId);
    if (playerIndex != room.currentPlayerIndex) return null;

    final currentScore = room.scores[playerIndex];

    // Проверка: сумма должна быть достижима тремя дротиками
    if (!isValidThreeDartScore(score)) {
      return {
        'type': 'bust',
        'message': 'Невозможная сумма ($score) для трёх дротиков',
      };
    }

    if (score > currentScore) {
      return {
        'type': 'bust',
        'message': 'Сумма превышает остаток ($currentScore)',
      };
    }

    room.scores[playerIndex] = currentScore - score;
    room.legHistory[playerIndex].add(score);
    room.lastApproach[playerIndex] = score;
    // Используем dartsUsed если передан, иначе +3
    final actualDarts = dartsUsed ?? 3;
    room.dartsInLeg[playerIndex] += actualDarts;
    room.turnStartTime = DateTime.now();

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
          'dartsInLeg': room.dartsInLeg,
        };
      }

      for (int i = 0; i < room.scores.length; i++) {
        room.scores[i] = 501;
        room.legHistory[i].clear();
        room.dartsInLeg[i] = 0;
        room.lastApproach[i] = null;
      }

      // Чередование: следующий лег начинает другой игрок
      room.currentPlayerIndex = (playerIndex + 1) % room.players.length;

      return {
        'type': 'leg_won',
        'winnerIndex': playerIndex,
        'currentPlayerIndex': room.currentPlayerIndex,
        'scores': room.legsWon,
        'dartsInLeg': room.dartsInLeg,
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
    room.pendingPlayers.removeWhere((p) => p.userId == userId);
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
