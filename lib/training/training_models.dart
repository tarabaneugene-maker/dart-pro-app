// Модели для тренировочных режимов

enum TrainingMode { sector, aroundTheClock, aroundTheClockClassic }
enum TrainingStep { menu, setup, process }
enum AroundDifficulty { single, double, triple }

class TrainingState {
  TrainingStep step;
  TrainingMode? mode;
  int selectedSector;
  final List<int> sectorAttempts;
  AroundDifficulty aroundDifficulty;
  int aroundTarget;
  int aroundTotalScore;
  int? pendingInputValue;
  bool isAutoOkEnabled;
  
  static const int maxSectorAttempts = 10;

  TrainingState({
    this.step = TrainingStep.menu,
    this.mode,
    this.selectedSector = 20,
    List<int>? sectorAttempts,
    this.aroundDifficulty = AroundDifficulty.single,
    this.aroundTarget = 1,
    this.aroundTotalScore = 0,
    this.pendingInputValue,
    this.isAutoOkEnabled = false,
  }) : sectorAttempts = sectorAttempts ?? [];

  bool get isAroundFinished => aroundTarget > 21;
  bool get isBullTarget => aroundTarget == 21;

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
    );
  }
}