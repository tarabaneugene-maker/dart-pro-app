import 'game_enums.dart';

/// Конфигурация игрока
class PlayerConfig {
  final String name;
  final InputMode inputMode;
  final bool isBot;
  final BotLevel? botLevel;

  PlayerConfig({
    required this.name,
    required this.inputMode,
    required this.isBot,
    this.botLevel,
  });

  /// Создать копию с обновленными полями
  PlayerConfig copyWith({
    String? name,
    InputMode? inputMode,
    bool? isBot,
    BotLevel? botLevel,
  }) =>
      PlayerConfig(
        name: name ?? this.name,
        inputMode: inputMode ?? this.inputMode,
        isBot: isBot ?? this.isBot,
        botLevel: botLevel ?? this.botLevel,
      );

  /// Проверить, является ли игрок ботом
  bool get isHuman => !isBot;

  /// Получить текстовое описание режима ввода
  String get inputModeDescription {
    switch (inputMode) {
      case InputMode.threeDarts:
        return 'Сумма подхода';
      case InputMode.oneDart:
        return 'Каждый бросок';
    }
  }

  /// Получить уровень бота в текстовом виде
  String? get botLevelDescription => botLevel?.description;

  @override
  String toString() {
    return 'PlayerConfig{name: $name, inputMode: $inputMode, isBot: $isBot, botLevel: $botLevel}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerConfig &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          inputMode == other.inputMode &&
          isBot == other.isBot &&
          botLevel == other.botLevel;

  @override
  int get hashCode =>
      name.hashCode ^ inputMode.hashCode ^ isBot.hashCode ^ botLevel.hashCode;
}