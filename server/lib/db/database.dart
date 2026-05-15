import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3/common.dart';
import '../models/user.dart';
import '../models/match_result.dart';

/// База данных сервера (SQLite)
class Database {
  late final CommonDatabase _db;
  bool _initialized = false;

  void init(String path) {
    _db = sqlite3.open(path);
    _migrate();
    _initialized = true;
  }

  void _migrate() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        login TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS user_stats (
        user_id TEXT PRIMARY KEY REFERENCES users(id),
        matches_played INTEGER DEFAULT 0,
        matches_won INTEGER DEFAULT 0,
        legs_played INTEGER DEFAULT 0,
        legs_won INTEGER DEFAULT 0,
        total_score INTEGER DEFAULT 0,
        total_darts INTEGER DEFAULT 0,
        best_leg INTEGER,
        highest_checkout INTEGER,
        current_elo INTEGER DEFAULT 1000
      )
    ''');

    _db.execute('''
      CREATE TABLE IF NOT EXISTS match_history (
        id TEXT PRIMARY KEY,
        player1_id TEXT REFERENCES users(id),
        player2_id TEXT REFERENCES users(id),
        player1_score INTEGER,
        player2_score INTEGER,
        player1_avg REAL,
        player2_avg REAL,
        winner_id TEXT REFERENCES users(id),
        finished_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  // ===================================================================
  // USERS
  // ===================================================================

  User? findUserByLogin(String login) {
    final result = _db.select(
      'SELECT id, login, password_hash, created_at FROM users WHERE login = ?',
      [login],
    );
    if (result.isEmpty) return null;
    final row = result.first;
    return User(
      id: row['id'] as String,
      login: row['login'] as String,
      passwordHash: row['password_hash'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  User? findUserById(String id) {
    final result = _db.select(
      'SELECT id, login, password_hash, created_at FROM users WHERE id = ?',
      [id],
    );
    if (result.isEmpty) return null;
    final row = result.first;
    return User(
      id: row['id'] as String,
      login: row['login'] as String,
      passwordHash: row['password_hash'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  void createUser(User user) {
    _db.execute(
      'INSERT INTO users (id, login, password_hash, created_at) VALUES (?, ?, ?, ?)',
      [user.id, user.login, user.passwordHash, user.createdAt.toIso8601String()],
    );
    // Создаём пустую статистику
    _db.execute(
      'INSERT INTO user_stats (user_id) VALUES (?)',
      [user.id],
    );
  }

  // ===================================================================
  // STATS
  // ===================================================================

  Map<String, dynamic>? getStats(String userId) {
    final result = _db.select(
      'SELECT * FROM user_stats WHERE user_id = ?',
      [userId],
    );
    if (result.isEmpty) return null;
    final row = result.first;
    return {
      'user_id': row['user_id'],
      'matches_played': row['matches_played'],
      'matches_won': row['matches_won'],
      'legs_played': row['legs_played'],
      'legs_won': row['legs_won'],
      'total_score': row['total_score'],
      'total_darts': row['total_darts'],
      'best_leg': row['best_leg'],
      'highest_checkout': row['highest_checkout'],
      'current_elo': row['current_elo'],
    };
  }

  void updateStatsAfterMatch(String userId, int score, int darts, bool won) {
    _db.execute(
      '''UPDATE user_stats SET
        matches_played = matches_played + 1,
        matches_won = matches_won + ?,
        legs_played = legs_played + 1,
        total_score = total_score + ?,
        total_darts = total_darts + ?
      WHERE user_id = ?''',
      [won ? 1 : 0, score, darts, userId],
    );
  }

  // ===================================================================
  // MATCH HISTORY
  // ===================================================================

  void saveMatch(MatchResult match) {
    _db.execute(
      '''INSERT INTO match_history
        (id, player1_id, player2_id, player1_score, player2_score,
         player1_avg, player2_avg, winner_id, finished_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        match.id,
        match.player1Id,
        match.player2Id,
        match.player1Score,
        match.player2Score,
        match.player1Avg,
        match.player2Avg,
        match.winnerId,
        match.finishedAt.toIso8601String(),
      ],
    );
  }

  List<Map<String, dynamic>> getMatchHistory(String userId, {int limit = 20}) {
    final result = _db.select(
      '''SELECT * FROM match_history
      WHERE player1_id = ? OR player2_id = ?
      ORDER BY finished_at DESC
      LIMIT ?''',
      [userId, userId, limit],
    );
    return result.map((r) => {
      'id': r['id'],
      'player1_id': r['player1_id'],
      'player2_id': r['player2_id'],
      'player1_score': r['player1_score'],
      'player2_score': r['player2_score'],
      'player1_avg': r['player1_avg'],
      'player2_avg': r['player2_avg'],
      'winner_id': r['winner_id'],
      'finished_at': r['finished_at'],
    }).toList();
  }

  void dispose() {
    if (_initialized) {
      _db.dispose();
    }
  }
}
