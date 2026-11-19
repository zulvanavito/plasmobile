import 'package:flutter_test/flutter_test.dart';
import 'package:plasmobile/core/utils/wita_clock.dart';

void main() {
  group('wita_clock (Asia/Makassar UTC+8)', () {
    test('rolls over date at 16:00 UTC (00:00 WITA)', () {
      final beforeMidnightWita = DateTime.utc(2026, 11, 19, 15, 59);
      final atMidnightWita = DateTime.utc(2026, 11, 19, 16, 0);

      expect(witaDateString(beforeMidnightWita), '2026-11-19');
      expect(nowInWita(beforeMidnightWita).hour, 23);
      expect(nowInWita(beforeMidnightWita).minute, 59);

      expect(witaDateString(atMidnightWita), '2026-11-20');
      expect(nowInWita(atMidnightWita).hour, 0);
      expect(nowInWita(atMidnightWita).minute, 0);
    });

    test('computes remaining duration until next 00:00 WITA', () {
      final sampleUtc = DateTime.utc(2026, 11, 19, 15, 30);
      expect(
        durationUntilNextWitaMidnight(sampleUtc),
        const Duration(minutes: 30),
      );
    });
  });
}
