import 'game_enums.dart';
import 'player_config.dart';

/// Настройки игры 501/301
class GameSettings {
  final GameType gameType;
  final int sets;
  final int legs;
  final StartType startType;
  final FinishType finishType;
  final List<PlayerConfig> players;
  final int startingPlayerIndex;

  GameSettings({
    required this.gameType,
    required this.sets,
    required this.legs,
    required this.startType,
    required this.finishType,
    required this.players,
    required this.startingPlayerIndex,
  });

  /// Настройки по умолчанию для игры 501
  static GameSettings defaultSettings() => GameSettings(
        gameType: GameType.d501,
        sets: 1,
        legs: 3,
        startType: StartType.straightIn,
        finishType: FinishType.doubleOut,
        players: [
          PlayerConfig(
            name: 'Игрок 1',
            inputMode: InputMode.threeDarts,
            isBot: false,
          ),
          PlayerConfig(
            name: 'Игрок 2',
            inputMode: InputMode.threeDarts,
            isBot: false,
          ),
        ],
        startingPlayerIndex: 0,
      );

  /// Получить начальный счет на основе типа игры
  int get startingScore => gameType.startingScore;

  /// Получить максимальное количество игроков
  int get maxPlayers => 4;

  /// Получить минимальное количество игроков
  int get minPlayers => 2;

  /// Проверить валидность настроек
  bool get isValid {
    if (players.length < minPlayers || players.length > maxPlayers) {
      return false;
    }
    if (startingPlayerIndex < 0 || startingPlayerIndex >= players.length) {
      return false;
    }
    if (sets < 1 || legs < 1) {
      return false;
    }
    return true;
  }

  /// Создать копию с обновленными полями
  GameSettings copyWith({
    GameType? gameType,
    int? sets,
    int? legs,
    StartType? startType,
    FinishType? finishType,
    List<PlayerConfig>? players,
    int? startingPlayerIndex,
  }) =>
      GameSettings(
        gameType: gameType ?? this.gameType,
        sets: sets ?? this.sets,
        legs: legs ?? this.legs,
        startType: startType ?? this.startType,
        finishType: finishType ?? this.finishType,
        players: players ?? this.players,
        startingPlayerIndex: startingPlayerIndex ?? this.startingPlayerIndex,
      );

  @override
  String toString() {
    return 'GameSettings{gameType: $gameType, sets: $sets, legs: $legs, '
        'startType: $startType, finishType: $finishType, '
        'players: $players, startingPlayerIndex: $startingPlayerIndex}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameSettings &&
          runtimeType == other.runtimeType &&
          gameType == other.gameType &&
          sets == other.sets &&
          legs == other.legs &&
          startType == other.startType &&
          finishType == other.finishType &&
          players == other.players &&
          startingPlayerIndex == other.startingPlayerIndex;

  @override
  int get hashCode =>
      gameType.hashCode ^
      sets.hashCode ^
      legs.hashCode ^
      startType.hashCode ^
      finishType.hashCode ^
      players.hashCode ^
      startingPlayerIndex.hashCode;
}