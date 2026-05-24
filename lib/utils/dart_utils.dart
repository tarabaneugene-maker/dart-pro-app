/// Невозможные суммы для трёх дротиков (макс 180, но не все числа достижимы)
const Set<int> _invalidThreeDartScores = {
  163, 166, 169, 172, 173, 175, 176, 178, 179,
};

/// Проверяет, можно ли набрать [score] тремя дротиками (или меньше).
/// Учитывает: Single (1-20), Double (2-40), Triple (3-60), Bull (25/50), 0.
bool isValidThreeDartScore(int score) {
  return score >= 0 && score <= 180 && !_invalidThreeDartScores.contains(score);
}
