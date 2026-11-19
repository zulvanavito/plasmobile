import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plasmobile/core/config/app_env.dart';
import 'package:plasmobile/core/network/auth_interceptor.dart';
import 'package:plasmobile/core/network/error_interceptor.dart';
import 'package:plasmobile/core/network/idempotency_interceptor.dart';

const Duration kAiRequestTimeout = Duration(seconds: 35);

final accessTokenProvider = Provider<AccessTokenProvider>(
  (ref) => () async => null,
);

Dio createPlasDio({
  required String baseUrl,
  required AccessTokenProvider getAccessToken,
  HttpClientAdapter? httpClientAdapter,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  if (httpClientAdapter != null) {
    dio.httpClientAdapter = httpClientAdapter;
  }

  dio.interceptors.addAll([
    AuthInterceptor(getAccessToken),
    IdempotencyInterceptor(),
    ErrorInterceptor(),
  ]);

  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  return createPlasDio(
    baseUrl: AppEnv.apiBaseUrl,
    getAccessToken: ref.watch(accessTokenProvider),
  );
});
