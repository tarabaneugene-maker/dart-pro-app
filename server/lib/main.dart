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
import 'package:mime/mime.dart';

/// Rate limiter: не более [maxRequests] за [windowDuration] на один IP
class _RateLimiter {
  final int maxRequests;
  final Duration windowDuration;
  final Map<String, _RateEntry> _entries = {};

  _RateLimiter({this.maxRequests = 30, this.windowDuration = const Duration(seconds: 10)});

  /// Возвращает true, если запрос разрешён
  bool allow(String key) {
    final now = DateTime.now();
    final entry = _entries[key];
    if (entry == null) {
      _entries[key] = _RateEntry(count: 1, windowStart: now);
      return true;
    }
    if (now.difference(entry.windowStart) > windowDuration) {
      _entries[key] = _RateEntry(count: 1, windowStart: now);
      return true;
    }
    entry.count++;
    return entry.count <= maxRequests;
  }

  /// Очистка старых записей
  void cleanUp() {
    final now = DateTime.now();
    _entries.removeWhere((_, entry) => now.difference(entry.windowStart) > windowDuration);
  }
}

class _RateEntry {
  int count;
  DateTime windowStart;
  _RateEntry({required this.count, required this.windowStart});
}

/// Главный сервер Dart Pro App
class GameServer {
  final Database _db = Database();
  late final AuthHandler _auth;
  late final GameRoomManager _rooms;
  final Uuid _uuid = const Uuid();

  // Rate limiters
  final _rateLimiter = _RateLimiter(maxRequests: 30, windowDuration: const Duration(seconds: 10));
  final _loginRateLimiter = _RateLimiter(maxRequests: 5, windowDuration: const Duration(seconds: 60));

  // Подключённые клиенты: userId -> WebSocket
  final Map<String, WebSocketChannel> _clients = {};
  final Map<WebSocketChannel, String> _clientUsers = {};

  // Клиенты в лобби (получают обновления)
  final Set<WebSocketChannel> _lobbyClients = {};

  Timer? _heartbeatTimer;
  Timer? _timeoutTimer;
  Timer? _rateLimitCleanupTimer;

  HttpServer? _server;

  static const _heartbeatInterval = Duration(seconds: 15);
  static const _timeoutCheckInterval = Duration(seconds: 30);
  // _legsToWin теперь берётся из gameParams комнаты

  Future<void> start({int? port, String? dbPath}) async {
    // Railway передаёт порт через переменную окружения PORT
    final actualPort = port ?? int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
    // Путь к БД из переменной окружения или по умолчанию
    final actualDbPath = dbPath ?? Platform.environment['DB_PATH'] ?? 'dart_pro.db';
    _db.init(actualDbPath);
    _auth = AuthHandler(_db);
    _rooms = GameRoomManager();

    _server = await HttpServer.bind(InternetAddress.anyIPv4, actualPort);
    print('🚀 Dart Pro Server запущен на порту $actualPort');

    // Graceful shutdown: обработка SIGTERM/SIGINT
    // SIGTERM не поддерживается на Windows — проверяем платформу
    if (!Platform.isWindows) {
      ProcessSignal.sigterm.watch().listen((_) {
        print('📥 Получен SIGTERM, завершаем работу...');
        shutdown();
      });
    }
    ProcessSignal.sigint.watch().listen((_) {
      print('📥 Получен SIGINT, завершаем работу...');
      shutdown();
    });

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      _checkHeartbeats();
    });

    _timeoutTimer = Timer.periodic(_timeoutCheckInterval, (_) {
      _rooms.checkTimeouts();
    });

    _rateLimitCleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _rateLimiter.cleanUp();
      _loginRateLimiter.cleanUp();
    });

    await for (final request in _server!) {
      try {
        _handleRequest(request);
      } catch (e) {
        print('❌ Ошибка обработки запроса: $e');
        try {
          request.response
            ..statusCode = 500
            ..write('Internal Server Error')
            ..close();
        } catch (_) {}
      }
    }
  }

  void _handleRequest(HttpRequest request) {
    final ip = request.connectionInfo?.remoteAddress.address ?? 'unknown';

    // Health check
    if (request.uri.path == '/health') {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'status': 'ok',
          'uptime': DateTime.now().toIso8601String(),
          'activeRooms': _rooms.activeRooms.length,
          'activePlayers': _clients.length,
        }))
        ..close();
      return;
    }

    // Rate limiting для всех запросов
    if (!_rateLimiter.allow(ip)) {
      request.response
        ..statusCode = 429
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'error': 'Слишком много запросов. Пожалуйста, подождите.',
          'retryAfter': 10,
        }))
        ..close();
      return;
    }

    if (request.uri.path == '/ws') {
      final ws = WebSocketTransformer.upgrade(request);
      ws.then((webSocket) {
        final channel = IOWebSocketChannel(webSocket);
        _handleConnection(channel, ip);
      }).catchError((e) {
        print('❌ Ошибка WebSocket upgrade: $e');
      });
    } else {
      _serveStatic(request);
    }
  }

  /// Раздаёт статику Flutter Web из папки build/web
  void _serveStatic(HttpRequest request) {
    final buildPath = 'build/web';
    String filePath;

    if (request.uri.path == '/' || request.uri.path.isEmpty) {
      filePath = '$buildPath/index.html';
    } else {
      filePath = '$buildPath${request.uri.path}';
    }

    final file = File(filePath);
    if (file.existsSync()) {
      final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
      // JS и WASM файлы не кэшируем — Flutter Web обновляется часто
      final isFlutterAsset = filePath.endsWith('.js') || filePath.endsWith('.wasm');
      final cacheControl = isFlutterAsset ? 'no-cache' : 'public, max-age=3600';
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.parse(mimeType)
        ..headers.set('Access-Control-Allow-Origin', '*')
        ..headers.set('Cache-Control', cacheControl)
        ..add(file.readAsBytesSync())
        ..close();
    } else {
      // SPA fallback: все неизвестные пути отдают index.html
      final indexFile = File('$buildPath/index.html');
      if (indexFile.existsSync()) {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..headers.set('Cache-Control', 'public, max-age=0')
          ..add(indexFile.readAsBytesSync())
          ..close();
      } else {
        request.response
          ..statusCode = 404
          ..write('Not Found. Собери Flutter Web: flutter build web --release')
          ..close();
      }
    }
  }

  void _handleConnection(WebSocketChannel ws, String ip) {
    print('🔌 Новое подключение с $ip');

    ws.stream.listen(
      (data) {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          _handleMessage(ws, message, ip);
      } catch (e) {
          print('❌ Ошибка обработки сообщения: $e');
          print('   Данные: $data');
          _send(ws, {'type': 'error', 'message': 'Некорректное сообщение'});
        }
      },
      onDone: () => _handleDisconnect(ws),
      onError: (_) => _handleDisconnect(ws),
    );
  }

  void _handleMessage(WebSocketChannel ws, Map<String, dynamic> message, String ip) {
    final type = message['type'] as String?;

    // Rate limiting для login/register
    if (type == 'login' || type == 'register') {
      if (!_loginRateLimiter.allow(ip)) {
        _send(ws, {
          'type': 'error',
          'message': 'Слишком много попыток входа. Подождите 60 секунд.',
        });
        return;
      }
    }

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
    final displayName = message['displayName'] as String? ?? login;

    final result = _auth.register(login, password, displayName: displayName);
    if (result['success'] == true) {
      final userId = result['user']['id'] as String;
      final user = result['user'] as Map<String, dynamic>;
      _registerClient(ws, userId);
      _send(ws, {
        'type': 'auth_ok',
        'userId': userId,
        'login': login,
        'displayName': user['displayName'] ?? login,
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
      final user = result['user'] as Map<String, dynamic>;
      _registerClient(ws, userId);
      _send(ws, {
        'type': 'auth_ok',
        'userId': userId,
        'login': login,
        'displayName': user['displayName'] ?? login,
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
        'displayName': user?.displayName ?? user?.login ?? '',
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
      _send(ws, {'type': 'error', 'code': 'not_authenticated', 'message': 'Не авторизован'});
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

    // Берём legsToWin из gameParams комнаты (по умолчанию 3)
    final room = _rooms.getPlayerRoom(userId);
    final legsToWin = (room?.gameParams?['legs'] as int?) ?? 3;
    final result = _rooms.processThrow(userId, score, legsToWin);
    if (result == null) {
      _send(ws, {'type': 'error', 'message': 'Неверный ход'});
      return;
    }

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
    print('🛑 Завершение работы сервера...');

    _heartbeatTimer?.cancel();
    _timeoutTimer?.cancel();
    _rateLimitCleanupTimer?.cancel();

    // Уведомляем всех клиентов
    for (final entry in _clients.entries) {
      try {
        entry.value.sink.add(jsonEncode({
          'type': 'server_shutdown',
          'message': 'Сервер завершает работу. Игры будут сохранены.',
        }));
      } catch (_) {}
    }

    // Сохраняем активные игры
    for (final room in _rooms.activeRooms) {
      if (room.status == RoomStatus.playing) {
        _saveMatchResult(room);
      }
    }

    // Закрываем все соединения
    for (final ws in _clients.values) {
      try {
        ws.sink.close();
      } catch (_) {}
    }

    _db.dispose();

    // Закрываем HTTP сервер
    try {
      _server?.close(force: true);
    } catch (_) {}

    print('✅ Сервер завершил работу');
  }
}

void main() async {
  final server = GameServer();
  await server.start();
}
