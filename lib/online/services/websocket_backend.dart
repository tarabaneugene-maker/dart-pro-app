import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'backend_service.dart';

/// Реализация BackendService через WebSocket
class WebSocketBackend implements BackendService {
  WebSocketChannel? _channel;
  final StreamController<ServerEvent> _eventController =
      StreamController<ServerEvent>.broadcast();

  Timer? _pingTimer;
  String? _token;
  bool _connected = false;

  static const _tokenKey = 'auth_token';

  @override
  String? get savedToken => _token;

  @override
  Future<void> connect(String url) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _connected = true;

      _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _send({'type': 'ping'});
      });

      _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            _handleMessage(message);
          } catch (e) {
            debugPrint('WebSocketBackend: ошибка парсинга: $e');
          }
        },
        onDone: () {
          _connected = false;
          _pingTimer?.cancel();
          debugPrint('WebSocketBackend: соединение закрыто');
        },
        onError: (error) {
          _connected = false;
          _pingTimer?.cancel();
          debugPrint('WebSocketBackend: ошибка: $error');
        },
      );

      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);
      if (_token != null) {
        _send({'type': 'auth', 'token': _token});
      }
    } catch (e) {
      debugPrint('WebSocketBackend: ошибка подключения: $e');
      rethrow;
    }
  }

  @override
  void disconnect() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _connected = false;
  }

  @override
  Future<AuthResult> register(String login, String password) async {
    final completer = Completer<AuthResult>();
    final sub = events.listen((event) {
      if (event is AuthOkEvent) {
        _token = event.token;
        _saveToken(event.token!);
        completer.complete(AuthResult(
          success: true,
          userId: event.userId,
          login: event.login,
          token: event.token,
        ));
      } else if (event is ErrorEvent) {
        completer.complete(AuthResult(success: false, error: event.message));
      }
    });

    _send({'type': 'register', 'login': login, 'password': password});
    return completer.future.timeout(const Duration(seconds: 10),
        onTimeout: () {
      sub.cancel();
      return AuthResult(success: false, error: 'Таймаут подключения');
    });
  }

  @override
  Future<AuthResult> login(String login, String password) async {
    final completer = Completer<AuthResult>();
    final sub = events.listen((event) {
      if (event is AuthOkEvent) {
        _token = event.token;
        _saveToken(event.token!);
        completer.complete(AuthResult(
          success: true,
          userId: event.userId,
          login: event.login,
          token: event.token,
        ));
      } else if (event is ErrorEvent) {
        completer.complete(AuthResult(success: false, error: event.message));
      }
    });

    _send({'type': 'login', 'login': login, 'password': password});
    return completer.future.timeout(const Duration(seconds: 10),
        onTimeout: () {
      sub.cancel();
      return AuthResult(success: false, error: 'Таймаут подключения');
    });
  }

  @override
  Future<AuthResult> authWithToken(String token) async {
    final completer = Completer<AuthResult>();
    final sub = events.listen((event) {
      if (event is AuthOkEvent) {
        completer.complete(AuthResult(
          success: true,
          userId: event.userId,
          login: event.login,
        ));
      } else if (event is ErrorEvent) {
        completer.complete(AuthResult(success: false, error: event.message));
      }
    });

    _send({'type': 'auth', 'token': token});
    return completer.future.timeout(const Duration(seconds: 10),
        onTimeout: () {
      sub.cancel();
      return AuthResult(success: false, error: 'Таймаут подключения');
    });
  }

  @override
  Future<void> createRoom(String playerName,
      {bool isPrivate = false,
      String gameType = '501',
      Map<String, dynamic>? gameParams}) async {
    _send({
      'type': 'create_room',
      'playerName': playerName,
      'isPrivate': isPrivate,
      'gameType': gameType,
      if (gameParams != null) 'gameParams': gameParams,
    });
  }

  @override
  Future<void> getLobby() async {
    _send({'type': 'get_lobby'});
  }

  @override
  Future<void> enterLobby() async {
    _send({'type': 'enter_lobby'});
  }

  @override
  Future<void> leaveLobby() async {
    _send({'type': 'leave_lobby'});
  }

  @override
  Future<void> requestJoin(String roomId, String playerName,
      {double avg = 0}) async {
    _send({
      'type': 'request_join',
      'roomId': roomId,
      'playerName': playerName,
      'avg': avg,
    });
  }

  @override
  Future<void> acceptJoin(String roomId) async {
    _send({'type': 'accept_join', 'roomId': roomId});
  }

  @override
  Future<void> rejectJoin(String roomId) async {
    _send({'type': 'reject_join', 'roomId': roomId});
  }

  @override
  Future<void> joinByCode(String code, String playerName,
      {double avg = 0}) async {
    _send({
      'type': 'join_by_code',
      'code': code,
      'playerName': playerName,
      'avg': avg,
    });
  }

  @override
  Future<void> leaveRoom() async {
    _send({'type': 'leave_room'});
  }

  @override
  Future<void> sendThrow(int score) async {
    _send({'type': 'throw', 'score': score});
  }

  @override
  Stream<ServerEvent> get events => _eventController.stream;

  @override
  void saveToken(String token) {
    _token = token;
    _saveToken(token);
  }

  @override
  void clearToken() {
    _token = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_tokenKey);
    });
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _eventController.close();
    _channel?.sink.close();
  }

  // ===================================================================
  // ВНУТРЕННЕЕ
  // ===================================================================

  void _send(Map<String, dynamic> data) {
    if (_channel != null && _connected) {
      try {
        _channel!.sink.add(jsonEncode(data));
      } catch (e) {
        debugPrint('WebSocketBackend: ошибка отправки: $e');
      }
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'auth_ok':
        _eventController.add(AuthOkEvent(
          userId: message['userId'] as String,
          login: message['login'] as String,
          token: message['token'] as String?,
        ));
        break;

      case 'error':
        _eventController.add(ErrorEvent(message['message'] as String? ?? ''));
        break;

      case 'room_created':
        _eventController.add(RoomCreatedEvent(
          code: message['code'] as String,
          room: RoomState.fromJson(message['room'] as Map<String, dynamic>),
        ));
        break;

      case 'lobby_update':
        final rooms = (message['rooms'] as List)
            .map((r) => LobbyRoomInfo.fromJson(r as Map<String, dynamic>))
            .toList();
        _eventController.add(LobbyUpdateEvent(rooms));
        break;

      case 'join_request':
        _eventController.add(JoinRequestEvent(
          roomId: message['roomId'] as String,
          player: RoomPlayerInfo.fromJson(
              message['player'] as Map<String, dynamic>),
        ));
        break;

      case 'join_requested':
        _eventController.add(JoinRequestedEvent(
          roomId: message['roomId'] as String,
          message: message['message'] as String? ?? '',
        ));
        break;

      case 'join_rejected':
        _eventController.add(JoinRejectedEvent(
          roomId: message['roomId'] as String,
          message: message['message'] as String? ?? '',
        ));
        break;

      case 'game_started':
        _eventController.add(GameStartedEvent(
          RoomState.fromJson(message['room'] as Map<String, dynamic>),
        ));
        break;

      case 'throw_result':
        _eventController.add(ThrowResultEvent(
          playerIndex: message['playerIndex'] as int,
          score: message['score'] as int,
          newScore: message['newScore'] as int,
          currentPlayerIndex: message['currentPlayerIndex'] as int,
          dartsInLeg: (message['dartsInLeg'] as List).cast<int>(),
          lastApproach: (message['lastApproach'] as List)
              .map((e) => e as int?)
              .toList(),
        ));
        break;

      case 'leg_won':
        _eventController.add(LegWonEvent(
          winnerIndex: message['winnerIndex'] as int,
          scores: (message['scores'] as List).cast<int>(),
        ));
        break;

      case 'match_won':
        _eventController.add(MatchWonEvent(
          winnerIndex: message['winnerIndex'] as int,
          scores: (message['scores'] as List).cast<int>(),
        ));
        break;

      case 'player_disconnected':
        _eventController
            .add(PlayerDisconnectedEvent(message['userId'] as String));
        break;

      case 'player_timeout':
        _eventController
            .add(PlayerTimeoutEvent(message['userId'] as String));
        break;

      case 'pong':
        _eventController.add(PongEvent());
        break;
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }
}
