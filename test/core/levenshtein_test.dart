import 'package:flutter_test/flutter_test.dart';
import 'package:plasmobile/core/utils/levenshtein.dart';

void main() {
  group('levenshtein utilities', () {
    test('normalizeFibAnswer trims, lowercases, and collapses whitespace', () {
      expect(
        normalizeFibAnswer('  Let   Count :  Number  '),
        'let count : number',
      );
    });

    test('levenshteinDistance computes edit distance accurately', () {
      expect(levenshteinDistance('interface', 'interface'), 0);
      expect(levenshteinDistance('interface', 'interfac'), 1);
      expect(levenshteinDistance('', 'abc'), 3);
      expect(levenshteinDistance('abc', ''), 3);
    });

    test('evaluateFibAnswer honors 70% threshold boundary', () {
      // Length 10: 3 edits => similarity 0.70 (passes)
      expect(evaluateFibAnswer('1234567xxx', '1234567890'), isTrue);
      // Length 10: 4 edits => similarity 0.60 (fails)
      expect(evaluateFibAnswer('123456xxxx', '1234567890'), isFalse);
      // Case-insensitive and whitespace-normalized match
      expect(evaluateFibAnswer('  INTERFACE ', 'interface'), isTrue);
    });

    test('evaluateFibAnswer rejects empty or >255 char answers', () {
      expect(evaluateFibAnswer('   ', 'string'), isFalse);
      final tooLong = 'a' * (kMaxFibLength + 1);
      expect(evaluateFibAnswer(tooLong, tooLong), isFalse);
    });
  });
}
