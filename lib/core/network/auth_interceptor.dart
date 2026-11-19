import 'package:dio/dio.dart';

typedef AccessTokenProvider = Future<String?> Function();

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._getAccessToken);

  final AccessTokenProvider _getAccessToken;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] == true) {
      handler.next(options);
      return;
    }

    final token = await _getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
