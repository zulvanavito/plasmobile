import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';

class ActivityItemDto {
  const ActivityItemDto({
    required this.attemptId,
    required this.exerciseId,
    required this.materialTitle,
    required this.submaterialTitle,
    required this.questionType,
    required this.attemptNumber,
    required this.status,
    this.score,
    required this.createdAt,
    this.submittedAt,
  });

  final String attemptId;
  final String exerciseId;
  final String materialTitle;
  final String submaterialTitle;
  final QuestionType questionType;
  final int attemptNumber;
  final AttemptStatus status;
  final double? score;
  final DateTime createdAt;
  final DateTime? submittedAt;

  factory ActivityItemDto.fromJson(Map<String, dynamic> json) {
    final rawSubmittedAt = json['submitted_at'] as String?;
    return ActivityItemDto(
      attemptId: json['attempt_id'] as String,
      exerciseId: json['exercise_id'] as String,
      materialTitle: json['material_title'] as String,
      submaterialTitle: json['submaterial_title'] as String,
      questionType: QuestionType.fromApi(json['question_type'] as String),
      attemptNumber: (json['attempt_number'] as num).toInt(),
      status: AttemptStatus.fromApi(json['status'] as String),
      score: (json['score'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      submittedAt:
          rawSubmittedAt != null ? DateTime.parse(rawSubmittedAt) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attempt_id': attemptId,
      'exercise_id': exerciseId,
      'material_title': materialTitle,
      'submaterial_title': submaterialTitle,
      'question_type': questionType.apiValue,
      'attempt_number': attemptNumber,
      'status': status.apiValue,
      'score': score,
      'created_at': createdAt.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
    };
  }
}

class ProgressSummaryDto {
  const ProgressSummaryDto({
    required this.completedMaterials,
    required this.totalMaterials,
    required this.completedExercises,
    required this.totalExercises,
    required this.preTestStatus,
    this.preTestScore,
    required this.postTestStatus,
    this.postTestScore,
    required this.isPostTestEligible,
    required this.aiQuota,
  });

  final int completedMaterials;
  final int totalMaterials;
  final int completedExercises;
  final int totalExercises;
  final TestOverviewStatus preTestStatus;
  final double? preTestScore;
  final TestOverviewStatus postTestStatus;
  final double? postTestScore;
  final bool isPostTestEligible;
  final AiQuotaDto aiQuota;

  factory ProgressSummaryDto.fromJson(Map<String, dynamic> json) {
    return ProgressSummaryDto(
      completedMaterials: (json['completed_materials'] as num).toInt(),
      totalMaterials: (json['total_materials'] as num).toInt(),
      completedExercises: (json['completed_exercises'] as num).toInt(),
      totalExercises: (json['total_exercises'] as num).toInt(),
      preTestStatus:
          TestOverviewStatus.fromApi(json['pre_test_status'] as String),
      preTestScore: (json['pre_test_score'] as num?)?.toDouble(),
      postTestStatus:
          TestOverviewStatus.fromApi(json['post_test_status'] as String),
      postTestScore: (json['post_test_score'] as num?)?.toDouble(),
      isPostTestEligible: json['is_post_test_eligible'] as bool,
      aiQuota: AiQuotaDto.fromJson(
        Map<String, dynamic>.from(json['ai_quota'] as Map),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'completed_materials': completedMaterials,
      'total_materials': totalMaterials,
      'completed_exercises': completedExercises,
      'total_exercises': totalExercises,
      'pre_test_status': preTestStatus.apiValue,
      'pre_test_score': preTestScore,
      'post_test_status': postTestStatus.apiValue,
      'post_test_score': postTestScore,
      'is_post_test_eligible': isPostTestEligible,
      'ai_quota': aiQuota.toJson(),
    };
  }
}
