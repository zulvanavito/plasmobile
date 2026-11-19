import 'package:dio/dio.dart';

const String kIdempotencyHeader = 'Idempotency-Key';
const String kIdempotencyKeyExtra = 'idempotencyKey';
const String kRequireIdempotencyExtra = 'requireIdempotency';

/// Attaches a caller-owned Idempotency-Key header without regenerating it on retry.
class IdempotencyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final existingHeader = options.headers[kIdempotencyHeader]?.toString();
    final extraKey = options.extra[kIdempotencyKeyExtra]?.toString();

    if ((existingHeader == null || existingHeader.isEmpty) &&
        extraKey != null &&
        extraKey.isNotEmpty) {
      options.headers[kIdempotencyHeader] = extraKey;
    }

    final activeKey = options.headers[kIdempotencyHeader]?.toString();
    if (options.extra[kRequireIdempotencyExtra] == true &&
        (activeKey == null || activeKey.isEmpty)) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: StateError('Missing Idempotency-Key for idempotent mutation'),
        ),
        true,
      );
      return;
    }

    handler.next(options);
  }
}
