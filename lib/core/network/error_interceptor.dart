import 'dart:io';

import 'package:dio/dio.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';

class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is StateError || err.error is PlasApiException) {
      handler.next(err);
      return;
    }

    final PlasApiException plasError;
    if (_isNetworkFailure(err)) {
      plasError = PlasApiException.offline(err.message);
    } else if (err.response != null) {
      plasError = _parseResponseError(err.response!);
    } else {
      plasError = PlasApiException.fromApiCode(
        ApiErrorCodes.serverError,
        serverMessage: err.message,
      );
    }

    handler.next(
      err.copyWith(
        error: plasError,
        message: plasError.message,
      ),
    );
  }

  bool _isNetworkFailure(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }
    return err.type == DioExceptionType.unknown &&
        err.response == null &&
        (err.error is SocketException || err.error == null);
  }

  PlasApiException _parseResponseError(Response<dynamic> response) {
    final statusCode = response.statusCode;
    final data = response.data;
    if (data is Map) {
      final errorNode = data['error'];
      if (errorNode is Map) {
        final code = errorNode['code']?.toString();
        final serverMessage = errorNode['message']?.toString();
        if (code != null && code.isNotEmpty) {
          return PlasApiException.fromApiCode(
            code,
            statusCode: statusCode,
            serverMessage: serverMessage,
          );
        }
      }
    }

    return PlasApiException.fromApiCode(
      _defaultCodeForStatus(statusCode),
      statusCode: statusCode,
    );
  }

  String _defaultCodeForStatus(int? statusCode) {
    return switch (statusCode) {
      400 => ApiErrorCodes.validationError,
      401 => ApiErrorCodes.unauthorized,
      403 => ApiErrorCodes.forbidden,
      404 => ApiErrorCodes.notFound,
      409 => ApiErrorCodes.invalidStateTransition,
      422 => ApiErrorCodes.invalidAnswer,
      502 => ApiErrorCodes.aiServiceError,
      504 => ApiErrorCodes.aiTimeout,
      _ => ApiErrorCodes.serverError,
    };
  }
}
