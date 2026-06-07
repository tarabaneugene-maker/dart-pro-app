// Модели для тренировочных режимов

/// Режимы тренировок
enum TrainingMode {
  sector,
  aroundTheClock,
  aroundTheClockClassic,
  bob27,
  shanghai,
}

/// Шаги навигации
enum TrainingStep { menu, setup, process }

/// Сложность Around the Clock
enum AroundDifficulty { single, double, triple }

/// Информация об игроке в тренировке
class TrainingPlayerInfo {
  final String name;
  final int totalScore;
  final int totalHits;
  final int totalTurns;

  const TrainingPlayerInfo({
    required this.name,
    this.totalScore = 0,
    this.totalHits = 0,
    this.totalTurns = 0,
  });

  TrainingPlayerInfo copyWith({
    String? name,
    int? totalScore,
    int? totalHits,
    int? totalTurns,
  }) {
    return TrainingPlayerInfo(
      name: name ?? this.name,
      totalScore: totalScore ?? this.totalScore,
      totalHits: totalHits ?? this.totalHits,
      totalTurns: totalTurns ?? this.totalTurns,
    );
  }
}

/// Состояние тренировки
class TrainingState {
  TrainingStep step;
  TrainingMode? mode;
  int selectedSector;
  AroundDifficulty aroundDifficulty;
  int aroundTarget;
  int aroundTotalScore;
  int? pendingInputValue;
  bool isAutoOkEnabled;

  // Парный режим
  bool isPaired;
  int currentPlayerIndex; // 0 = P1, 1 = P2
  TrainingPlayerInfo player1;
  TrainingPlayerInfo player2;

  // Сектор
  final List<int> sectorAttempts;

  // Bob27
  int bob27Score;
  int bob27CurrentSector; // 1..20

  // Shanghai
  int shanghaiCurrentSector; // 1..7 (или до 20)
  int shanghaiDartsInSector; // 0..3
  bool shanghaiFinished;

  static const int maxSectorAttempts = 10;
  static const int bob27StartScore = 27;
  static const int shanghaiMaxSector = 7;

  TrainingState({
    this.step = TrainingStep.menu,
    this.mode,
    this.selectedSector = 20,
    this.aroundDifficulty = AroundDifficulty.single,
    this.aroundTarget = 1,
    this.aroundTotalScore = 0,
    this.pendingInputValue,
    this.isAutoOkEnabled = false,
    this.isPaired = false,
    this.currentPlayerIndex = 0,
    TrainingPlayerInfo? player1,
    TrainingPlayerInfo? player2,
    List<int>? sectorAttempts,
    this.bob27Score = bob27StartScore,
    this.bob27CurrentSector = 1,
    this.shanghaiCurrentSector = 1,
    this.shanghaiDartsInSector = 0,
    this.shanghaiFinished = false,
  })  : sectorAttempts = sectorAttempts ?? [],
        player1 = player1 ?? const TrainingPlayerInfo(name: 'Игрок1'),
        player2 = player2 ?? const TrainingPlayerInfo(name: 'Игрок2');

  bool get isAroundFinished => aroundTarget > 21;
  bool get isBullTarget => aroundTarget == 21;

  TrainingPlayerInfo get currentPlayer =>
      currentPlayerIndex == 0 ? player1 : player2;

  void switchPlayer() {
    currentPlayerIndex = currentPlayerIndex == 0 ? 1 : 0;
  }

  TrainingState copyWith({
    TrainingStep? step,
    TrainingMode? mode,
    int? selectedSector,
    List<int>? sectorAttempts,
    AroundDifficulty? aroundDifficulty,
    int? aroundTarget,
    int? aroundTotalScore,
    int? pendingInputValue,
    bool? isAutoOkEnabled,
    bool? isPaired,
    int? currentPlayerIndex,
    TrainingPlayerInfo? player1,
    TrainingPlayerInfo? player2,
    int? bob27Score,
    int? bob27CurrentSector,
    int? shanghaiCurrentSector,
    int? shanghaiDartsInSector,
    bool? shanghaiFinished,
  }) {
    return TrainingState(
      step: step ?? this.step,
      mode: mode ?? this.mode,
      selectedSector: selectedSector ?? this.selectedSector,
      sectorAttempts: sectorAttempts ?? this.sectorAttempts,
      aroundDifficulty: aroundDifficulty ?? this.aroundDifficulty,
      aroundTarget: aroundTarget ?? this.aroundTarget,
      aroundTotalScore: aroundTotalScore ?? this.aroundTotalScore,
      pendingInputValue: pendingInputValue ?? this.pendingInputValue,
      isAutoOkEnabled: isAutoOkEnabled ?? this.isAutoOkEnabled,
      isPaired: isPaired ?? this.isPaired,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      player1: player1 ?? this.player1,
      player2: player2 ?? this.player2,
      bob27Score: bob27Score ?? this.bob27Score,
      bob27CurrentSector: bob27CurrentSector ?? this.bob27CurrentSector,
      shanghaiCurrentSector:
          shanghaiCurrentSector ?? this.shanghaiCurrentSector,
      shanghaiDartsInSector: shanghaiDartsInSector ?? this.shanghaiDartsInSector,
      shanghaiFinished: shanghaiFinished ?? this.shanghaiFinished,
    );
  }
}
