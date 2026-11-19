import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/network/dio_client.dart';
import 'package:plasmobile/core/network/idempotency_interceptor.dart';

class _FakeHttpAdapter implements HttpClientAdapter {
  _FakeHttpAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> capturedRequests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedRequests.add(options);
    return handler(options);
  }
}

ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

void main() {
  group('Dio interceptors', () {
    test('attaches Bearer JWT and respects skipAuth extra', () async {
      final adapter = _FakeHttpAdapter(
        (options) async => _jsonResponse(200, {'ok': true}),
      );
      final dio = createPlasDio(
        baseUrl: 'https://example.test/api',
        getAccessToken: () async => 'jwt-token-xyz',
        httpClientAdapter: adapter,
      );

      await dio.get<dynamic>('/me');
      expect(
        adapter.capturedRequests.last.headers['Authorization'],
        'Bearer jwt-token-xyz',
      );

      await dio.get<dynamic>(
        '/health',
        options: Options(extra: {'skipAuth': true}),
      );
      expect(adapter.capturedRequests.last.headers['Authorization'], isNull);
    });

    test('preserves caller-owned Idempotency-Key across retries', () async {
      final adapter = _FakeHttpAdapter(
        (options) async => _jsonResponse(200, {'ok': true}),
      );
      final dio = createPlasDio(
        baseUrl: 'https://example.test/api',
        getAccessToken: () async => 'jwt',
        httpClientAdapter: adapter,
      );

      const stableKey = '11111111-2222-4333-8444-555555555555';
      final opts = Options(
        extra: {
          kRequireIdempotencyExtra: true,
          kIdempotencyKeyExtra: stableKey,
        },
      );

      await dio.post<dynamic>('/exercise-attempts/1/answers', data: {}, options: opts);
      await dio.post<dynamic>('/exercise-attempts/1/answers', data: {}, options: opts);

      expect(adapter.capturedRequests[0].headers[kIdempotencyHeader], stableKey);
      expect(adapter.capturedRequests[1].headers[kIdempotencyHeader], stableKey);
    });

    test('rejects mutation missing Idempotency-Key when required', () async {
      final adapter = _FakeHttpAdapter(
        (options) async => _jsonResponse(200, {'ok': true}),
      );
      final dio = createPlasDio(
        baseUrl: 'https://example.test/api',
        getAccessToken: () async => 'jwt',
        httpClientAdapter: adapter,
      );

      await expectLater(
        () => dio.post<dynamic>(
          '/ai/ask',
          data: {'question': 'Apa itu let?'},
          options: Options(extra: {kRequireIdempotencyExtra: true}),
        ),
        throwsA(
          isA<DioException>().having((e) => e.error, 'error', isA<StateError>()),
        ),
      );
      expect(adapter.capturedRequests, isEmpty);
    });

    test('maps API error envelope to PlasApiException', () async {
      final adapter = _FakeHttpAdapter(
        (options) async => _jsonResponse(409, {
          'error': {
            'code': ApiErrorCodes.classLocked,
            'message': 'Raw DB error',
          },
        }),
      );
      final dio = createPlasDio(
        baseUrl: 'https://example.test/api',
        getAccessToken: () async => 'jwt',
        httpClientAdapter: adapter,
      );

      await expectLater(
        () => dio.patch<dynamic>('/me/class', data: {'kelas_id': 'k1'}),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<PlasApiException>()
                .having((p) => p.code, 'code', ApiErrorCodes.classLocked)
                .having((p) => p.statusCode, 'statusCode', 409)
                .having((p) => p.isOffline, 'isOffline', isFalse)
                .having(
                  (p) => p.message,
                  'message',
                  plasErrorMessage(ApiErrorCodes.classLocked),
                ),
          ),
        ),
      );
    });

    test('maps connection failure to offline retryable PlasApiException', () async {
      final adapter = _FakeHttpAdapter((options) async {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'No internet',
        );
      });
      final dio = createPlasDio(
        baseUrl: 'https://example.test/api',
        getAccessToken: () async => 'jwt',
        httpClientAdapter: adapter,
      );

      await expectLater(
        () => dio.get<dynamic>('/materials'),
        throwsA(
          isA<DioException>().having(
            (e) => e.error,
            'error',
            isA<PlasApiException>()
                .having((p) => p.isOffline, 'isOffline', isTrue)
                .having((p) => p.isRetryable, 'isRetryable', isTrue),
          ),
        ),
      );
    });
  });
}
