import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import '../db/database.dart';
import '../models/user.dart';

/// Обработчик аутентификации
class AuthHandler {
  final Database _db;
  final Map<String, String> _activeTokens = {}; // token -> userId
  final Map<String, DateTime> _tokenExpiry = {}; // token -> expiry

  static const _tokenDuration = Duration(hours: 24);

  AuthHandler(this._db);

  /// Регистрация нового пользователя
  /// Возвращает Map с результатом: {'success': true, 'token': '...', 'user': {...}}
  /// или {'success': false, 'error': '...'}
  Map<String, dynamic> register(String login, String password) {
    if (login.length < 3) {
      return {'success': false, 'error': 'Логин должен быть не менее 3 символов'};
    }
    if (password.length < 4) {
      return {'success': false, 'error': 'Пароль должен быть не менее 4 символов'};
    }

    // Проверка на существующего пользователя
    final existing = _db.findUserByLogin(login);
    if (existing != null) {
      return {'success': false, 'error': 'Пользователь с таким логином уже существует'};
    }

    final id = _generateId();
    final passwordHash = _hashPassword(password);

    final user = User(
      id: id,
      login: login,
      passwordHash: passwordHash,
      createdAt: DateTime.now(),
    );

    _db.createUser(user);
    final token = _generateToken();

    _activeTokens[token] = id;
    _tokenExpiry[token] = DateTime.now().add(_tokenDuration);

    return {
      'success': true,
      'token': token,
      'user': user.toJson(),
    };
  }

  /// Вход пользователя
  Map<String, dynamic> login(String login, String password) {
    final user = _db.findUserByLogin(login);
    if (user == null) {
      return {'success': false, 'error': 'Неверный логин или пароль'};
    }

    final passwordHash = _hashPassword(password);
    if (user.passwordHash != passwordHash) {
      return {'success': false, 'error': 'Неверный логин или пароль'};
    }

    final token = _generateToken();
    _activeTokens[token] = user.id;
    _tokenExpiry[token] = DateTime.now().add(_tokenDuration);

    return {
      'success': true,
      'token': token,
      'user': user.toJson(),
    };
  }

  /// Проверка токена. Возвращает userId или null
  String? validateToken(String token) {
    final expiry = _tokenExpiry[token];
    if (expiry == null) return null;
    if (DateTime.now().isAfter(expiry)) {
      _activeTokens.remove(token);
      _tokenExpiry.remove(token);
      return null;
    }
    return _activeTokens[token];
  }

  /// Выход (инвалидация токена)
  void logout(String token) {
    _activeTokens.remove(token);
    _tokenExpiry.remove(token);
  }

  String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }
}
