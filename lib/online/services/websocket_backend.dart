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
  Timer? _reconnectTimer;
  String? _token;
  bool _connected = false;
  String? _lastUrl;
  bool _disposed = false;

  // Защита от гонок
  int _connectionGeneration = 0;
  StreamSubscription? _streamSub;
  final List<Map<String, dynamic>> _outbox = [];

  // Request-response для auth
  Completer<Map<String, dynamic>>? _pendingAuth;
  bool _authInProgress = false;
  Completer<void>? _authReady; // завершается когда reauth закончен
  bool _reauthInProgress = false; // флаг что reauth уже идёт
  String? _userId; // userId текущего пользователя

  static const _tokenKey = 'auth_token';

  @override
  bool get isConnected => _connected;

  @override
  Future<void> waitForConnection() async {
    if (_connected) return;
    // Ждём пока _connected станет true (максимум 5 секунд)
    for (var i = 0; i < 50; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (_connected) return;
    }
  }

  /// НОВОЕ: гарантировать, что соединение есть (если нет — переподключиться)
  Future<void> ensureConnected() async {
    if (_connected && _channel != null) return;
    // Сначала подождать — может reconnect уже идёт
    await waitForConnection();
    if (_connected && _channel != null) return; // дождались!
    if (_lastUrl != null) {
      _reconnectTimer?.cancel(); // отменить запланированный reconnect
      await connect(_lastUrl!);
      return;
    }
    throw StateError('Нет URL сервера');
  }

  /// Дождаться завершения reauth (если он ещё идёт)
  Future<void> waitForAuth() async {
    if (_authReady != null) {
      try {
        await _authReady!.future.timeout(const Duration(seconds: 10));
      } on TimeoutException {
        // reauth не завершился — продолжаем, createRoom проверит _token
      }
    }
  }

  @override
  String? get savedToken => _token;

  @override
  String? get currentUserId => _userId;

  @override
  Future<void> connect(String url) async {
    _lastUrl = url;
    _disposed = false;

    // === A2: закрыть старое соединение ===
    final gen = ++_connectionGeneration;
    await _streamSub?.cancel();
    _streamSub = null;
    _pingTimer?.cancel();
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _connected = false;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel!.ready.timeout(const Duration(seconds: 10));

      // Если за время подключения появилось новое поколение — выходим
      if (gen != _connectionGeneration || _disposed) return;

      _connected = true;
      debugPrint('WebSocketBackend: подключено к $url');

      _pingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _send({'type': 'ping'});
      });

      _streamSub = _channel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data as String) as Map<String, dynamic>;
            _handleMessage(message);
          } catch (e, stack) {
            debugPrint('WebSocketBackend: ошибка обработки сообщения: $e\n$stack');
          }
        },
        onDone: () {
          debugPrint('WebSocketBackend: соединение закрыто');
          if (gen != _connectionGeneration) return; // игнорировать старый сокет
          _onDisconnected();
        },
        onError: (error) {
          debugPrint('WebSocketBackend: ошибка стрима: $error');
          if (gen != _connectionGeneration) return; // игнорировать старый сокет
          _onDisconnected();
        },
      );

      // Токен читаем
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenKey);

      // === A3: повторная авторизация после connect (fire-and-forget) ===
      _authReady = Completer<void>();
      unawaited(_reauthenticateAfterConnect().whenComplete(() {
        _authReady?.complete();
      }));

      // === A1: отправить накопившиеся сообщения ===
      _flushOutbox();
    } catch (e) {
      debugPrint('WebSocketBackend: ошибка подключения: $e');
      if (gen != _connectionGeneration) return; // игнорировать старый сокет
      _onDisconnected();
      rethrow;
    }
  }

  /// A3: повторная авторизация после каждого connect/reconnect
  /// Использует отдельный Completer, чтобы не конкурировать с _performAuth()
  Future<void> _reauthenticateAfterConnect() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    
    // Если reauth уже идёт — не запускаем второй
    if (_reauthInProgress) return;
    _reauthInProgress = true;
    
    try {
      // Отправляем auth напрямую, без _performAuth
      final completer = Completer<Map<String, dynamic>>();
      _pendingAuth = completer;
      _authInProgress = true;
      
      _send({'type': 'auth', 'token': token});
      
      final message = await completer.future.timeout(const Duration(seconds: 10));
      if (message['type'] == 'auth_ok') {
        debugPrint('WebSocketBackend: re-auth успешен');
      } else {
        debugPrint('WebSocketBackend: re-auth failed: ${message['message']}');
        clearToken();
      }
    } catch (e) {
      debugPrint('WebSocketBackend: re-auth error: $e');
    } finally {
      _pendingAuth = null;
      _authInProgress = false;
      _reauthInProgress = false;
    }
  }

  void _onDisconnected() {
    _connected = false;
    _pingTimer?.cancel();
    // Авто-переподключение через 3 секунды
    _reconnectTimer?.cancel();
    if (!_disposed && _lastUrl != null) {
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        debugPrint('WebSocketBackend: попытка переподключения...');
        connect(_lastUrl!).catchError((_) {});
      });
    }
  }

  /// A6: disconnect() — НЕ ставит _disposed = true
  @override
  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _streamSub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    _outbox.clear();
    // НЕ ставим _disposed = true — reconnect должен работать
  }

  /// Внутренний метод для выполнения auth-запроса с защитой от гонок
  Future<AuthResult> _performAuth({
    required String type,
    required Map<String, dynamic> payload,
    bool saveTokenOnSuccess = false,
  }) async {
    // Если уже идёт авторизация — ждём её завершения
    if (_authInProgress) {
      await _pendingAuth?.future;
    }

    _authInProgress = true;
    final completer = Completer<Map<String, dynamic>>();
    _pendingAuth = completer;

    _send(payload);

    try {
      final message = await completer.future.timeout(const Duration(seconds: 10));
      if (message['type'] == 'auth_ok') {
        final token = message['token'] as String?;
        final userId = message['userId'] as String?;
        if (saveTokenOnSuccess && token != null) {
          _token = token;
          _saveToken(token);
        }
        if (userId != null) {
          _userId = userId;
        }
        return AuthResult(
          success: true,
          userId: userId,
          login: message['login'] as String?,
          displayName: message['displayName'] as String?,
          token: token,
        );
      } else {
        return AuthResult(success: false, error: message['message'] as String? ?? 'Ошибка $type');
      }
    } on TimeoutException {
      return AuthResult(success: false, error: 'Таймаут подключения');
    } finally {
      _pendingAuth = null;
      _authInProgress = false;
    }
  }

  @override
  Future<AuthResult> register(String login, String password, {String displayName = ''}) async {
    await ensureConnected();
    return _performAuth(
      type: 'register',
      payload: {
        'type': 'register',
        'login': login,
        'password': password,
        'displayName': displayName,
      },
      saveTokenOnSuccess: true,
    );
  }

  @override
  Future<AuthResult> login(String login, String password) async {
    await ensureConnected();
    return _performAuth(
      type: 'login',
      payload: {'type': 'login', 'login': login, 'password': password},
      saveTokenOnSuccess: true,
    );
  }

  @override
  Future<AuthResult> authWithToken(String token) async {
    await ensureConnected();
    return _performAuth(
      type: 'auth',
      payload: {'type': 'auth', 'token': token},
      saveTokenOnSuccess: false,
    );
  }

  /// A5: createRoom — async + проверки
  @override
  Future<void> createRoom(String playerName,
      {bool isPrivate = false,
      String gameType = '501',
      Map<String, dynamic>? gameParams}) async {
    await ensureConnected();
    // Ждём завершения reauth (если он ещё идёт)
    await waitForAuth();
    if (_token == null) {
      throw StateError('Не авторизован');
    }
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

  /// A6: dispose() — полная зачистка
  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _streamSub?.cancel();
    _eventController.close();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
    _outbox.clear();
  }

  // ===================================================================
  // ВНУТРЕННЕЕ
  // ===================================================================

  /// A1: _send с очередью
  void _send(Map<String, dynamic> data) {
    if (!_connected || _channel == null) {
      _outbox.add(data);
      debugPrint('WebSocketBackend: ⛔ в очередь (offline): ${data['type']}');
      return;
    }
    try {
      _channel!.sink.add(jsonEncode(data));
      debugPrint('WebSocketBackend: ✅ отправлено: $data');
    } catch (e) {
      debugPrint('WebSocketBackend: ❌ ошибка отправки: $e');
      _outbox.add(data);
      _onDisconnected();
    }
  }

  /// A1: отправить накопившиеся сообщения
  void _flushOutbox() {
    if (!_connected || _outbox.isEmpty) return;
    final pending = List<Map<String, dynamic>>.from(_outbox);
    _outbox.clear();
    for (final msg in pending) {
      _send(msg);
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    debugPrint('WebSocketBackend: получено: $message');
    final type = message['type'] as String?;

    // === A4: перехват auth-ответов для _pendingAuth ===
    if (_pendingAuth != null && !_pendingAuth!.isCompleted) {
      if (type == 'auth_ok' || type == 'error') {
        _pendingAuth!.complete(message);
        // НЕ делаем return — ивент должен дойти до _handleMessageSafe,
        // чтобы страницы получили AuthOkEvent
      }
    }

    try {
      _handleMessageSafe(message, type);
    } catch (e, stack) {
      debugPrint('WebSocketBackend: ошибка в _handleMessage: $e\n$stack');
      _eventController.add(ErrorEvent(
        'Ошибка обработки ответа сервера: $e',
      ));
    }
  }

  void _handleMessageSafe(Map<String, dynamic> message, String? type) {
    switch (type) {
      case 'auth_ok':
        _eventController.add(AuthOkEvent(
          userId: message['userId'] as String,
          login: message['login'] as String,
          displayName: message['displayName'] as String?,
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

      case 'bust':
        _eventController.add(ErrorEvent(message['message'] as String? ?? 'Перебор!'));
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
