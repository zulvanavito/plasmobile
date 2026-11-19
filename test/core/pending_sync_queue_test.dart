import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

PendingSyncItem _makeItem(String key, String label) {
  return PendingSyncItem(
    idempotencyKey: key,
    method: 'POST',
    path: '/exercise-attempts/a1/answers',
    body: {
      'question_id': 'q1',
      'answer': {'value': true},
    },
    createdAtIso: '2026-11-19T12:00:00Z',
    operationLabel: label,
  );
}

void main() {
  group('PendingSyncQueue', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('deduplicates by idempotencyKey and persists across instances', () async {
      final prefs = await SharedPreferences.getInstance();
      final storageA = PendingSyncStorage(prefs);

      await storageA.enqueue(_makeItem('uuid-1', 'Jawaban 1'));
      await storageA.enqueue(_makeItem('uuid-1', 'Jawaban 1 duplikat'));
      await storageA.enqueue(_makeItem('uuid-2', 'Jawaban 2'));

      final storageB = PendingSyncStorage(prefs);
      final loaded = storageB.loadAll();
      expect(loaded.length, 2);
      expect(loaded.map((e) => e.idempotencyKey), ['uuid-1', 'uuid-2']);
    });

    test('retryAll removes succeeded and terminal 409 items while keeping offline items', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pendingSyncProvider.notifier);
      await notifier.enqueue(_makeItem('uuid-ok', 'Sukses'));
      await notifier.enqueue(_makeItem('uuid-dup', 'Sudah dijawab'));
      await notifier.enqueue(_makeItem('uuid-offline', 'Masih offline'));

      await notifier.retryAll((item) async {
        if (item.idempotencyKey == 'uuid-dup') {
          throw PlasApiException.fromApiCode(
            ApiErrorCodes.alreadyAnswered,
            statusCode: 409,
          );
        }
        if (item.idempotencyKey == 'uuid-offline') {
          throw PlasApiException.offline();
        }
      });

      final remaining = container.read(pendingSyncProvider);
      expect(remaining.length, 1);
      expect(remaining.single.idempotencyKey, 'uuid-offline');
    });
  });
}
