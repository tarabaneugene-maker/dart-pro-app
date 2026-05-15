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
  static const Map<int, String> _checkoutTable = {
    170: 'T20',
    167: 'T20',
    164: 'T20',
    161: 'T20',
    160: 'T20',
    158: 'T20',
    157: 'T20',
    156: 'T20',
    155: 'T20',
    154: 'T20',
    153: 'T20',
    152: 'T20',
    151: 'T20',
    150: 'T20',
    149: 'T20',
    148: 'T20',
    147: 'T20',
    146: 'T20',
    145: 'T20',
    144: 'T20',
    143: 'T20',
    142: 'T20',
    141: 'T20',
    140: 'T20',
    139: 'T19',
    138: 'T20',
    137: 'T20',
    136: 'T20',
    135: 'T20',
    134: 'T20',
    133: 'T20',
    132: 'T20',
    131: 'T20',
    130: 'T20',
    129: 'T19',
    128: 'T18',
    127: 'T20',
    126: 'T19',
    125: 'T20',
    124: 'T20',
    123: 'T19',
    122: 'T18',
    121: 'T20',
    120: 'T20',
    119: 'T19',
    118: 'T20',
    117: 'T20',
    116: 'T20',
    115: 'T20',
    114: 'T20',
    113: 'T20',
    112: 'T20',
    111: 'T20',
    110: 'T20',
    109: 'T20',
    108: 'T20',
    107: 'T19',
    106: 'T20',
    105: 'T20',
    104: 'T18',
    103: 'T20',
    102: 'T20',
    101: 'T20',
    100: 'T20',
    99: 'T19',
    98: 'T20',
    97: 'T19',
    96: 'T20',
    95: 'T20',
    94: 'T18',
    93: 'T19',
    92: 'T20',
    91: 'T17',
    90: 'T20',
    89: 'T19',
    88: 'T20',
    87: 'T17',
    86: 'T18',
    85: 'T15',
    84: 'T20',
    83: 'T17',
    82: 'T14',
    81: 'T19',
    80: 'T20',
    79: 'T19',
    78: 'T18',
    77: 'T15',
    76: 'T20',
    75: 'T17',
    74: 'T14',
    73: 'T19',
    72: 'T16',
    71: 'T13',
    70: 'T10',
    69: 'T15',
    68: 'T20',
    67: 'T17',
    66: 'T10',
    65: 'T15',
    64: 'T16',
    63: 'T13',
    62: 'T10',
    61: 'T15',
    60: 'S20',
    59: 'S19',
    58: 'S18',
    57: 'S17',
    56: 'S16',
    55: 'S15',
    54: 'S14',
    53: 'S13',
    52: 'S12',
    51: 'S11',
    50: 'Bull',
    49: 'S9',
    48: 'S8',
    47: 'S15',
    46: 'S6',
    45: 'S13',
    44: 'S4',
    43: 'S11',
    42: 'S10',
    41: 'S9',
    40: 'D20',
    39: 'S7',
    38: 'D19',
    37: 'S5',
    36: 'D18',
    35: 'S3',
    34: 'D17',
    33: 'S1',
    32: 'D16',
    31: 'S15',
    30: 'D15',
    29: 'S13',
    28: 'D14',
    27: 'S11',
    26: 'D13',
    25: 'S9',
    24: 'D12',
    23: 'S7',
    22: 'D11',
    21: 'S5',
    20: 'D10',
    19: 'S3',
    18: 'D9',
    17: 'S1',
    16: 'D8',
    15: 'S7',
    14: 'D7',
    13: 'S5',
    12: 'D6',
    11: 'S3',
    10: 'D5',
    9: 'S1',
    8: 'D4',
    7: 'S3',
    6: 'D3',
    5: 'S1',
    4: 'D2',
    3: 'S1',
    2: 'D1',
  };

  DartBot501(this.level) : _sigma = BotSigmaConfig.forLevel(level);

  /// Бросить 3 дротика на основе текущего состояния
  List<int> throwDarts({
    required int remainingScore,
    required bool isDoubleIn,
    required bool isDoubleOut,
    bool isFirstDartOfLeg = false,
    int dartsThrownInLeg = 0,
    int opponentRemaining = 501,
  }) {
    final results = <int>[];
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

      int score;
      if (!doubleInClosed) {
        score = _throwForDoubleIn(context);
        if (score > 0) doubleInClosed = true;
      } else if (isDoubleOut && currentRemaining <= 170) {
        if (currentRemaining <= 40 ||
            _isDirectCheckoutAttempt(currentRemaining)) {
          score = _throwForCheckout(context);
        } else {
          score = _throwForSetup(context);
        }
      } else {
        score = _throwForScoring(context);
      }

      // Проверка правил Double Out
      if (isDoubleOut) {
        int newRemaining = currentRemaining - score;
        if (newRemaining == 1 || newRemaining < 0) {
          score = 0;
        }
      }

      // Проверка превышения очков
      if (score > currentRemaining) {
        score = 0;
      }

      results.add(score);
      currentRemaining -= score;
      dartsUsed++;

      // Проверка завершения лега
      if (currentRemaining == 0 &&
          (!isDoubleOut || score % 2 == 0 || score == 50)) {
        break;
      }
    }
    return results;
  }

  /// Бросок для Double In
  int _throwForDoubleIn(BotContext501 ctx) {
    const targets = ['D20', 'D16', 'D10', 'D12', 'D8', 'D4', 'D2'];
    final aim = TargetCoordinates.get(targets[_random.nextInt(targets.length)])!;
    return DartThrowSimulator.simulateThrow(aim.x, aim.y, _sigma.checkout);
  }

  /// Бросок для набора очков
  int _throwForScoring(BotContext501 ctx) {
    const aimKey = 'T20';
    final aim = TargetCoordinates.get(aimKey)!;
    return DartThrowSimulator.simulateThrow(aim.x, aim.y, _sigma.scoring);
  }

  /// Бросок для setup (подготовка к финишу)
  int _throwForSetup(BotContext501 ctx) {
    String aimKey = _getSetupAim(ctx.remainingScore);
    final aim = TargetCoordinates.get(aimKey) ?? TargetCoordinates.get('T20')!;
    return DartThrowSimulator.simulateThrow(aim.x, aim.y, _sigma.setup);
  }

  /// Бросок для checkout (финиш)
  int _throwForCheckout(BotContext501 ctx) {
    String aimKey = _getCheckoutAim(ctx.remainingScore);
    final aim =
        TargetCoordinates.get(aimKey) ?? TargetCoordinates.get('D20')!;
    return DartThrowSimulator.simulateThrow(aim.x, aim.y, _sigma.checkout);
  }

  /// Проверить, является ли попытка прямым финишем
  bool _isDirectCheckoutAttempt(int remaining) => remaining <= 40;

  /// Получить цель для setup-броска
  String _getSetupAim(int remaining) {
    if (remaining == 50) return 'S10';
    if (remaining == 48) return 'S16';
    if (remaining == 46) return 'S6';
    if (remaining == 44) return 'S4';
    if (remaining == 42) return 'S10';
    if (remaining == 40) return 'D20';
    if (remaining <= 60) return 'S20';
    if (remaining <= 90) return 'T20';
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
