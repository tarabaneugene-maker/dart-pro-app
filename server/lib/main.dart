import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'db/database.dart';
import 'auth/auth_handler.dart';
import 'game/game_room_manager.dart';
import 'models/room.dart';
import 'models/match_result.dart';
import 'package:uuid/uuid.dart';

/// Главный сервер Dart Pro App
class GameServer {
  final Database _db = Database();
  late final AuthHandler _auth;
  late final GameRoomManager _rooms;
  final Uuid _uuid = const Uuid();

  // Подключённые клиенты: userId -> WebSocket
  final Map<String, WebSocketChannel> _clients = {};
  final Map<WebSocketChannel, String> _clientUsers = {};

  // Клиенты в лобби (получают обновления)
  final Set<WebSocketChannel> _lobbyClients = {};

  Timer? _heartbeatTimer;
  Timer? _timeoutTimer;

  static const _heartbeatInterval = Duration(seconds: 15);
  static const _timeoutCheckInterval = Duration(seconds: 30);
  static const _legsToWin = 3;

  Future<void> start({int port = 8080, String dbPath = 'dart_pro.db'}) async {
    _db.init(dbPath);
    _auth = AuthHandler(_db);
    _rooms = GameRoomManager();

    final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
    print('🚀 Dart Pro Server запущен на порту $port');

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _checkHeartbeats();
    });

    _timeoutTimer = Timer.periodic(_timeoutCheckInterval, (_) {
      _rooms.checkTimeouts();
    });

    await for (final request in server) {
      if (request.uri.path == '/ws') {
        final ws = await WebSocketTransformer.upgrade(request);
        final channel = IOWebSocketChannel(ws);
        _handleConnection(channel);
      } else {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({
                'status': 'ok',
                'activeRooms': _rooms.activeRooms.length,
                'connectedClients': _clients.length,
              }))
          ..close();
      }
    }
  }

  void _handleConnection(WebSocketChannel ws) {
    print('🔌 Новое подключение');

    ws.stream.listen(
      (data) {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          _handleMessage(ws, message);
        } catch (e) {
          _send(ws, {'type': 'error', 'message': 'Некорректное сообщение'});
        }
      },
      onDone: () => _handleDisconnect(ws),
      onError: (_) => _handleDisconnect(ws),
    );
  }

  void _handleMessage(WebSocketChannel ws, Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'register':
        _handleRegister(ws, message);
        break;
      case 'login':
        _handleLogin(ws, message);
        break;
      case 'auth':
        _handleAuth(ws, message);
        break;
      case 'create_room':
        _handleCreateRoom(ws, message);
        break;
      case 'get_lobby':
        _handleGetLobby(ws);
        break;
      case 'enter_lobby':
        _handleEnterLobby(ws);
        break;
      case 'leave_lobby':
        _handleLeaveLobby(ws);
        break;
      case 'request_join':
        _handleRequestJoin(ws, message);
        break;
      case 'accept_join':
        _handleAcceptJoin(ws, message);
        break;
      case 'reject_join':
        _handleRejectJoin(ws, message);
        break;
      case 'join_by_code':
        _handleJoinByCode(ws, message);
        break;
      case 'leave_room':
        _handleLeaveRoom(ws);
        break;
      case 'throw':
        _handleThrow(ws, message);
        break;
      case 'ping':
        _handlePing(ws);
        break;
      default:
        _send(ws, {'type': 'error', 'message': 'Неизвестный тип: $type'});
    }
  }

  // ===================================================================
  // АУТЕНТИФИКАЦИЯ
  // ===================================================================

  void _handleRegister(WebSocketChannel ws, Map<String, dynamic> message) {
    final login = message['login'] as String? ?? '';
    final password = message['password'] as String? ?? '';

    final result = _auth.register(login, password);
    if (result['success'] == true) {
      final userId = result['user']['id'] as String;
      _registerClient(ws, userId);
      _send(ws, {
        'type': 'auth_ok',
        'userId': userId,
        'login': login,
        'token': result['token'],
      });
    } else {
      _send(ws, {'type': 'error', 'message': result['error']});
    }
  }

  void _handleLogin(WebSocketChannel ws, Map<String, dynamic> message) {
    final login = message['login'] as String? ?? '';
    final password = message['password'] as String? ?? '';

    final result = _auth.login(login, password);
    if (result['success'] == true) {
      final userId = result['user']['id'] as String;
      _registerClient(ws, userId);
      _send(ws, {
        'type': 'auth_ok',
        'userId': userId,
        'login': login,
        'token': result['token'],
      });
    } else {
      _send(ws, {'type': 'error', 'message': result['error']});
    }
  }

  void _handleAuth(WebSocketChannel ws, Map<String, dynamic> message) {
    final token = message['token'] as String? ?? '';
    final userId = _auth.validateToken(token);

    if (userId != null) {
      _registerClient(ws, userId);
      final user = _db.findUserById(userId);
      _send(ws, {
        'type': 'auth_ok',
        'userId': userId,
        'login': user?.login ?? '',
      });
    } else {
      _send(ws, {'type': 'error', 'message': 'Недействительный токен'});
    }
  }

  // ===================================================================
  // КОМНАТЫ И ЛОББИ
  // ===================================================================

  void _handleCreateRoom(WebSocketChannel ws, Map<String, dynamic> message) {
    final userId = _clientUsers[ws];
    if (userId == null) {
      _send(ws, {'type': 'error', 'message': 'Не авторизован'});
      return;
    }

    final playerName = message['playerName'] as String? ?? 'Игрок';
    final isPrivate = message['isPrivate'] as bool? ?? false;
    final gameType = message['gameType'] as String? ?? '501';
    final gameParams = message['gameParams'] as Map<String, dynamic>?;

    final room = _rooms.createRoom(userId, playerName,
        isPrivate: isPrivate, gameType: gameType, gameParams: gameParams);

    _send(ws, {
      'type': 'room_created',
      'code': room.code,
      'room': room.toJson(),
    });

    print('🏠 Создана комната ${room.code} ($gameType, private=$isPrivate)');

    // Обновляем лобби
    _broadcastLobbyUpdate();
  }

  void _handleGetLobby(WebSocketChannel ws) {
    final rooms = _rooms.getPublicRooms();
    _send(ws, {
      'type': 'lobby_update',
      'rooms': rooms.map((r) => r.toLobbyJson()).toList(),
    });
  }

  void _handleEnterLobby(WebSocketChannel ws) {
    _lobbyClients.add(ws);
    _handleGetLobby(ws);
  }

  void _handleLeaveLobby(WebSocketChannel ws) {
    _lobbyClients.remove(ws);
  }

  void _handleRequestJoin(WebSocketChannel ws, Map<String, dynamic> message) {
    final userId = _clientUsers[ws];
    if (userId == null) {
      _send(ws, {'type': 'error', 'message': 'Не авторизован'});
      return;
    }

    final roomId = message['roomId'] as String? ?? '';
    final playerName = message['playerName'] as String? ?? 'Игрок';
    final avg = (message['avg'] as num?)?.toDouble() ?? 0;

    final (room, error) = _rooms.requestJoin(roomId, userId, playerName, avg: avg);
    if (room == null) {
      _send(ws, {'type': 'error', 'message': error ?? 'Ошибка'});
      return;
    }

    // Уведомляем создателя
    final creatorWs = _clients[room.creator?.userId];
    if (creatorWs != null) {
      _send(creatorWs, {
        'type': 'join_request',
        'roomId': room.id,
        'player': {
          'userId': userId,
          'name': playerName,
          'avg': avg,
        },
      });
    }

    _send(ws, {
      'type': 'join_requested',
      'roomId': room.id,
      'message': 'Запрос отправлен, ожидайте подтверждения',
    });
  }

  void _handleAcceptJoin(WebSocketChannel ws, Map<String, dynamic> message) {
    final userId = _clientUsers[ws];
    if (userId == null) {
      _send(ws, {'type': 'error', 'message': 'Не авторизован'});
      return;
    }

    final roomId = message['roomId'] as String? ?? '';
    final (room, error) = _rooms.acceptJoin(roomId, userId);
    if (room == null) {
      _send(ws, {'type': 'error', 'message': error ?? 'Ошибка'});
      return;
    }

    // Уведомляем обоих игроков
    _broadcastToRoom(room, {
      'type': 'game_started',
      'room': room.toJson(),
    });

    print('🎮 Игра началась в комнате ${room.code}');
  }

  void _handleRejectJoin(WebSocketChannel ws, Map<String, dynamic> message) {
    final userId = _clientUsers[ws];
    if (userId == null) {
      _send(ws, {'type': 'error', 'message': 'Не авторизован'});
      return;
    }

    final roomId = message['roomId'] as String? ?? '';
    final (room, rejectedUserId) = _rooms.rejectJoin(roomId, userId);
    if (room == null) {
      _send(ws, {'type': 'error', 'message': 'Ошибка'});
      return;
    }

    // Уведомляем отклонённого игрока
    if (rejectedUserId != null) {
      final rejectedWs = _clients[rejectedUserId];
      if (rejectedWs != null) {
        _send(rejectedWs, {
          'type': 'join_rejected',
          'roomId': room.id,
          'message': 'Создатель отклонил ваш запрос',
        });
      }
    }
  }

  void _handleJoinByCode(WebSocketChannel ws, Map<String, dynamic> message) {
    final userId = _clientUsers[ws];
    if (userId == null) {
      _send(ws, {'type': 'error', 'message': 'Не авторизован'});
      return;
    }

    final code = message['code'] as String? ?? '';
    final playerName = message['playerName'] as String? ?? 'Игрок';
    final avg = (message['avg'] as num?)?.toDouble() ?? 0;

    final (room, error) =
        _rooms.joinRoomByCode(code, userId, playerName, avg: avg);
    if (room == null) {
      _send(ws, {'type': 'error', 'message': error ?? 'Ошибка'});
      return;
    }

    // Если приватная — сразу игра
    if (room.isPrivate) {
      _broadcastToRoom(room, {
        'type': 'game_started',
        'room': room.toJson(),
      });
    } else {
      // Публичная — уведомляем создателя о заявке
      final creatorWs = _clients[room.creator?.userId];
      if (creatorWs != null) {
        _send(creatorWs, {
          'type': 'join_request',
          'roomId': room.id,
          'player': {
            'userId': userId,
            'name': playerName,
            'avg': avg,
          },
        });
      }
      _send(ws, {
        'type': 'join_requested',
        'roomId': room.id,
        'message': 'Запрос отправлен, ожидайте подтверждения',
      });
    }
  }

  void _handleLeaveRoom(WebSocketChannel ws) {
    final userId = _clientUsers[ws];
    if (userId == null) return;

    final room = _rooms.getPlayerRoom(userId);
    if (room == null) return;

    // Если создатель покидает — удаляем комнату
    if (room.creator?.userId == userId) {
      _rooms.removeRoom(room.id);
      _broadcastLobbyUpdate();
    } else {
      _rooms.removePlayer(userId);
    }
  }

  // ===================================================================
  // ИГРОВЫЕ ДЕЙСТВИЯ
  // ===================================================================

  void _handleThrow(WebSocketChannel ws, Map<String, dynamic> message) {
    final userId = _clientUsers[ws];
    if (userId == null) {
      _send(ws, {'type': 'error', 'message': 'Не авторизован'});
      return;
    }

    final score = message['score'] as int?;
    if (score == null) {
      _send(ws, {'type': 'error', 'message': 'Не указан счёт'});
      return;
    }

    final result = _rooms.processThrow(userId, score, _legsToWin);
    if (result == null) {
      _send(ws, {'type': 'error', 'message': 'Неверный ход'});
      return;
    }

    final room = _rooms.getPlayerRoom(userId);
    if (room == null) return;

    if (result['type'] == 'match_won') {
      _saveMatchResult(room);
    }

    _broadcastToRoom(room, result);
  }

  void _handlePing(WebSocketChannel ws) {
    final userId = _clientUsers[ws];
    if (userId != null) {
      _rooms.updateHeartbeat(userId);
    }
    _send(ws, {'type': 'pong'});
  }

  void _handleDisconnect(WebSocketChannel ws) {
    final userId = _clientUsers.remove(ws);
    _lobbyClients.remove(ws);
    if (userId != null) {
      _clients.remove(userId);
      print('❌ Отключился пользователь $userId');

      final room = _rooms.getPlayerRoom(userId);
      if (room != null) {
        _broadcastToRoom(room, {
          'type': 'player_disconnected',
          'userId': userId,
        });
      }

      _rooms.removePlayer(userId);
      _broadcastLobbyUpdate();
    }
  }

  // ===================================================================
  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ===================================================================

  void _registerClient(WebSocketChannel ws, String userId) {
    final oldWs = _clients[userId];
    if (oldWs != null) {
      _clientUsers.remove(oldWs);
      oldWs.sink.close();
    }

    _clients[userId] = ws;
    _clientUsers[ws] = userId;
  }

  void _send(WebSocketChannel ws, Map<String, dynamic> data) {
    try {
      ws.sink.add(jsonEncode(data));
    } catch (_) {}
  }

  void _broadcastToRoom(Room room, Map<String, dynamic> data) {
    final encoded = jsonEncode(data);
    for (final player in room.players) {
      final ws = _clients[player.userId];
      if (ws != null) {
        try {
          ws.sink.add(encoded);
        } catch (_) {}
      }
    }
  }

  void _broadcastLobbyUpdate() {
    final rooms = _rooms.getPublicRooms();
    final data = jsonEncode({
      'type': 'lobby_update',
      'rooms': rooms.map((r) => r.toLobbyJson()).toList(),
    });

    for (final ws in _lobbyClients) {
      try {
        ws.sink.add(data);
      } catch (_) {
        _lobbyClients.remove(ws);
      }
    }
  }

  void _checkHeartbeats() {
    final now = DateTime.now();
    for (final entry in _clients.entries) {
      final room = _rooms.getPlayerRoom(entry.key);
      if (room == null) continue;
      final player = room.playerByUserId(entry.key);
      if (player != null &&
          now.difference(player.lastHeartbeat) >
              const Duration(seconds: 45)) {
        player.isConnected = false;
        _broadcastToRoom(room, {
          'type': 'player_timeout',
          'userId': entry.key,
        });
      }
    }
  }

  void _saveMatchResult(Room room) {
    final winnerIndex = room.legsWon[0] > room.legsWon[1] ? 0 : 1;

    final match = MatchResult(
      id: _uuid.v4(),
      player1Id: room.players[0].userId,
      player2Id: room.players[1].userId,
      player1Score: room.legsWon[0],
      player2Score: room.legsWon[1],
      player1Avg: _calculateAverage(room.legHistory[0]),
      player2Avg: _calculateAverage(room.legHistory[1]),
      winnerId: room.players[winnerIndex].userId,
      finishedAt: DateTime.now(),
    );

    _db.saveMatch(match);

    _db.updateStatsAfterMatch(
      room.players[0].userId,
      room.legHistory[0].fold(0, (a, b) => a + b),
      room.dartsInLeg[0],
      winnerIndex == 0,
    );
    _db.updateStatsAfterMatch(
      room.players[1].userId,
      room.legHistory[1].fold(0, (a, b) => a + b),
      room.dartsInLeg[1],
      winnerIndex == 1,
    );
  }

  double _calculateAverage(List<int> history) {
    if (history.isEmpty) return 0;
    final total = history.fold<int>(0, (a, b) => a + b);
    return total / history.length;
  }

  void shutdown() {
    _heartbeatTimer?.cancel();
    _timeoutTimer?.cancel();
    for (final ws in _clients.values) {
      ws.sink.close();
    }
    _db.dispose();
  }
}

void main() async {
  final server = GameServer();
  await server.start();
}
