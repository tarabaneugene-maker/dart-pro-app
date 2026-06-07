/// Координаты целей на мишени для дартс
/// Единый источник истины для всех ботов и симуляторов
///
/// Геометрия доски (стандарт BDO/PDC):
/// - Bull (double bull): радиус 6.35 мм
/// - Single bull: радиус 15.9 мм
/// - Triple ring: внутренний 99 мм, внешний 107 мм → центр 103 мм
/// - Double ring: внутренний 162 мм, внешний 170 мм → центр 166 мм
/// - Single (центр сектора): ~135 мм
///
/// Сектора по часовой стрелке, начиная с 20 наверху (12 часов):
///   20, 1, 18, 4, 13, 6, 10, 15, 2, 17, 3, 19, 7, 16, 8, 11, 14, 9, 12, 5
class TargetCoordinates {
  TargetCoordinates._();

  /// Карта координат всех целей на мишени
  static const Map<String, Point> all = {
    // ===== Triple (утроения) — радиус 103 мм =====
    'T20': Point(0, -103),
    'T1': Point(32, -98),
    'T18': Point(60, -84),
    'T4': Point(84, -60),
    'T13': Point(98, -32),
    'T6': Point(107, 0),
    'T10': Point(98, 32),
    'T15': Point(84, 60),
    'T2': Point(60, 84),
    'T17': Point(32, 98),
    'T3': Point(0, 103),
    'T19': Point(-32, 98),
    'T7': Point(-60, 84),
    'T16': Point(-84, 60),
    'T8': Point(-98, 32),
    'T11': Point(-107, 0),
    'T14': Point(-98, -32),
    'T9': Point(-84, -60),
    'T12': Point(-60, -84),
    'T5': Point(-32, -98),

    // ===== Double (удвоения) — радиус 166 мм =====
    'D20': Point(0, -166),
    'D1': Point(51, -158),
    'D18': Point(97, -135),
    'D4': Point(135, -97),
    'D13': Point(158, -51),
    'D6': Point(166, 0),
    'D10': Point(158, 51),
    'D15': Point(135, 97),
    'D2': Point(97, 135),
    'D17': Point(51, 158),
    'D3': Point(0, 166),
    'D19': Point(-51, 158),
    'D7': Point(-97, 135),
    'D16': Point(-135, 97),
    'D8': Point(-158, 51),
    'D11': Point(-166, 0),
    'D14': Point(-158, -51),
    'D9': Point(-135, -97),
    'D12': Point(-97, -135),
    'D5': Point(-51, -158),

    // ===== Single (простые сектора) — радиус 135 мм =====
    'S20': Point(0, -135),
    'S1': Point(42, -128),
    'S18': Point(79, -110),
    'S4': Point(110, -79),
    'S13': Point(128, -42),
    'S6': Point(135, 0),
    'S10': Point(128, 42),
    'S15': Point(110, 79),
    'S2': Point(79, 110),
    'S17': Point(42, 128),
    'S3': Point(0, 135),
    'S19': Point(-42, 128),
    'S7': Point(-79, 110),
    'S16': Point(-110, 79),
    'S8': Point(-128, 42),
    'S11': Point(-135, 0),
    'S14': Point(-128, -42),
    'S9': Point(-110, -79),
    'S12': Point(-79, -110),
    'S5': Point(-42, -128),

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
