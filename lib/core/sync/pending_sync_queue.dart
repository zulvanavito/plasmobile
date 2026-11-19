import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PendingSyncItem {
  const PendingSyncItem({
    required this.idempotencyKey,
    required this.method,
    required this.path,
    required this.body,
    required this.createdAtIso,
    required this.operationLabel,
  });

  factory PendingSyncItem.fromJson(Map<String, dynamic> json) {
    return PendingSyncItem(
      idempotencyKey: json['idempotency_key'] as String,
      method: json['method'] as String,
      path: json['path'] as String,
      body: Map<String, dynamic>.from(json['body'] as Map),
      createdAtIso: json['created_at_iso'] as String,
      operationLabel: json['operation_label'] as String,
    );
  }

  final String idempotencyKey;
  final String method;
  final String path;
  final Map<String, dynamic> body;
  final String createdAtIso;
  final String operationLabel;

  Map<String, dynamic> toJson() => {
        'idempotency_key': idempotencyKey,
        'method': method,
        'path': path,
        'body': body,
        'created_at_iso': createdAtIso,
        'operation_label': operationLabel,
      };
}

class PendingSyncStorage {
  PendingSyncStorage(this._prefs);

  static const String storageKey = 'plas_pending_sync_v1';
  final SharedPreferences _prefs;

  List<PendingSyncItem> loadAll() {
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => PendingSyncItem.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  Future<List<PendingSyncItem>> enqueue(PendingSyncItem item) async {
    final items = loadAll();
    if (items.any((e) => e.idempotencyKey == item.idempotencyKey)) {
      return items;
    }
    final next = [...items, item];
    await _save(next);
    return next;
  }

  Future<List<PendingSyncItem>> remove(String idempotencyKey) async {
    final next = loadAll()
        .where((item) => item.idempotencyKey != idempotencyKey)
        .toList(growable: false);
    await _save(next);
    return next;
  }

  Future<void> clear() async {
    await _prefs.remove(storageKey);
  }

  Future<void> _save(List<PendingSyncItem> items) async {
    if (items.isEmpty) {
      await _prefs.remove(storageKey);
      return;
    }
    final encoded = jsonEncode(items.map((item) => item.toJson()).toList());
    await _prefs.setString(storageKey, encoded);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final pendingSyncStorageProvider = Provider<PendingSyncStorage>((ref) {
  return PendingSyncStorage(ref.watch(sharedPreferencesProvider));
});

const Set<String> _terminalSyncConflictCodes = {
  ApiErrorCodes.alreadyAnswered,
  ApiErrorCodes.alreadySubmitted,
  ApiErrorCodes.attemptSubmitted,
  ApiErrorCodes.idempotencyConflict,
};

class PendingSyncNotifier extends Notifier<List<PendingSyncItem>> {
  @override
  List<PendingSyncItem> build() {
    return ref.watch(pendingSyncStorageProvider).loadAll();
  }

  PendingSyncStorage get _storage => ref.read(pendingSyncStorageProvider);

  Future<void> enqueue(PendingSyncItem item) async {
    state = await _storage.enqueue(item);
  }

  Future<void> remove(String idempotencyKey) async {
    state = await _storage.remove(idempotencyKey);
  }

  Future<void> clear() async {
    await _storage.clear();
    state = const [];
  }

  Future<void> retryAll(
    Future<void> Function(PendingSyncItem item) executor,
  ) async {
    final snapshot = List<PendingSyncItem>.from(state);
    for (final item in snapshot) {
      try {
        await executor(item);
        state = await _storage.remove(item.idempotencyKey);
      } catch (error) {
        final plasError = _extractPlasError(error);
        if (plasError != null &&
            _terminalSyncConflictCodes.contains(plasError.code)) {
          state = await _storage.remove(item.idempotencyKey);
        } else if (plasError != null && plasError.isRetryable) {
          continue;
        } else {
          rethrow;
        }
      }
    }
  }

  PlasApiException? _extractPlasError(Object error) {
    if (error is PlasApiException) return error;
    if (error is DioException && error.error is PlasApiException) {
      return error.error as PlasApiException;
    }
    return null;
  }
}

final pendingSyncProvider =
    NotifierProvider<PendingSyncNotifier, List<PendingSyncItem>>(
  PendingSyncNotifier.new,
);
