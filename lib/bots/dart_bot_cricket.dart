import 'dart:math';
import '../models/game_enums.dart';
import 'dart_throw_simulator.dart';
import 'bot_sigma_config.dart';
import 'bot_context_cricket.dart';
import 'target_coordinates.dart';

/// Бот для игры Cricket с физической моделью броска
class DartBotCricket {
  final BotLevel level;
  final BotSigmaConfig _sigma;
  final Random _random = Random();

  DartBotCricket(this.level) : _sigma = BotSigmaConfig.forLevel(level);

  /// Бросить подход (3 дротика) на основе контекста.
  /// Возвращает Map от sector к hits.
  Map<int, int> throwTurn(CricketBotContext ctx) {
    final result = <int, int>{};

    for (int dart = 0; dart < 3; dart++) {
      final aimKey = _chooseAim(ctx, result);
      if (aimKey == null) break; // Нет целей — все закрыты

      final aim = TargetCoordinates.get(aimKey);
      if (aim == null) break;

      final throwResult =
          DartThrowSimulator.simulateThrow(aim.x, aim.y, _sigma.scoring);

      if (throwResult.score > 0) {
        final sector = throwResult.segment;
        final hits = throwResult.multiplier;

        // Проверяем, имеет ли смысл засчитывать попадание
        if (_isSectorUseful(sector, ctx, result)) {
          result[sector] = (result[sector] ?? 0) + hits;
        }
      }
    }

    return result;
  }

  /// Выбрать цель для текущего дротика
  /// Принимает во внимание уже набранные hits в текущем подходе
  String? _chooseAim(CricketBotContext ctx, Map<int, int> currentTurnHits) {
    // 1. Розовый приоритет: сектора, которые соперник закрыл, а бот — нет
    final urgent = ctx.opponentClosedSectors;
    if (urgent.isNotEmpty) {
      final sector = _pickSector(urgent, currentTurnHits);
      if (sector != null) return _aimForSector(sector);
    }

    // 2. Открытые сектора (оба не закрыли) — от большего номинала
    final open = ctx.bothOpenSectors;
    if (open.isNotEmpty) {
      final sector = _pickSector(open, currentTurnHits);
      if (sector != null) return _aimForSector(sector);
    }

    // 3. American: сектора, где бот закрыл, а соперник нет — набор очков
    if (ctx.variant == CricketVariant.american) {
      final scoring = ctx.myClosedSectors;
      if (scoring.isNotEmpty) {
        final sector = _pickSector(scoring, currentTurnHits);
        if (sector != null) return _aimForSector(sector);
      }
    }

    // 4. Всё закрыто — бесполезный бросок (например, в T20 для галочки)
    return 'T20';
  }

  /// Выбрать сектор из списка, отдавая приоритет незакрытым в этом подходе
  int? _pickSector(List<int> sectors, Map<int, int> currentTurnHits) {
    // Сначала ищем сектор, который ещё не добит до 3 в этом подходе
    for (final s in sectors) {
      final turnHits = currentTurnHits[s] ?? 0;
      final myHits = _getMyHitsForSector(s); // заглушка, заполняется из контекста
      if (myHits + turnHits < 3) return s;
    }
    // Все уже закрыты в этом подходе — берём первый
    return sectors.isNotEmpty ? sectors.first : null;
  }

  // Вспомогательное поле для _pickSector — будет перезаписано перед throwTurn
  Map<int, int> _myHitsCache = {};

  int _getMyHitsForSector(int sector) => _myHitsCache[sector] ?? 0;

  /// Выбрать цель для указанного сектора в зависимости от уровня бота
  String _aimForSector(int sector) {
    if (sector == 25) {
      // Bull: бот целится в Bull (центр)
      return 'Bull';
    }

    // В зависимости от уровня выбираем Triple, Double или Single
    switch (level) {
      case BotLevel.beginner35_45:
        // Новичок целится в Single
        return 'S$sector';
      case BotLevel.amateur45_55:
        // Любитель: 50% Single, 50% Double
        return _random.nextBool() ? 'S$sector' : 'D$sector';
      case BotLevel.amateur55_65:
        // Любитель+: 30% Single, 70% Double
        return _random.nextDouble() < 0.3 ? 'S$sector' : 'D$sector';
      case BotLevel.pro65_75:
        // Профи: 30% Double, 70% Triple
        return _random.nextDouble() < 0.3 ? 'D$sector' : 'T$sector';
      case BotLevel.pro75_85:
        // Профи+: 20% Double, 80% Triple
        return _random.nextDouble() < 0.2 ? 'D$sector' : 'T$sector';
      case BotLevel.expert85_95:
        // Эксперт: почти всегда Triple
        return _random.nextDouble() < 0.1 ? 'D$sector' : 'T$sector';
    }
  }

  /// Проверить, полезно ли попадание в сектор (не переполняет лимит 3)
  bool _isSectorUseful(int sector, CricketBotContext ctx, Map<int, int> currentTurnHits) {
    final myHits = ctx.myHits[sector] ?? 0;
    final turnHits = currentTurnHits[sector] ?? 0;
    final total = myHits + turnHits;

    // Если уже 3+ хитов в сумме — сектор закрыт, дальше только очки в American
    if (total >= 3) {
      if (ctx.variant == CricketVariant.american) {
        // Очки начисляются только если соперник не закрыл
        final oppHits = ctx.opponentHits[sector] ?? 0;
        return oppHits < 3;
      }
      return false; // Classic — бесполезно
    }

    // Если соперник закрыл, а бот нет — всё равно полезно (закрываемся)
    final oppHits = ctx.opponentHits[sector] ?? 0;
    if (oppHits >= 3) return true;

    // Сектор открыт у обоих — полезно
    return true;
  }

  /// Основной метод для внешнего вызова
  Map<int, int> throwTurnWithContext({
    required Map<int, int> myHits,
    required Map<int, int> opponentHits,
    required CricketVariant variant,
  }) {
    _myHitsCache = Map.from(myHits);
    final ctx = CricketBotContext(
      myHits: myHits,
      opponentHits: opponentHits,
      variant: variant,
    );
    return throwTurn(ctx);
  }
}
