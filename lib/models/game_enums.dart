// Модели перечислений для игровых режимов

/// Уровни сложности ботов
enum BotLevel {
  beginner35_45,
  amateur45_55,
  amateur55_65,
  pro65_75,
  pro75_85,
  expert85_95,
}

/// Режимы ввода очков
enum InputMode { threeDarts, oneDart }

/// Типы игр
enum GameType { d501, d301 }

/// Типы начала игры
enum StartType { straightIn, doubleIn }

/// Типы финиша
enum FinishType { doubleOut, straightOut }

/// Вспомогательные методы для BotLevel
extension BotLevelExtension on BotLevel {
  /// Получить текстовое описание уровня
  String get description {
    switch (this) {
      case BotLevel.beginner35_45:
        return 'Начинающий (35-45)';
      case BotLevel.amateur45_55:
        return 'Любитель (45-55)';
      case BotLevel.amateur55_65:
        return 'Любитель+ (55-65)';
      case BotLevel.pro65_75:
        return 'Про (65-75)';
      case BotLevel.pro75_85:
        return 'Про+ (75-85)';
      case BotLevel.expert85_95:
        return 'Эксперт (85-95)';
    }
  }

  /// Получить числовое значение среднего счета
  double get averageScore {
    switch (this) {
      case BotLevel.beginner35_45:
        return 40.0;
      case BotLevel.amateur45_55:
        return 50.0;
      case BotLevel.amateur55_65:
        return 60.0;
      case BotLevel.pro65_75:
        return 70.0;
      case BotLevel.pro75_85:
        return 80.0;
      case BotLevel.expert85_95:
        return 90.0;
    }
  }
}

/// Вспомогательные методы для GameType
extension GameTypeExtension on GameType {
  /// Получить начальный счет для типа игры
  int get startingScore {
    switch (this) {
      case GameType.d501:
        return 501;
      case GameType.d301:
        return 301;
    }
  }

  /// Получить название игры
  String get name {
    switch (this) {
      case GameType.d501:
        return '501';
      case GameType.d301:
        return '301';
    }
  }
}

/// Вспомогательные методы для StartType
extension StartTypeExtension on StartType {
  /// Получить текстовое описание
  String get description {
    switch (this) {
      case StartType.straightIn:
        return 'Straight In';
      case StartType.doubleIn:
        return 'Double In';
    }
  }
}

/// Вспомогательные методы для FinishType
extension FinishTypeExtension on FinishType {
  /// Получить текстовое описание
  String get description {
    switch (this) {
      case FinishType.doubleOut:
        return 'Double Out';
      case FinishType.straightOut:
        return 'Straight Out';
    }
  }
}