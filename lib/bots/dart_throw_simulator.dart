import 'dart:math';
import 'target_coordinates.dart';

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

  /// Преобразование координат в очки на мишени
  static int _getScoreFromCoordinates(double x, double y) {
    double distance = sqrt(x * x + y * y);

    // Если попадание вне мишени
    if (distance > 170) return 0;

    // Определение сектора
    double angle = atan2(y, x);
    double sectorAngle = angle + pi / 20;
    if (sectorAngle < 0) sectorAngle += 2 * pi;
    int sectorIndex = (sectorAngle / (pi / 10)).floor();

    const List<int> sectorMap = [
      6, 13, 4, 18, 1, 20, 5, 12, 9, 14,
      11, 8, 16, 7, 19, 3, 17, 2, 15, 10,
    ];
    int segment = sectorMap[sectorIndex % 20];

    // Определение множителя
    int multiplier;
    if (distance <= 6.35) {
      // Bullseye (double bull)
      multiplier = 2;
      segment = 25;
    } else if (distance <= 15.9) {
      // Bull (single bull)
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

    return segment * multiplier;
  }

  /// Симуляция броска по заданным координатам цели
  static int simulateThrow(double targetX, double targetY, double stdDevMm) {
    double hitX = _gaussian(targetX, stdDevMm);
    double hitY = _gaussian(targetY, stdDevMm);
    return _getScoreFromCoordinates(hitX, hitY);
  }

  /// Симуляция серии бросков
  static List<int> simulateThrows({
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
