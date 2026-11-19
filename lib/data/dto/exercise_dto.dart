import 'package:plasmobile/data/dto/student_answer.dart';

class QuestionOptionDto {
  const QuestionOptionDto({
    required this.optionId,
    required this.text,
    required this.sequence,
  });

  final String optionId;
  final String text;
  final int sequence;

  factory QuestionOptionDto.fromJson(Map<String, dynamic> json) {
    return QuestionOptionDto(
      optionId: json['option_id'] as String,
      text: json['text'] as String,
      sequence: (json['sequence'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'option_id': optionId,
      'text': text,
      'sequence': sequence,
    };
  }
}

class ExerciseQuestionDto {
  const ExerciseQuestionDto({
    required this.questionId,
    required this.sequence,
    required this.questionText,
    required this.questionType,
    this.hint,
    this.options = const <QuestionOptionDto>[],
  });

  final String questionId;
  final int sequence;
  final String questionText;
  final QuestionType questionType;
  final String? hint;
  final List<QuestionOptionDto> options;

  factory ExerciseQuestionDto.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? const <dynamic>[];
    return ExerciseQuestionDto(
      questionId: json['question_id'] as String,
      sequence: (json['sequence'] as num).toInt(),
      questionText: json['question_text'] as String,
      questionType: QuestionType.fromApi(json['question_type'] as String),
      hint: json['hint'] as String?,
      options: List<QuestionOptionDto>.unmodifiable(
        rawOptions.map(
          (item) => QuestionOptionDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'question_id': questionId,
      'sequence': sequence,
      'question_text': questionText,
      'question_type': questionType.apiValue,
      'hint': hint,
      'options': options.map((item) => item.toJson()).toList(),
    };
  }
}

class ExerciseDetailDto {
  const ExerciseDetailDto({
    required this.exerciseId,
    required this.submaterialId,
    required this.title,
    required this.questionType,
    this.questions = const <ExerciseQuestionDto>[],
  });

  final String exerciseId;
  final String submaterialId;
  final String title;
  final QuestionType questionType;
  final List<ExerciseQuestionDto> questions;

  factory ExerciseDetailDto.fromJson(Map<String, dynamic> json) {
    final rawQuestions =
        json['questions'] as List<dynamic>? ?? const <dynamic>[];
    return ExerciseDetailDto(
      exerciseId: json['exercise_id'] as String,
      submaterialId: json['submaterial_id'] as String,
      title: json['title'] as String,
      questionType: QuestionType.fromApi(json['question_type'] as String),
      questions: List<ExerciseQuestionDto>.unmodifiable(
        rawQuestions.map(
          (item) => ExerciseQuestionDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'exercise_id': exerciseId,
      'submaterial_id': submaterialId,
      'title': title,
      'question_type': questionType.apiValue,
      'questions': questions.map((item) => item.toJson()).toList(),
    };
  }
}

class ExerciseAttemptDto {
  const ExerciseAttemptDto({
    required this.attemptId,
    required this.exerciseId,
    required this.attemptNumber,
    required this.status,
    this.score,
    required this.startedAt,
    this.submittedAt,
    this.questions = const <ExerciseQuestionDto>[],
  });

  final String attemptId;
  final String exerciseId;
  final int attemptNumber;
  final AttemptStatus status;
  final double? score;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final List<ExerciseQuestionDto> questions;

  factory ExerciseAttemptDto.fromJson(Map<String, dynamic> json) {
    final rawQuestions =
        json['questions'] as List<dynamic>? ?? const <dynamic>[];
    final rawSubmittedAt = json['submitted_at'] as String?;
    return ExerciseAttemptDto(
      attemptId: json['attempt_id'] as String,
      exerciseId: json['exercise_id'] as String,
      attemptNumber: (json['attempt_number'] as num).toInt(),
      status: AttemptStatus.fromApi(json['status'] as String),
      score: (json['score'] as num?)?.toDouble(),
      startedAt: DateTime.parse(json['started_at'] as String),
      submittedAt:
          rawSubmittedAt != null ? DateTime.parse(rawSubmittedAt) : null,
      questions: List<ExerciseQuestionDto>.unmodifiable(
        rawQuestions.map(
          (item) => ExerciseQuestionDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attempt_id': attemptId,
      'exercise_id': exerciseId,
      'attempt_number': attemptNumber,
      'status': status.apiValue,
      'score': score,
      'started_at': startedAt.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'questions': questions.map((item) => item.toJson()).toList(),
    };
  }
}

class ExerciseAnswerResponseDto {
  const ExerciseAnswerResponseDto({
    required this.attemptId,
    required this.questionId,
    required this.isCorrect,
    this.explanation,
    this.hint,
    required this.answeredAt,
  });

  final String attemptId;
  final String questionId;
  final bool isCorrect;
  final String? explanation;
  final String? hint;
  final DateTime answeredAt;

  factory ExerciseAnswerResponseDto.fromJson(Map<String, dynamic> json) {
    return ExerciseAnswerResponseDto(
      attemptId: json['attempt_id'] as String,
      questionId: json['question_id'] as String,
      isCorrect: json['is_correct'] as bool,
      explanation: json['explanation'] as String?,
      hint: json['hint'] as String?,
      answeredAt: DateTime.parse(json['answered_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attempt_id': attemptId,
      'question_id': questionId,
      'is_correct': isCorrect,
      'explanation': explanation,
      'hint': hint,
      'answered_at': answeredAt.toIso8601String(),
    };
  }
}

class ExerciseReviewItemDto {
  const ExerciseReviewItemDto({
    required this.questionId,
    required this.sequence,
    required this.questionText,
    required this.questionType,
    this.options = const <QuestionOptionDto>[],
    this.studentAnswer,
    this.isCorrect,
    this.explanation,
    this.hint,
    required this.timeSpentSeconds,
  });

  final String questionId;
  final int sequence;
  final String questionText;
  final QuestionType questionType;
  final List<QuestionOptionDto> options;
  final StudentAnswer? studentAnswer;
  final bool? isCorrect;
  final String? explanation;
  final String? hint;
  final int timeSpentSeconds;

  factory ExerciseReviewItemDto.fromJson(Map<String, dynamic> json) {
    final questionType = QuestionType.fromApi(json['question_type'] as String);
    final rawOptions = json['options'] as List<dynamic>? ?? const <dynamic>[];
    final rawStudentAnswer = json['student_answer'];

    return ExerciseReviewItemDto(
      questionId: json['question_id'] as String,
      sequence: (json['sequence'] as num).toInt(),
      questionText: json['question_text'] as String,
      questionType: questionType,
      options: List<QuestionOptionDto>.unmodifiable(
        rawOptions.map(
          (item) => QuestionOptionDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      studentAnswer: rawStudentAnswer is Map
          ? StudentAnswer.fromJson(
              questionType,
              Map<String, dynamic>.from(rawStudentAnswer),
            )
          : null,
      isCorrect: json['is_correct'] as bool?,
      explanation: json['explanation'] as String?,
      hint: json['hint'] as String?,
      timeSpentSeconds: (json['time_spent_seconds'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'question_id': questionId,
      'sequence': sequence,
      'question_text': questionText,
      'question_type': questionType.apiValue,
      'options': options.map((item) => item.toJson()).toList(),
      'student_answer': studentAnswer?.toJson(),
      'is_correct': isCorrect,
      'explanation': explanation,
      'hint': hint,
      'time_spent_seconds': timeSpentSeconds,
    };
  }
}

class ExerciseAttemptDetailDto {
  const ExerciseAttemptDetailDto({
    required this.attemptId,
    required this.exerciseId,
    required this.exerciseTitle,
    required this.attemptNumber,
    required this.status,
    this.score,
    required this.startedAt,
    this.submittedAt,
    required this.items,
  });

  final String attemptId;
  final String exerciseId;
  final String exerciseTitle;
  final int attemptNumber;
  final AttemptStatus status;
  final double? score;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final List<ExerciseReviewItemDto> items;

  factory ExerciseAttemptDetailDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const <dynamic>[];
    final rawSubmittedAt = json['submitted_at'] as String?;
    return ExerciseAttemptDetailDto(
      attemptId: json['attempt_id'] as String,
      exerciseId: json['exercise_id'] as String,
      exerciseTitle: json['exercise_title'] as String,
      attemptNumber: (json['attempt_number'] as num).toInt(),
      status: AttemptStatus.fromApi(json['status'] as String),
      score: (json['score'] as num?)?.toDouble(),
      startedAt: DateTime.parse(json['started_at'] as String),
      submittedAt:
          rawSubmittedAt != null ? DateTime.parse(rawSubmittedAt) : null,
      items: List<ExerciseReviewItemDto>.unmodifiable(
        rawItems.map(
          (item) => ExerciseReviewItemDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attempt_id': attemptId,
      'exercise_id': exerciseId,
      'exercise_title': exerciseTitle,
      'attempt_number': attemptNumber,
      'status': status.apiValue,
      'score': score,
      'started_at': startedAt.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
