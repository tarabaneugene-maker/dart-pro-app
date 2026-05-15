import '../models/game_enums.dart';

/// Конфигурация сигм (стандартных отклонений) для ботов
/// Определяет точность бросков в разных ситуациях
class BotSigmaConfig {
  final double scoring;   // Сигма для обычных бросков (набор очков)
  final double setup;     // Сигма для setup-бросков (подготовка к финишу)
  final double checkout;  // Сигма для checkout-бросков (финиш)

  const BotSigmaConfig({
    required this.scoring,
    required this.setup,
    required this.checkout,
  });

  /// Получить конфигурацию для указанного уровня бота
  static BotSigmaConfig forLevel(BotLevel level) {
    switch (level) {
      case BotLevel.beginner35_45:
        return BotSigmaConfig(scoring: 22.0, setup: 26.0, checkout: 30.0);
      case BotLevel.amateur45_55:
        return BotSigmaConfig(scoring: 18.0, setup: 22.0, checkout: 27.0);
      case BotLevel.amateur55_65:
        return BotSigmaConfig(scoring: 14.0, setup: 18.0, checkout: 24.0);
      case BotLevel.pro65_75:
        return BotSigmaConfig(scoring: 11.0, setup: 14.0, checkout: 18.0);
      case BotLevel.pro75_85:
        return BotSigmaConfig(scoring: 9.0, setup: 11.0, checkout: 14.0);
      case BotLevel.expert85_95:
        return BotSigmaConfig(scoring: 7.0, setup: 9.0, checkout: 11.0);
    }
  }

  /// Получить сигму для указанного типа броска
  double getSigmaForThrowType(String throwType) {
    switch (throwType) {
      case 'scoring':
        return scoring;
      case 'setup':
        return setup;
      case 'checkout':
        return checkout;
      default:
        return scoring;
    }
  }

  @override
  String toString() {
    return 'BotSigmaConfig{scoring: ${scoring.toStringAsFixed(1)}, '
        'setup: ${setup.toStringAsFixed(1)}, '
        'checkout: ${checkout.toStringAsFixed(1)}}';
  }
}