import 'dart:math';
import 'target_coordinates.dart';

/// Результат одного броска дротика
class ThrowResult {
  final int score;
  final int segment;    // 1-20, 25 для Bull
  final int multiplier; // 1 (single), 2 (double), 3 (triple)

  const ThrowResult({
    required this.score,
    required this.segment,
    required this.multiplier,
  });

  /// Попадание в удвоение (D1-D20 или Bull)
  bool get isDouble => multiplier == 2;

  /// Попадание в утроение (T1-T20)
  bool get isTriple => multiplier == 3;

  /// Попадание в Bull (single bull = 25, double bull = 50)
  bool get isBull => segment == 25;

  /// Попадание в Single (S1-S20 или single bull)
  bool get isSingle => multiplier == 1 && segment != 25;

  @override
  String toString() =>
      'ThrowResult(score: $score, segment: $segment, multiplier: $multiplier)';
}

/// Симулятор броска дротика с физической моделью
class DartThrowSimulator {
  static final Random _random = Random();

  /// Генерация случайного числа по нормальному распределению
  static double _gaussian(double mean, double stdDev) {
    double u1 = _random.nextDouble();
    double u2 = _random.nextDouble();
    double z = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
    return mean + stdDev * z;
  }

  /// Преобразование координат в результат броска на мишени
  static ThrowResult _getScoreFromCoordinates(double x, double y) {
    double distance = sqrt(x * x + y * y);

    // Если попадание вне мишени (за double ring)
    if (distance > 170) {
      return const ThrowResult(score: 0, segment: 0, multiplier: 0);
    }

    // Определение сектора
    double angle = atan2(y, x);
    double sectorAngle = angle + pi / 20;
    if (sectorAngle < 0) sectorAngle += 2 * pi;
    int sectorIndex = (sectorAngle / (pi / 10)).floor();

    // Порядок секторов по часовой от 6 (начиная с 3 часов, угол ~0)
    // Сектор 20 (12 часов) = atan2(-103, 0) = -π/2 → sectorIndex = 15
    const List<int> sectorMap = [
      6, 10, 15, 2, 17, 3, 19, 7, 16, 8,
      11, 14, 9, 12, 5, 20, 1, 18, 4, 13,
    ];
    int segment = sectorMap[sectorIndex % 20];

    // Определение множителя
    int multiplier;
    if (distance <= 6.35) {
      // Double Bull (Bullseye)
      multiplier = 2;
      segment = 25;
    } else if (distance <= 15.9) {
      // Single Bull
      multiplier = 1;
      segment = 25;
    } else if (distance >= 99 && distance <= 107) {
      // Triple ring
      multiplier = 3;
    } else if (distance >= 162 && distance <= 170) {
      // Double ring
      multiplier = 2;
    } else {
      // Single area
      multiplier = 1;
    }

    return ThrowResult(
      score: segment * multiplier,
      segment: segment,
      multiplier: multiplier,
    );
  }

  /// Симуляция одного броска по заданным координатам цели
  static ThrowResult simulateThrow(
      double targetX, double targetY, double stdDevMm) {
    double hitX = _gaussian(targetX, stdDevMm);
    double hitY = _gaussian(targetY, stdDevMm);
    return _getScoreFromCoordinates(hitX, hitY);
  }

  /// Симуляция серии бросков
  static List<ThrowResult> simulateThrows({
    required double targetX,
    required double targetY,
    required double stdDevMm,
    required int count,
  }) {
    return List.generate(
        count, (_) => simulateThrow(targetX, targetY, stdDevMm));
  }

  /// Получить координаты цели по названию сегмента
  static Point? getTargetCoordinates(String segment) {
    return TargetCoordinates.get(segment);
  }
}
