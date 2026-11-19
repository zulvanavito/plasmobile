const int kMaxFibLength = 255;
const double kFibSimilarityThreshold = 0.70;

String normalizeFibAnswer(String input) {
  return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

int levenshteinDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var prev = List<int>.generate(b.length + 1, (j) => j);
  var curr = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    curr[0] = i;
    final aCode = a.codeUnitAt(i - 1);
    for (var j = 1; j <= b.length; j++) {
      final cost = aCode == b.codeUnitAt(j - 1) ? 0 : 1;
      final deletion = prev[j] + 1;
      final insertion = curr[j - 1] + 1;
      final substitution = prev[j - 1] + cost;
      var minVal = deletion < insertion ? deletion : insertion;
      if (substitution < minVal) minVal = substitution;
      curr[j] = minVal;
    }
    final temp = prev;
    prev = curr;
    curr = temp;
  }

  return prev[b.length];
}

double levenshteinSimilarity(String a, String b) {
  final normA = normalizeFibAnswer(a);
  final normB = normalizeFibAnswer(b);
  if (normA.isEmpty && normB.isEmpty) return 1.0;
  if (normA.isEmpty || normB.isEmpty) return 0.0;

  final maxLen = normA.length > normB.length ? normA.length : normB.length;
  final dist = levenshteinDistance(normA, normB);
  return 1.0 - (dist / maxLen);
}

bool evaluateFibAnswer(
  String studentAnswer,
  String expectedAnswer, {
  double threshold = kFibSimilarityThreshold,
}) {
  if (studentAnswer.length > kMaxFibLength) return false;
  final normStudent = normalizeFibAnswer(studentAnswer);
  final normExpected = normalizeFibAnswer(expectedAnswer);
  if (normStudent.isEmpty || normExpected.isEmpty) return false;
  return levenshteinSimilarity(normStudent, normExpected) >= threshold;
}
