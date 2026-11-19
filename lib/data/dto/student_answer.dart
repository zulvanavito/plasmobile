import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/utils/levenshtein.dart';

enum QuestionType {
  mc('MC'),
  tf('TF'),
  fib('FIB');

  const QuestionType(this.apiValue);

  final String apiValue;

  static QuestionType fromApi(String raw) {
    for (final value in values) {
      if (value.apiValue == raw) return value;
    }
    throw PlasApiException.fromApiCode(
      ApiErrorCodes.validationError,
      statusCode: 400,
      serverMessage: 'Unknown QuestionType: $raw',
    );
  }
}

enum AttemptStatus {
  inProgress('IN_PROGRESS'),
  submitted('SUBMITTED');

  const AttemptStatus(this.apiValue);

  final String apiValue;

  static AttemptStatus fromApi(String raw) {
    for (final value in values) {
      if (value.apiValue == raw) return value;
    }
    throw PlasApiException.fromApiCode(
      ApiErrorCodes.validationError,
      statusCode: 400,
      serverMessage: 'Unknown AttemptStatus: $raw',
    );
  }
}

enum TestType {
  pre('PRE'),
  post('POST');

  const TestType(this.apiValue);

  final String apiValue;

  static TestType fromApi(String raw) {
    for (final value in values) {
      if (value.apiValue == raw) return value;
    }
    throw PlasApiException.fromApiCode(
      ApiErrorCodes.validationError,
      statusCode: 400,
      serverMessage: 'Unknown TestType: $raw',
    );
  }
}

enum TestOverviewStatus {
  notStarted('NOT_STARTED'),
  inProgress('IN_PROGRESS'),
  submitted('SUBMITTED');

  const TestOverviewStatus(this.apiValue);

  final String apiValue;

  static TestOverviewStatus fromApi(String raw) {
    for (final value in values) {
      if (value.apiValue == raw) return value;
    }
    throw PlasApiException.fromApiCode(
      ApiErrorCodes.validationError,
      statusCode: 400,
      serverMessage: 'Unknown TestOverviewStatus: $raw',
    );
  }
}

enum AiHintLevel {
  konsepDasar(1, 'Konsep Dasar'),
  strategi(2, 'Strategi'),
  penalaran(3, 'Penalaran');

  const AiHintLevel(this.level, this.label);

  final int level;
  final String label;

  static AiHintLevel fromValue(int raw) {
    for (final value in values) {
      if (value.level == raw) return value;
    }
    throw PlasApiException.fromApiCode(
      ApiErrorCodes.validationError,
      statusCode: 400,
      serverMessage: 'Unknown AiHintLevel: $raw',
    );
  }
}

sealed class StudentAnswer {
  const StudentAnswer();

  Map<String, dynamic> toJson();

  factory StudentAnswer.fromJson(QuestionType type, Map<String, dynamic> json) {
    if (json.length != 1) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.invalidAnswer,
        statusCode: 422,
        serverMessage: 'Answer payload must contain exactly one canonical key.',
      );
    }

    switch (type) {
      case QuestionType.mc:
        if (!json.containsKey('option_id')) {
          throw PlasApiException.fromApiCode(
            ApiErrorCodes.invalidAnswer,
            statusCode: 422,
            serverMessage: 'MC answer requires "option_id".',
          );
        }
        final rawOptionId = json['option_id'];
        if (rawOptionId is! String || rawOptionId.trim().isEmpty) {
          throw PlasApiException.fromApiCode(
            ApiErrorCodes.invalidAnswer,
            statusCode: 422,
            serverMessage: 'MC "option_id" must be a non-empty string.',
          );
        }
        return McAnswer(rawOptionId);

      case QuestionType.tf:
        if (!json.containsKey('value')) {
          throw PlasApiException.fromApiCode(
            ApiErrorCodes.invalidAnswer,
            statusCode: 422,
            serverMessage: 'TF answer requires "value".',
          );
        }
        final rawBool = json['value'];
        if (rawBool is! bool) {
          throw PlasApiException.fromApiCode(
            ApiErrorCodes.invalidAnswer,
            statusCode: 422,
            serverMessage: 'TF "value" must be a boolean.',
          );
        }
        return TfAnswer(rawBool);

      case QuestionType.fib:
        if (!json.containsKey('value')) {
          throw PlasApiException.fromApiCode(
            ApiErrorCodes.invalidAnswer,
            statusCode: 422,
            serverMessage: 'FIB answer requires "value".',
          );
        }
        final rawText = json['value'];
        if (rawText is! String || rawText.length > kMaxFibLength) {
          throw PlasApiException.fromApiCode(
            ApiErrorCodes.invalidAnswer,
            statusCode: 422,
            serverMessage:
                'FIB "value" must be a string with length <= $kMaxFibLength.',
          );
        }
        return FibAnswer(rawText);
    }
  }
}

final class McAnswer extends StudentAnswer {
  const McAnswer(this.optionId);

  final String optionId;

  @override
  Map<String, dynamic> toJson() {
    if (optionId.trim().isEmpty) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.invalidAnswer,
        statusCode: 422,
        serverMessage: 'MC "option_id" must not be empty.',
      );
    }
    return <String, dynamic>{'option_id': optionId};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is McAnswer &&
          runtimeType == other.runtimeType &&
          optionId == other.optionId;

  @override
  int get hashCode => optionId.hashCode;

  @override
  String toString() => 'McAnswer(optionId: $optionId)';
}

final class TfAnswer extends StudentAnswer {
  const TfAnswer(this.value);

  final bool value;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'value': value};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TfAnswer &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'TfAnswer(value: $value)';
}

final class FibAnswer extends StudentAnswer {
  const FibAnswer(this.value);

  final String value;

  @override
  Map<String, dynamic> toJson() {
    if (value.length > kMaxFibLength) {
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.invalidAnswer,
        statusCode: 422,
        serverMessage: 'FIB answer exceeds $kMaxFibLength characters.',
      );
    }
    return <String, dynamic>{'value': value};
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FibAnswer &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'FibAnswer(value: $value)';
}
