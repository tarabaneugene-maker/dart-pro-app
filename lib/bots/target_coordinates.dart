/// Координаты целей на мишени для дартс
/// Единый источник истины для всех ботов и симуляторов
class TargetCoordinates {
  TargetCoordinates._();

  /// Карта координат всех целей на мишени
  /// Ключ: название цели (например 'T20', 'D20', 'S20', 'Bull')
  /// Значение: координаты (x, y) в мм относительно центра мишени
  static const Map<String, Point> all = {
    // Triple (утроения)
    'T20': Point(0, -103),
    'T19': Point(-31, -98),
    'T18': Point(-60, -84),
    'T17': Point(-88, -60),
    'T16': Point(-103, -31),
    'T15': Point(-107, 0),
    'T14': Point(-98, 31),
    'T13': Point(-84, 60),
    'T12': Point(-60, 88),
    'T11': Point(-31, 103),
    'T10': Point(0, 107),
    'T9': Point(31, 103),
    'T8': Point(60, 88),
    'T7': Point(84, 60),
    'T6': Point(98, 31),
    'T5': Point(107, 0),
    'T4': Point(98, -31),
    'T3': Point(84, -60),
    'T2': Point(60, -88),
    'T1': Point(31, -103),
    // Double (удвоения)
    'D20': Point(0, -166),
    'D19': Point(-31, -166),
    'D18': Point(-60, -166),
    'D17': Point(-88, -166),
    'D16': Point(-166, 0),
    'D15': Point(-166, -31),
    'D14': Point(-166, -60),
    'D13': Point(-166, -88),
    'D12': Point(-84, -143),
    'D11': Point(-84, 143),
    'D10': Point(0, 166),
    'D9': Point(31, 166),
    'D8': Point(166, 0),
    'D7': Point(166, 31),
    'D6': Point(166, 60),
    'D5': Point(0, 83),
    'D4': Point(98, 143),
    'D3': Point(84, 143),
    'D2': Point(60, 166),
    'D1': Point(31, 166),
    // Single (простые сектора)
    'S20': Point(0, -135),
    'S19': Point(-31, -135),
    'S18': Point(-60, -135),
    'S17': Point(-88, -135),
    'S16': Point(-135, 0),
    'S15': Point(-135, -31),
    'S14': Point(-135, -60),
    'S13': Point(-135, -88),
    'S12': Point(-60, 135),
    'S11': Point(-31, 135),
    'S10': Point(0, 135),
    'S9': Point(31, 135),
    'S8': Point(60, 135),
    'S7': Point(84, 135),
    'S6': Point(98, 135),
    'S5': Point(0, 70),
    'S4': Point(98, 135),
    'S3': Point(84, 135),
    'S2': Point(60, 135),
    'S1': Point(0, -20),
    // Bull
    'Bull': Point(0, 0),
  };

  /// Получить координаты цели по названию
  static Point? get(String key) => all[key];
}

/// Простая структура для хранения координат
class Point {
  final double x, y;
  const Point(this.x, this.y);

  @override
  String toString() => 'Point(${x.toStringAsFixed(1)}, ${y.toStringAsFixed(1)})';
}
