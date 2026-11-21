import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/data/dto/student_answer.dart';

class AiQuotaDto {
  const AiQuotaDto({
    required this.remainingQuota,
    required this.dailyLimit,
    required this.usageDate,
  });

  final int remainingQuota;
  final int dailyLimit;
  final String usageDate;

  factory AiQuotaDto.fromJson(Map<String, dynamic> json) {
    return AiQuotaDto(
      remainingQuota: (json['remaining_quota'] as num).toInt(),
      dailyLimit: (json['daily_limit'] as num).toInt(),
      usageDate: json['usage_date'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'remaining_quota': remainingQuota,
      'daily_limit': dailyLimit,
      'usage_date': usageDate,
    };
  }
}

class AiAskRequestDto {
  const AiAskRequestDto({
    required this.question,
    this.submaterialId,
    this.exerciseQuestionId,
    this.hintLevel = AiHintLevel.konsepDasar,
  });

  final String question;
  final String? submaterialId;
  final String? exerciseQuestionId;
  final AiHintLevel hintLevel;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'question': question,
      if (submaterialId != null) 'submaterial_id': submaterialId,
      if (exerciseQuestionId != null)
        'exercise_question_id': exerciseQuestionId,
      'hint_level': hintLevel.level,
    };
  }
}

enum AiAskStatus {
  success('success'),
  alreadyProcessed('already_processed');

  const AiAskStatus(this.apiValue);

  final String apiValue;

  static AiAskStatus fromApi(String raw) {
    for (final value in values) {
      if (value.apiValue == raw) return value;
    }
    throw PlasApiException.fromApiCode(
      ApiErrorCodes.validationError,
      statusCode: 400,
      serverMessage: 'Unknown AiAskStatus: $raw',
    );
  }
}

class AiAskResponseDto {
  const AiAskResponseDto({
    required this.status,
    this.answer,
    this.hintLevel,
    required this.remainingQuota,
  });

  final AiAskStatus status;
  final String? answer;
  final AiHintLevel? hintLevel;
  final int remainingQuota;

  factory AiAskResponseDto.fromJson(Map<String, dynamic> json) {
    final rawHintLevel = json['hint_level'];
    return AiAskResponseDto(
      status: AiAskStatus.fromApi(json['status'] as String),
      answer: json['answer'] as String?,
      hintLevel: rawHintLevel is num
          ? AiHintLevel.fromValue(rawHintLevel.toInt())
          : null,
      remainingQuota: (json['remaining_quota'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'status': status.apiValue,
      'answer': answer,
      'hint_level': hintLevel?.level,
      'remaining_quota': remainingQuota,
    };
  }
}
