/// Невозможные суммы для трёх дротиков (макс 180, но не все числа достижимы)
const Set<int> _invalidThreeDartScores = {
  163, 166, 169, 172, 173, 175, 176, 178, 179,
};

/// Проверяет, можно ли набрать [score] тремя дротиками (или меньше).
/// Учитывает: Single (1-20), Double (2-40), Triple (3-60), Bull (25/50), 0.
bool isValidThreeDartScore(int score) {
  return score >= 0 && score <= 180 && !_invalidThreeDartScores.contains(score);
}

// ===================================================================
// Валидация закрытия лега по количеству дротиков (Double Out)
// ===================================================================

/// Суммы, достижимые одним дротиком при Double Out (чётные даблы до 40 + Bull)
const Set<int> _validOneDartDoubleOut = {
  2, 4, 6, 8, 10, 12, 14, 16, 18, 20,
  22, 24, 26, 28, 30, 32, 34, 36, 38, 40,
  50,
};

/// Суммы, НЕдостижимые двумя дротиками при Double Out (от 2 до 110)
const Set<int> _invalidTwoDartDoubleOut = {
  0, 1, 99, 102, 103, 105, 106, 108, 109,
};

/// Суммы, НЕдостижимые тремя дротиками при Double Out (от 2 до 170)
const Set<int> _invalidThreeDartDoubleOut = {
  0, 1, 159, 162, 163, 165, 166, 168, 169,
};

/// Можно ли закрыть [score] ровно [dartCount] дротиками при Double Out?
bool canFinishWithDarts(int score, int dartCount, {bool isDoubleOut = true}) {
  if (score <= 0) return false;

  if (isDoubleOut) {
    switch (dartCount) {
      case 1:
        return _validOneDartDoubleOut.contains(score);
      case 2:
        return score >= 2 && score <= 110 && !_invalidTwoDartDoubleOut.contains(score);
      case 3:
        return score >= 2 && score <= 170 && !_invalidThreeDartDoubleOut.contains(score);
      default:
        return false;
    }
  } else {
    // Single Out
    switch (dartCount) {
      case 1:
        return (score >= 1 && score <= 20) || score == 25 || score == 50;
      case 2:
        return score >= 2 && score <= 120;
      case 3:
        return score >= 2 && score <= 180;
      default:
        return false;
    }
  }
}


