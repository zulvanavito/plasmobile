import 'package:plasmobile/data/dto/student_answer.dart';

class MaterialSummaryDto {
  const MaterialSummaryDto({
    required this.materialId,
    required this.sequence,
    required this.title,
    required this.description,
    required this.submaterialCount,
    required this.completedExercises,
  });

  final String materialId;
  final int sequence;
  final String title;
  final String description;
  final int submaterialCount;
  final int completedExercises;

  factory MaterialSummaryDto.fromJson(Map<String, dynamic> json) {
    return MaterialSummaryDto(
      materialId: json['material_id'] as String,
      sequence: (json['sequence'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String,
      submaterialCount: (json['submaterial_count'] as num).toInt(),
      completedExercises: (json['completed_exercises'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'material_id': materialId,
      'sequence': sequence,
      'title': title,
      'description': description,
      'submaterial_count': submaterialCount,
      'completed_exercises': completedExercises,
    };
  }
}

class SubMaterialSummaryDto {
  const SubMaterialSummaryDto({
    required this.submaterialId,
    required this.sequence,
    required this.title,
    required this.hasSubmittedExercise,
    required this.attemptsUsed,
    this.maxAttempts = 3,
  });

  final String submaterialId;
  final int sequence;
  final String title;
  final bool hasSubmittedExercise;
  final int attemptsUsed;
  final int maxAttempts;

  factory SubMaterialSummaryDto.fromJson(Map<String, dynamic> json) {
    return SubMaterialSummaryDto(
      submaterialId: json['submaterial_id'] as String,
      sequence: (json['sequence'] as num).toInt(),
      title: json['title'] as String,
      hasSubmittedExercise: json['has_submitted_exercise'] as bool,
      attemptsUsed: (json['attempts_used'] as num).toInt(),
      maxAttempts: (json['max_attempts'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'submaterial_id': submaterialId,
      'sequence': sequence,
      'title': title,
      'has_submitted_exercise': hasSubmittedExercise,
      'attempts_used': attemptsUsed,
      'max_attempts': maxAttempts,
    };
  }
}

class MaterialDetailDto {
  const MaterialDetailDto({
    required this.materialId,
    required this.sequence,
    required this.title,
    required this.description,
    required this.submaterials,
  });

  final String materialId;
  final int sequence;
  final String title;
  final String description;
  final List<SubMaterialSummaryDto> submaterials;

  factory MaterialDetailDto.fromJson(Map<String, dynamic> json) {
    final rawList = json['submaterials'] as List<dynamic>? ?? const <dynamic>[];
    return MaterialDetailDto(
      materialId: json['material_id'] as String,
      sequence: (json['sequence'] as num).toInt(),
      title: json['title'] as String,
      description: json['description'] as String,
      submaterials: List<SubMaterialSummaryDto>.unmodifiable(
        rawList.map(
          (item) => SubMaterialSummaryDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'material_id': materialId,
      'sequence': sequence,
      'title': title,
      'description': description,
      'submaterials': submaterials.map((item) => item.toJson()).toList(),
    };
  }
}

class ExerciseOverviewDto {
  const ExerciseOverviewDto({
    required this.exerciseId,
    required this.title,
    required this.questionType,
    this.latestAttemptStatus,
    required this.attemptsUsed,
    required this.remainingAttempts,
    this.maxAttempts = 3,
    this.bestScore,
  });

  final String exerciseId;
  final String title;
  final QuestionType questionType;
  final AttemptStatus? latestAttemptStatus;
  final int attemptsUsed;
  final int remainingAttempts;
  final int maxAttempts;
  final double? bestScore;

  factory ExerciseOverviewDto.fromJson(Map<String, dynamic> json) {
    final rawLatestStatus = json['latest_attempt_status'] as String?;
    return ExerciseOverviewDto(
      exerciseId: json['exercise_id'] as String,
      title: json['title'] as String,
      questionType: QuestionType.fromApi(json['question_type'] as String),
      latestAttemptStatus: rawLatestStatus != null
          ? AttemptStatus.fromApi(rawLatestStatus)
          : null,
      attemptsUsed: (json['attempts_used'] as num).toInt(),
      remainingAttempts: (json['remaining_attempts'] as num).toInt(),
      maxAttempts: (json['max_attempts'] as num?)?.toInt() ?? 3,
      bestScore: (json['best_score'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'exercise_id': exerciseId,
      'title': title,
      'question_type': questionType.apiValue,
      'latest_attempt_status': latestAttemptStatus?.apiValue,
      'attempts_used': attemptsUsed,
      'remaining_attempts': remainingAttempts,
      'max_attempts': maxAttempts,
      'best_score': bestScore,
    };
  }
}

class SubMaterialDetailDto {
  const SubMaterialDetailDto({
    required this.submaterialId,
    required this.materialId,
    required this.sequence,
    required this.title,
    required this.contentMarkdown,
    required this.exercise,
  });

  final String submaterialId;
  final String materialId;
  final int sequence;
  final String title;
  final String contentMarkdown;
  final ExerciseOverviewDto exercise;

  factory SubMaterialDetailDto.fromJson(Map<String, dynamic> json) {
    return SubMaterialDetailDto(
      submaterialId: json['submaterial_id'] as String,
      materialId: json['material_id'] as String,
      sequence: (json['sequence'] as num).toInt(),
      title: json['title'] as String,
      contentMarkdown: json['content_markdown'] as String,
      exercise: ExerciseOverviewDto.fromJson(
        Map<String, dynamic>.from(json['exercise'] as Map),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'submaterial_id': submaterialId,
      'material_id': materialId,
      'sequence': sequence,
      'title': title,
      'content_markdown': contentMarkdown,
      'exercise': exercise.toJson(),
    };
  }
}
