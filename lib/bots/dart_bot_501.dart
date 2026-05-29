import 'dart:math';
import '../models/game_enums.dart';
import 'dart_throw_simulator.dart';
import 'bot_sigma_config.dart';
import 'bot_context_501.dart';
import 'target_coordinates.dart';

/// Бот для игры 501 с физической моделью броска
class DartBot501 {
  final BotLevel level;
  final BotSigmaConfig _sigma;
  final Random _random = Random();

  /// Таблица финишей: остаток -> цель для checkout-броска
  /// Цель — это первый бросок в оптимальной 3-дротиковой комбинации
  static const Map<int, String> _checkoutTable = {
    // 3-dart finishes (T + T + D)
    170: 'T20',  // T20 T20 Bull
    167: 'T20',  // T20 T19 Bull
    164: 'T20',  // T20 T18 Bull
    161: 'T20',  // T20 T17 Bull
    160: 'T20',  // T20 T20 D20
    158: 'T20',  // T20 T20 D19
    157: 'T20',  // T20 T19 D20
    156: 'T20',  // T20 T20 D18
    155: 'T20',  // T20 T19 D19
    154: 'T20',  // T20 T18 D20
    153: 'T20',  // T20 T19 D18
    152: 'T20',  // T20 T20 D16
    151: 'T20',  // T20 T17 D20
    150: 'T20',  // T20 T18 D18
    149: 'T20',  // T20 T19 D16
    148: 'T20',  // T20 T16 D20
    147: 'T20',  // T20 T17 D18
    146: 'T20',  // T20 T18 D16
    145: 'T20',  // T20 T15 D20
    144: 'T20',  // T20 T20 D12
    143: 'T20',  // T20 T17 D16
    142: 'T20',  // T20 T14 D20
    141: 'T20',  // T20 T15 D18
    140: 'T20',  // T20 T20 D10
    139: 'T19',  // T19 T14 D20
    138: 'T20',  // T20 T18 D12
    137: 'T20',  // T20 T15 D16
    136: 'T20',  // T20 T20 D8
    135: 'T20',  // T20 T15 D15
    134: 'T20',  // T20 T14 D16
    133: 'T20',  // T20 T19 D8
    132: 'T20',  // T20 T16 D12
    131: 'T20',  // T20 T13 D20
    130: 'T20',  // T20 T20 D5
    129: 'T19',  // T19 T16 D12
    128: 'T18',  // T18 T14 D20
    127: 'T20',  // T20 T17 D8
    126: 'T19',  // T19 T15 D12
    125: 'T20',  // T20 T15 D10
    124: 'T20',  // T20 T16 D8
    123: 'T19',  // T19 T14 D10
    122: 'T18',  // T18 T18 D13
    121: 'T20',  // T20 T11 D20
    120: 'T20',  // T20 S20 D20
    119: 'T19',  // T19 T12 D13
    118: 'T20',  // T20 S18 D20
    117: 'T20',  // T20 S17 D20
    116: 'T20',  // T20 S16 D20
    115: 'T20',  // T20 S15 D20
    114: 'T20',  // T20 S14 D20
    113: 'T20',  // T20 S13 D20
    112: 'T20',  // T20 S12 D20
    111: 'T20',  // T20 S11 D20
    110: 'T20',  // T20 S10 D20
    109: 'T20',  // T20 S9 D20
    108: 'T20',  // T20 S8 D20
    107: 'T19',  // T19 S10 D20
    106: 'T20',  // T20 S6 D20
    105: 'T20',  // T20 S5 D20
    104: 'T18',  // T18 S10 D20
    103: 'T20',  // T20 S3 D20
    102: 'T20',  // T20 S10 D16
    101: 'T20',  // T20 S9 D16
    100: 'T20',  // T20 S8 D16
    99: 'T19',   // T19 S10 D16
    98: 'T20',   // T20 S6 D16
    97: 'T19',   // T19 S8 D16
    96: 'T20',   // T20 S4 D16
    95: 'T20',   // T20 S3 D16
    94: 'T18',   // T18 S10 D15
    93: 'T19',   // T19 S6 D15
    92: 'T20',   // T20 S12 D10
    91: 'T17',   // T17 S10 D15
    90: 'T20',   // T20 S10 D10
    89: 'T19',   // T19 S12 D10
    88: 'T20',   // T20 S8 D10
    87: 'T17',   // T17 S16 D10
    86: 'T18',   // T18 S12 D10
    85: 'T15',   // T15 S10 D20
    84: 'T20',   // T20 S4 D10
    83: 'T17',   // T17 S12 D10
    82: 'T14',   // T14 S10 D20
    81: 'T19',   // T19 S4 D10
    80: 'T20',   // T20 S10 D5
    79: 'T19',   // T19 S2 D10
    78: 'T18',   // T18 S4 D10
    77: 'T15',   // T15 S12 D10
    76: 'T20',   // T20 S6 D5
    75: 'T17',   // T17 S4 D10
    74: 'T14',   // T14 S12 D10
    73: 'T19',   // T19 S6 D5
    72: 'T16',   // T16 S4 D10
    71: 'T13',   // T13 S12 D10
    70: 'T10',   // T10 S10 D20
    69: 'T15',   // T15 S4 D10
    68: 'T20',   // T20 S8 D5
    67: 'T17',   // T17 S6 D5
    66: 'T10',   // T10 S16 D10
    65: 'T15',   // T15 S10 D5
    64: 'T16',   // T16 S6 D5
    63: 'T13',   // T13 S4 D10
    62: 'T10',   // T10 S12 D10
    61: 'T15',   // T15 S6 D5
    // 2-dart finishes (S + D)
    60: 'S20',   // S20 D20
    59: 'S19',   // S19 D20
    58: 'S18',   // S18 D20
    57: 'S17',   // S17 D20
    56: 'S16',   // S16 D20
    55: 'S15',   // S15 D20
    54: 'S14',   // S14 D20
    53: 'S13',   // S13 D20
    52: 'S12',   // S12 D20
    51: 'S11',   // S11 D20
    50: 'Bull',  // Bull (double bull)
    49: 'S9',    // S9 D20
    48: 'S8',    // S8 D20
    47: 'S15',   // S15 D16
    46: 'S6',    // S6 D20
    45: 'S13',   // S13 D16
    44: 'S4',    // S4 D20
    43: 'S11',   // S11 D16
    42: 'S10',   // S10 D16
    41: 'S9',    // S9 D16
    // 1-dart finishes (D)
    40: 'D20',
    39: 'S7',    // S7 D16 (2 дротика)
    38: 'D19',
    37: 'S5',    // S5 D16 (2 дротика)
    36: 'D18',
    35: 'S3',    // S3 D16 (2 дротика)
    34: 'D17',
    33: 'S1',    // S1 D16 (2 дротика)
    32: 'D16',
    31: 'S15',   // S15 D8 (2 дротика)
    30: 'D15',
    29: 'S13',   // S13 D8 (2 дротика)
    28: 'D14',
    27: 'S11',   // S11 D8 (2 дротика)
    26: 'D13',
    25: 'S9',    // S9 D8 (2 дротика)
    24: 'D12',
    23: 'S7',    // S7 D8 (2 дротика)
    22: 'D11',
    21: 'S5',    // S5 D8 (2 дротика)
    20: 'D10',
    19: 'S3',    // S3 D8 (2 дротика)
    18: 'D9',
    17: 'S1',    // S1 D8 (2 дротика)
    16: 'D8',
    15: 'S7',    // S7 D4 (2 дротика)
    14: 'D7',
    13: 'S5',    // S5 D4 (2 дротика)
    12: 'D6',
    11: 'S3',    // S3 D4 (2 дротика)
    10: 'D5',
    9: 'S1',     // S1 D4 (2 дротика)
    8: 'D4',
    7: 'S3',     // S3 D2 (2 дротика)
    6: 'D3',
    5: 'S1',     // S1 D2 (2 дротика)
    4: 'D2',
    3: 'S1',     // S1 D1 (2 дротика)
    2: 'D1',
  };

  DartBot501(this.level) : _sigma = BotSigmaConfig.forLevel(level);

  /// Бросить 3 дротика на основе текущего состояния
  /// Возвращает список результатов бросков
  List<ThrowResult> throwDarts({
    required int remainingScore,
    required bool isDoubleIn,
    required bool isDoubleOut,
    bool isFirstDartOfLeg = false,
    int dartsThrownInLeg = 0,
    int opponentRemaining = 501,
  }) {
    final results = <ThrowResult>[];
    int currentRemaining = remainingScore;
    bool doubleInClosed = !isDoubleIn || !isFirstDartOfLeg;
    int dartsUsed = dartsThrownInLeg;

    for (int dart = 0; dart < 3; dart++) {
      if (currentRemaining <= 0) break;

      final context = BotContext501(
        remainingScore: currentRemaining,
        opponentRemaining: opponentRemaining,
        dartsThrownInLeg: dartsUsed,
        isDoubleIn: isDoubleIn,
        isDoubleOut: isDoubleOut,
        isFirstDartOfLeg: isFirstDartOfLeg && dart == 0,
      );

      ThrowResult result;
      if (!doubleInClosed) {
        result = _throwForDoubleIn(context);
        // Double In считается закрытым только при попадании в дабл
        if (result.isDouble) doubleInClosed = true;
      } else if (isDoubleOut && currentRemaining <= 170) {
        // Сначала проверяем, можно ли закрыть за 1 дротик
        if (_canFinishInOneDart(currentRemaining)) {
          result = _throwForCheckout(context);
        } else if (_canFinishInTwoDarts(currentRemaining)) {
          // 2-дротиковый финиш: первый бросок — setup под дабл
          result = _throwForCheckout(context);
        } else {
          // 3-дротиковый финиш или setup
          result = _throwForSetup(context);
        }
      } else {
        result = _throwForScoring(context);
      }

      // Проверка правил Double Out
      if (isDoubleOut) {
        int newRemaining = currentRemaining - result.score;
        if (newRemaining == 1 || newRemaining < 0) {
          // Bust — обнуляем бросок
          result = const ThrowResult(score: 0, segment: 0, multiplier: 0);
        }
      }

      // Проверка превышения очков
      if (result.score > currentRemaining) {
        result = const ThrowResult(score: 0, segment: 0, multiplier: 0);
      }

      results.add(result);
      currentRemaining -= result.score;
      dartsUsed++;

      // Проверка завершения лега
      if (currentRemaining == 0) {
        if (!isDoubleOut || result.isDouble || (result.isBull && result.score == 50)) {
          break;
        }
        // Если остаток 0, но не дабл — bust (например, S20 на остатке 20)
        // Откатываем последний бросок
        currentRemaining += result.score;
        results.removeLast();
        results.add(const ThrowResult(score: 0, segment: 0, multiplier: 0));
        dartsUsed--;
      }
    }
    return results;
  }

  /// Можно ли закрыть остаток за 1 дротик (дабл или Bull)
  bool _canFinishInOneDart(int remaining) {
    if (remaining == 50) return true; // Bull
    if (remaining > 40) return false;
    if (remaining % 2 != 0) return false;
    final doubleSector = remaining ~/ 2;
    return doubleSector >= 1 && doubleSector <= 20;
  }

  /// Можно ли закрыть остаток за 2 дротика (S + D)
  bool _canFinishInTwoDarts(int remaining) {
    if (remaining <= 40) return false; // это 1 дротик
    if (remaining > 60) return false; // 60 = S20 D20 — макс 2-дротиковый
    // Проверяем: есть ли single, после которого остаётся чётный дабл <= 40
    for (int s = 1; s <= 20; s++) {
      final afterSingle = remaining - s;
      if (afterSingle > 0 && afterSingle <= 40 && afterSingle % 2 == 0) {
        return true;
      }
    }
    return false;
  }

  /// Бросок для Double In
  ThrowResult _throwForDoubleIn(BotContext501 ctx) {
    const targets = ['D20', 'D16', 'D10', 'D12', 'D8', 'D4', 'D2'];
    final aim = TargetCoordinates.get(targets[_random.nextInt(targets.length)])!;
    return DartThrowSimulator.simulateThrow(aim.x, aim.y, _sigma.checkout);
  }

  /// Бросок для набора очков
  ThrowResult _throwForScoring(BotContext501 ctx) {
    const aimKey = 'T20';
    final aim = TargetCoordinates.get(aimKey)!;
    return DartThrowSimulator.simulateThrow(aim.x, aim.y, _sigma.scoring);
  }

  /// Бросок для setup (подготовка к финишу)
  ThrowResult _throwForSetup(BotContext501 ctx) {
    String aimKey = _getSetupAim(ctx.remainingScore);
    final aim = TargetCoordinates.get(aimKey) ?? TargetCoordinates.get('T20')!;
    return DartThrowSimulator.simulateThrow(aim.x, aim.y, _sigma.setup);
  }

  /// Бросок для checkout (финиш)
  ThrowResult _throwForCheckout(BotContext501 ctx) {
    String aimKey = _getCheckoutAim(ctx.remainingScore);
    final aim =
        TargetCoordinates.get(aimKey) ?? TargetCoordinates.get('D20')!;
    return DartThrowSimulator.simulateThrow(aim.x, aim.y, _sigma.checkout);
  }

  /// Получить цель для setup-броска
  /// Цель — оставить себе удобный дабл (D20, D16, D10, D8)
  String _getSetupAim(int remaining) {
    // Для остатков 61-100: пытаемся оставить D20 или D16
    if (remaining >= 61 && remaining <= 100) {
      // T20 оставляет remaining - 60
      final afterT20 = remaining - 60;
      if (afterT20 > 0 && afterT20 <= 40 && afterT20 % 2 == 0) {
        return 'T20';
      }
      // T19 оставляет remaining - 57
      final afterT19 = remaining - 57;
      if (afterT19 > 0 && afterT19 <= 40 && afterT19 % 2 == 0) {
        return 'T19';
      }
      // T18 оставляет remaining - 54
      final afterT18 = remaining - 54;
      if (afterT18 > 0 && afterT18 <= 40 && afterT18 % 2 == 0) {
        return 'T18';
      }
    }
    // Для остатков 41-60: оставляем дабл через single
    if (remaining >= 41 && remaining <= 60) {
      // Ищем single, после которого остаётся чётный дабл
      for (int s = 20; s >= 1; s--) {
        final afterSingle = remaining - s;
        if (afterSingle > 0 && afterSingle <= 40 && afterSingle % 2 == 0) {
          return 'S$s';
        }
      }
    }
    // По умолчанию — T20
    return 'T20';
  }

  /// Получить цель для checkout-броска
  String _getCheckoutAim(int remaining) {
    return _checkoutTable[remaining] ?? 'T20';
  }

  /// Получить уровень бота
  BotLevel get botLevel => level;

  /// Получить средний счет бота
  double get averageScore => level.averageScore;
}
