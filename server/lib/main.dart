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

  // Grace-таймеры: roomId -> Timer (60 сек после turn_timeout)
  final Map<String, Timer> _graceTimers = {};
  // Флаг: был ли уже turn_timeout для комнаты (чтобы не спамить)
  final Set<String> _turnTimeoutSent = {};

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
      // Heartbeat обновляется через ping, таймауты хода проверяются отдельно
    });

    _timeoutTimer = Timer.periodic(_timeoutCheckInterval, (_) {
      _rooms.checkTimeouts();
      _checkTurnTimeouts();
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
      // Вся Flutter-статика без кэша — браузер всегда проверяет свежесть
      final isFlutterAsset = filePath.endsWith('.js') || filePath.endsWith('.wasm') || filePath.endsWith('.html');
      final cacheControl = isFlutterAsset ? 'no-cache, no-store, must-revalidate' : 'public, max-age=3600';
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
      case 'cricket_throw':
        _handleCricketThrow(ws, message);
        break;
      case 'ping':
        _handlePing(ws);
        break;
      case 'forfeit_request':
        // Активный игрок нажал «Завершить» в диалоге turn_timeout
        final userId = _clientUsers[ws];
        if (userId != null) {
          _handleForfeit(userId, reason: 'opponent_forfeit');
        }
        break;
      case 'check_active_game':
        _handleCheckActiveGame(ws);
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
    final targetUserId = message['targetUserId'] as String? ?? '';
    if (targetUserId.isEmpty) {
      _send(ws, {'type': 'error', 'message': 'Не указан игрок'});
      return;
    }

    final (room, error) = _rooms.acceptJoin(roomId, userId, targetUserId);
    if (room == null) {
      _send(ws, {'type': 'error', 'message': error ?? 'Ошибка'});
      return;
    }

    // Уведомляем обоих игроков
    final turnDeadline = room.turnStartTime != null
        ? room.turnStartTime!.millisecondsSinceEpoch + 120000
        : DateTime.now().millisecondsSinceEpoch + 120000;
    _broadcastToRoom(room, {
      'type': 'game_started',
      'room': room.toJson(),
      'turnDeadline': turnDeadline,
    });


    // Уведомляем всех оставшихся pendingPlayers, что игра началась без них
    for (final pending in room.pendingPlayers) {
      final pendingWs = _clients[pending.userId];
      if (pendingWs != null) {
        _send(pendingWs, {
          'type': 'join_rejected',
          'roomId': room.id,
          'creatorName': room.creator?.name ?? 'Создатель',
          'message': 'Игра началась без вас',
        });
      }
    }
    // Очищаем pendingPlayers
    room.pendingPlayers.clear();

    // Обновляем лобби — комната исчезла из списка
    _broadcastLobbyUpdate();

    print('🎮 Игра началась в комнате ${room.code}');

  }

  void _handleRejectJoin(WebSocketChannel ws, Map<String, dynamic> message) {
    final userId = _clientUsers[ws];
    if (userId == null) {
      _send(ws, {'type': 'error', 'message': 'Не авторизован'});
      return;
    }

    final roomId = message['roomId'] as String? ?? '';
    final targetUserId = message['targetUserId'] as String? ?? '';
    if (targetUserId.isEmpty) {
      _send(ws, {'type': 'error', 'message': 'Не указан игрок'});
      return;
    }

    final (room, rejectedUserId) = _rooms.rejectJoin(roomId, userId, targetUserId);
    if (room == null) {
      _send(ws, {'type': 'error', 'message': 'Ошибка'});
      return;
    }

    // Имя создателя для уведомления
    final creatorName = room.creator?.name ?? 'Создатель';

    // Уведомляем отклонённого игрока
    if (rejectedUserId != null) {
      final rejectedWs = _clients[rejectedUserId];
      if (rejectedWs != null) {
        _send(rejectedWs, {
          'type': 'join_rejected',
          'roomId': room.id,
          'creatorName': creatorName,
          'message': 'Создатель отклонил ваш запрос',
        });
      }
    }

    // Уведомляем создателя об обновлённом списке ожидающих
    _sendPendingPlayersUpdate(room);

    // Обновляем лобби — комната снова доступна
    _broadcastLobbyUpdate();
  }

  /// Отправить создателю комнаты обновлённый список ожидающих игроков
  void _sendPendingPlayersUpdate(Room room) {
    final creatorWs = _clients[room.creator?.userId];
    if (creatorWs != null) {
      _send(creatorWs, {
        'type': 'pending_players_updated',
        'roomId': room.id,
        'players': room.pendingPlayers
            .map((p) => {
              'userId': p.userId,
              'name': p.name,
              'avg': p.avg,
            })
            .toList(),
      });
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
      final turnDeadline = room.turnStartTime != null
          ? room.turnStartTime!.millisecondsSinceEpoch + 120000
          : DateTime.now().millisecondsSinceEpoch + 120000;
      _broadcastToRoom(room, {
        'type': 'game_started',
        'room': room.toJson(),
        'turnDeadline': turnDeadline,
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

    // Если игра идёт — техническое поражение
    if (room.status == RoomStatus.playing) {
      _handleForfeit(userId, reason: 'left');
      return;
    }

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

    final dartsUsed = message['dartsUsed'] as int?;

    // Берём legsToWin из gameParams комнаты (по умолчанию 3)
    final room = _rooms.getPlayerRoom(userId);
    final legsToWin = (room?.gameParams?['legs'] as int?) ?? 3;
    final result = _rooms.processThrow(userId, score, legsToWin,
        dartsUsed: dartsUsed);


    if (result == null) {
      _send(ws, {'type': 'error', 'message': 'Неверный ход'});
      return;
    }

    if (room == null) return;

    // Добавляем turnDeadline в ответ (абсолютный timestamp)
    result['turnDeadline'] = room.turnStartTime!.millisecondsSinceEpoch + 120000;


    if (result['type'] == 'match_won') {
      _saveMatchResult(room);
    }

    _broadcastToRoom(room, result);
  }

  void _handleCricketThrow(WebSocketChannel ws, Map<String, dynamic> message) {
    final userId = _clientUsers[ws];
    if (userId == null) {
      _send(ws, {'type': 'error', 'message': 'Не авторизован'});
      return;
    }

    final sectorHitsRaw = message['sectorHits'] as Map<String, dynamic>?;
    if (sectorHitsRaw == null) {
      _send(ws, {'type': 'error', 'message': 'Не указаны хиты по секторам'});
      return;
    }

    // Преобразуем ключи из String в int
    final sectorHits = sectorHitsRaw.map((k, v) => MapEntry(int.parse(k), v as int));

    final room = _rooms.getPlayerRoom(userId);
    final legsToWin = (room?.gameParams?['legs'] as int?) ?? 3;
    final result = _rooms.processCricketThrow(userId, sectorHits, legsToWin);

    if (result == null) {
      _send(ws, {'type': 'error', 'message': 'Неверный ход'});
      return;
    }

    if (room == null) return;

    result['turnDeadline'] = room.turnStartTime!.millisecondsSinceEpoch + 120000;

    if (result['type'] == 'cricket_match_won') {
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
      if (room != null && room.status == RoomStatus.playing) {
        // Помечаем игрока как отключённого, НЕ удаляем из комнаты
        final player = room.playerByUserId(userId);
        if (player != null) {
          player.isConnected = false;
        }
        // НЕ уведомляем соперника — полагаемся на таймер хода
      } else if (room != null) {
        // Если игра ещё не началась — просто удаляем
        _rooms.removePlayer(userId);
        _broadcastLobbyUpdate();
      }
    }
  }

  // ===================================================================
  // ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ
  // ===================================================================

  void _registerClient(WebSocketChannel ws, String userId) {
    final oldWs = _clients[userId];
    if (oldWs != null) {
      if (oldWs == ws) {
        // Тот же сокет — не закрываем себя
        return;
      }
      _clientUsers.remove(oldWs);
      oldWs.sink.close();
    }

    _clients[userId] = ws;
    _clientUsers[ws] = userId;

    // Проверяем, есть ли активная игра
    final room = _rooms.getPlayerRoom(userId);
    if (room != null && room.status == RoomStatus.playing) {
      // Отменяем grace-таймер, если был
      _graceTimers[room.id]?.cancel();
      _graceTimers.remove(room.id);
      _turnTimeoutSent.remove(room.id);

      final player = room.playerByUserId(userId);
      if (player != null) {
        player.isConnected = true;
      }

      // Вычисляем turnDeadline для вернувшегося игрока
      final turnDeadline = room.turnStartTime != null
          ? room.turnStartTime!.millisecondsSinceEpoch + 120000
          : DateTime.now().millisecondsSinceEpoch + 120000;

      // Отправляем состояние игры самому вернувшемуся игроку
      _send(ws, {
        'type': 'game_resume',
        'room': room.toJson(),
        'turnDeadline': turnDeadline,
      });


    }
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

    // toList() — защита от ConcurrentModificationError при удалении битых сокетов
    for (final ws in _lobbyClients.toList()) {
      try {
        ws.sink.add(data);
      } catch (_) {
        _lobbyClients.remove(ws);
      }
    }
  }

  /// Проверить таймауты ходов (2 минуты на ход)
  void _checkTurnTimeouts() {
    final now = DateTime.now();
    for (final room in _rooms.activeRooms) {
      if (room.status != RoomStatus.playing) continue;
      if (room.turnStartTime == null) continue;

      final elapsed = now.difference(room.turnStartTime!);
      final timeLeft = (120 - elapsed.inSeconds).clamp(0, 120);

      if (elapsed > const Duration(minutes: 2)) {
        final currentUserId = room.players[room.currentPlayerIndex].userId;
        print('⏰ Таймаут хода игрока $currentUserId');

        if (!_turnTimeoutSent.contains(room.id)) {
          // Первый раз — отправляем предупреждение сопернику
          _turnTimeoutSent.add(room.id);

          // Отправляем turn_timeout сопернику (активному игроку)
          final opponentIndex = room.currentPlayerIndex == 0 ? 1 : 0;
          final opponentWs = _clients[room.players[opponentIndex].userId];
          if (opponentWs != null) {
            _send(opponentWs, {
              'type': 'turn_timeout',
              'turnDeadline': 0,
              'room': room.toJson(),
            });
          }


          // Запускаем grace-таймер 60 секунд
          _graceTimers[room.id]?.cancel();
          _graceTimers[room.id] = Timer(const Duration(seconds: 60), () {
            // Grace-период истёк — форфейт
            _handleForfeit(currentUserId, reason: 'turn_timeout');
          });
        } else if (_graceTimers.containsKey(room.id)) {
          // Grace-таймер уже тикает — проверяем, не истёк ли
          // Timer сам сработает через 60 сек, ничего не делаем
        }
      }
    }
  }


  /// Обработать техническое поражение игрока
  void _handleForfeit(String userId, {required String reason}) {
    final room = _rooms.getPlayerRoom(userId);
    if (room == null || room.status != RoomStatus.playing) return;

    print('⚖️ Техническое поражение игрока $userId (причина: $reason)');

    // Отменяем grace-таймер, если был
    _graceTimers[room.id]?.cancel();
    _graceTimers.remove(room.id);
    _turnTimeoutSent.remove(room.id);

    // Определяем победителя

    final loserIndex = room.players.indexWhere((p) => p.userId == userId);
    if (loserIndex == -1) return;
    final winnerIndex = loserIndex == 0 ? 1 : 0;

    // Завершаем игру
    room.status = RoomStatus.finished;
    room.finishedAt = DateTime.now();

    // Сохраняем результат
    _saveMatchResult(room);

    // Уведомляем обоих игроков
    _broadcastToRoom(room, {
      'type': 'opponent_forfeit',
      'winnerIndex': winnerIndex,
      'loserIndex': loserIndex,
      'reason': reason,
    });

    // Удаляем комнату
    _rooms.removeRoom(room.id);
    _broadcastLobbyUpdate();
  }

  /// Проверить активную игру для игрока
  void _handleCheckActiveGame(WebSocketChannel ws) {
    final userId = _clientUsers[ws];
    if (userId == null) {
      _send(ws, {'type': 'no_active_game'});
      return;
    }

    final room = _rooms.getPlayerRoom(userId);
    if (room != null && room.status == RoomStatus.playing) {
      final turnDeadline = room.turnStartTime != null
          ? room.turnStartTime!.millisecondsSinceEpoch + 120000
          : DateTime.now().millisecondsSinceEpoch + 120000;
      _send(ws, {
        'type': 'game_resume',
        'room': room.toJson(),
        'turnDeadline': turnDeadline,
      });
    } else {


      _send(ws, {'type': 'no_active_game'});
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
