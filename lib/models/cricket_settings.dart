import 'game_enums.dart';
import 'player_config.dart';

/// Настройки игры Cricket
class CricketSettings {
  final int sets;
  final int legs;
  final List<PlayerConfig> players;
  final int startingPlayerIndex;

  CricketSettings({
    required this.sets,
    required this.legs,
    required this.players,
    required this.startingPlayerIndex,
  });

  /// Настройки по умолчанию для Cricket
  static CricketSettings defaultSettings() => CricketSettings(
        sets: 1,
        legs: 3,
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
  CricketSettings copyWith({
    int? sets,
    int? legs,
    List<PlayerConfig>? players,
    int? startingPlayerIndex,
  }) =>
      CricketSettings(
        sets: sets ?? this.sets,
        legs: legs ?? this.legs,
        players: players ?? this.players,
        startingPlayerIndex: startingPlayerIndex ?? this.startingPlayerIndex,
      );

  @override
  String toString() {
    return 'CricketSettings{sets: $sets, legs: $legs, '
        'players: $players, startingPlayerIndex: $startingPlayerIndex}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CricketSettings &&
          runtimeType == other.runtimeType &&
          sets == other.sets &&
          legs == other.legs &&
          players == other.players &&
          startingPlayerIndex == other.startingPlayerIndex;

  @override
  int get hashCode =>
      sets.hashCode ^ legs.hashCode ^ players.hashCode ^ startingPlayerIndex.hashCode;
}