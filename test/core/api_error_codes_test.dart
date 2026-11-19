import 'package:flutter_test/flutter_test.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';

void main() {
  group('ApiErrorCodes & plasErrorMessage', () {
    test('every mapped message is non-empty and contains no em dash', () {
      expect(ApiErrorCodes.messages.length, greaterThanOrEqualTo(25));
      for (final entry in ApiErrorCodes.messages.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: 'Empty message for ${entry.key}');
        expect(
          entry.value.contains('\u2014'),
          isFalse,
          reason: 'Em dash found in message for ${entry.key}',
        );
      }
    });

    test('critical domain error messages match DESIGN.md copy rules', () {
      expect(plasErrorMessage(ApiErrorCodes.quotaExceeded), contains('00:00 WITA'));
      expect(plasErrorMessage(ApiErrorCodes.attemptLimitReached), contains('3/3'));
      expect(plasErrorMessage(ApiErrorCodes.classLocked), contains('SUBMITTED'));
      expect(plasErrorMessage(ApiErrorCodes.prerequisiteNotMet), contains('7 materi'));
      expect(plasErrorMessage(ApiErrorCodes.nimConflict), contains('NIM'));
      expect(plasErrorMessage(ApiErrorCodes.networkOffline), contains('idempotensi'));
    });

    test('unknown code uses fallback if present, otherwise serverError', () {
      expect(
        plasErrorMessage('custom_unknown', fallback: 'Pesan server'),
        'Pesan server',
      );
      expect(
        plasErrorMessage('custom_unknown'),
        plasErrorMessage(ApiErrorCodes.serverError),
      );
    });
  });
}
