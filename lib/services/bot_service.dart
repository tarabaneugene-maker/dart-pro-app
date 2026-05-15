import '../models/game_enums.dart';
import '../bots/dart_bot_501.dart';

/// Сервис для управления ботами
class BotService {
  /// Создать бота для игры 501
  static DartBot501 createBot501(BotLevel level) {
    return DartBot501(level);
  }

  /// Получить список доступных уровней ботов
  static List<BotLevel> getAvailableBotLevels() {
    return BotLevel.values;
  }

  /// Получить описание уровня бота
  static String getBotLevelDescription(BotLevel level) {
    return level.description;
  }

  /// Получить средний счет для уровня бота
  static double getBotAverageScore(BotLevel level) {
    return level.averageScore;
  }

  /// Проверить, является ли имя бота стандартным
  static bool isStandardBotName(String name) {
    final standardNames = [
      'Бот-новичок',
      'Бот-любитель',
      'Бот-профи',
      'Бот-эксперт',
      'ИИ-игрок',
    ];
    return standardNames.any((standard) => name.contains(standard));
  }

  /// Сгенерировать имя для бота на основе уровня
  static String generateBotName(BotLevel level) {
    switch (level) {
      case BotLevel.beginner35_45:
        return 'Бот-новичок';
      case BotLevel.amateur45_55:
        return 'Бот-любитель';
      case BotLevel.amateur55_65:
        return 'Бот-любитель+';
      case BotLevel.pro65_75:
        return 'Бот-профи';
      case BotLevel.pro75_85:
        return 'Бот-профи+';
      case BotLevel.expert85_95:
        return 'Бот-эксперт';
    }
  }

  /// Получить рекомендуемый уровень бота для тренировки
  static BotLevel getRecommendedTrainingLevel(double playerAverage) {
    if (playerAverage < 45) return BotLevel.beginner35_45;
    if (playerAverage < 55) return BotLevel.amateur45_55;
    if (playerAverage < 65) return BotLevel.amateur55_65;
    if (playerAverage < 75) return BotLevel.pro65_75;
    if (playerAverage < 85) return BotLevel.pro75_85;
    return BotLevel.expert85_95;
  }
}