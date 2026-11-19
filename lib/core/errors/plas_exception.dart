import 'package:plasmobile/core/constants/api_error_codes.dart';

class PlasApiException implements Exception {
  const PlasApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.serverMessage,
    this.isOffline = false,
  });

  factory PlasApiException.offline([String? detail]) {
    return PlasApiException(
      code: ApiErrorCodes.networkOffline,
      message: plasErrorMessage(ApiErrorCodes.networkOffline),
      serverMessage: detail,
      isOffline: true,
    );
  }

  factory PlasApiException.fromApiCode(
    String code, {
    int? statusCode,
    String? serverMessage,
  }) {
    return PlasApiException(
      statusCode: statusCode,
      code: code,
      message: plasErrorMessage(code, fallback: serverMessage),
      serverMessage: serverMessage,
      isOffline: code == ApiErrorCodes.networkOffline,
    );
  }

  final int? statusCode;
  final String code;
  final String message;
  final String? serverMessage;
  final bool isOffline;

  bool get isRetryable =>
      isOffline ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504 ||
      code == ApiErrorCodes.requestInProgress;

  @override
  String toString() =>
      'PlasApiException(statusCode: $statusCode, code: $code, message: $message)';
}
