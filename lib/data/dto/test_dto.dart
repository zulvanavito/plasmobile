import 'package:plasmobile/data/dto/exercise_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';

class TestOverviewItemDto {
  const TestOverviewItemDto({
    required this.testId,
    required this.testType,
    required this.title,
    required this.questionCount,
    required this.status,
    this.activeAttemptId,
    this.score,
    required this.isEligible,
    required this.completedExercises,
    required this.totalExercises,
  });

  final String testId;
  final TestType testType;
  final String title;
  final int questionCount;
  final TestOverviewStatus status;
  final String? activeAttemptId;
  final double? score;
  final bool isEligible;
  final int completedExercises;
  final int totalExercises;

  factory TestOverviewItemDto.fromJson(Map<String, dynamic> json) {
    return TestOverviewItemDto(
      testId: json['test_id'] as String,
      testType: TestType.fromApi(json['test_type'] as String),
      title: json['title'] as String,
      questionCount: (json['question_count'] as num).toInt(),
      status: TestOverviewStatus.fromApi(json['status'] as String),
      activeAttemptId: json['active_attempt_id'] as String?,
      score: (json['score'] as num?)?.toDouble(),
      isEligible: json['is_eligible'] as bool,
      completedExercises: (json['completed_exercises'] as num).toInt(),
      totalExercises: (json['total_exercises'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'test_id': testId,
      'test_type': testType.apiValue,
      'title': title,
      'question_count': questionCount,
      'status': status.apiValue,
      'active_attempt_id': activeAttemptId,
      'score': score,
      'is_eligible': isEligible,
      'completed_exercises': completedExercises,
      'total_exercises': totalExercises,
    };
  }
}

class TestsOverviewDto {
  const TestsOverviewDto({
    required this.preTest,
    required this.postTest,
  });

  final TestOverviewItemDto preTest;
  final TestOverviewItemDto postTest;

  factory TestsOverviewDto.fromJson(Map<String, dynamic> json) {
    return TestsOverviewDto(
      preTest: TestOverviewItemDto.fromJson(
        Map<String, dynamic>.from(json['pre_test'] as Map),
      ),
      postTest: TestOverviewItemDto.fromJson(
        Map<String, dynamic>.from(json['post_test'] as Map),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'pre_test': preTest.toJson(),
      'post_test': postTest.toJson(),
    };
  }
}

class TestActiveQuestionDto {
  const TestActiveQuestionDto({
    required this.sequence,
    required this.totalQuestions,
    required this.questionText,
    required this.questionType,
    this.options = const <QuestionOptionDto>[],
    required this.questionStartedAt,
  });

  final int sequence;
  final int totalQuestions;
  final String questionText;
  final QuestionType questionType;
  final List<QuestionOptionDto> options;
  final DateTime questionStartedAt;

  factory TestActiveQuestionDto.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] as List<dynamic>? ?? const <dynamic>[];
    return TestActiveQuestionDto(
      sequence: (json['sequence'] as num).toInt(),
      totalQuestions: (json['total_questions'] as num).toInt(),
      questionText: json['question_text'] as String,
      questionType: QuestionType.fromApi(json['question_type'] as String),
      options: List<QuestionOptionDto>.unmodifiable(
        rawOptions.map(
          (item) => QuestionOptionDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
      questionStartedAt: DateTime.parse(json['question_started_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sequence': sequence,
      'total_questions': totalQuestions,
      'question_text': questionText,
      'question_type': questionType.apiValue,
      'options': options.map((item) => item.toJson()).toList(),
      'question_started_at': questionStartedAt.toIso8601String(),
    };
  }
}

class TestAttemptStartDto {
  const TestAttemptStartDto({
    required this.attemptId,
    required this.testId,
    required this.testType,
    required this.status,
    required this.totalQuestions,
    required this.currentSequence,
    required this.startedAt,
    this.firstQuestion,
  });

  final String attemptId;
  final String testId;
  final TestType testType;
  final AttemptStatus status;
  final int totalQuestions;
  final int currentSequence;
  final DateTime startedAt;
  final TestActiveQuestionDto? firstQuestion;

  factory TestAttemptStartDto.fromJson(Map<String, dynamic> json) {
    final rawFirstQuestion = json['first_question'];
    return TestAttemptStartDto(
      attemptId: json['attempt_id'] as String,
      testId: json['test_id'] as String,
      testType: TestType.fromApi(json['test_type'] as String),
      status: AttemptStatus.fromApi(json['status'] as String),
      totalQuestions: (json['total_questions'] as num).toInt(),
      currentSequence: (json['current_sequence'] as num).toInt(),
      startedAt: DateTime.parse(json['started_at'] as String),
      firstQuestion: rawFirstQuestion is Map
          ? TestActiveQuestionDto.fromJson(
              Map<String, dynamic>.from(rawFirstQuestion),
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attempt_id': attemptId,
      'test_id': testId,
      'test_type': testType.apiValue,
      'status': status.apiValue,
      'total_questions': totalQuestions,
      'current_sequence': currentSequence,
      'started_at': startedAt.toIso8601String(),
      'first_question': firstQuestion?.toJson(),
    };
  }
}

class TestAnswerAckDto {
  const TestAnswerAckDto({
    required this.attemptId,
    required this.sequence,
    required this.isRecorded,
    required this.answeredAt,
    this.nextSequence,
  });

  final String attemptId;
  final int sequence;
  final bool isRecorded;
  final DateTime answeredAt;
  final int? nextSequence;

  factory TestAnswerAckDto.fromJson(Map<String, dynamic> json) {
    return TestAnswerAckDto(
      attemptId: json['attempt_id'] as String,
      sequence: (json['sequence'] as num).toInt(),
      isRecorded: json['is_recorded'] as bool,
      answeredAt: DateTime.parse(json['answered_at'] as String),
      nextSequence: (json['next_sequence'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attempt_id': attemptId,
      'sequence': sequence,
      'is_recorded': isRecorded,
      'answered_at': answeredAt.toIso8601String(),
      'next_sequence': nextSequence,
    };
  }
}

class TestResultItemDto {
  const TestResultItemDto({
    required this.sequence,
    required this.questionText,
    required this.questionType,
    required this.isCorrect,
    required this.timeSpentSeconds,
  });

  final int sequence;
  final String questionText;
  final QuestionType questionType;
  final bool isCorrect;
  final int timeSpentSeconds;

  factory TestResultItemDto.fromJson(Map<String, dynamic> json) {
    return TestResultItemDto(
      sequence: (json['sequence'] as num).toInt(),
      questionText: json['question_text'] as String,
      questionType: QuestionType.fromApi(json['question_type'] as String),
      isCorrect: json['is_correct'] as bool,
      timeSpentSeconds: (json['time_spent_seconds'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'sequence': sequence,
      'question_text': questionText,
      'question_type': questionType.apiValue,
      'is_correct': isCorrect,
      'time_spent_seconds': timeSpentSeconds,
    };
  }
}

class TestAttemptResultDto {
  const TestAttemptResultDto({
    required this.attemptId,
    required this.testId,
    required this.testType,
    required this.status,
    required this.score,
    required this.totalDurationSeconds,
    required this.startedAt,
    required this.submittedAt,
    required this.items,
  });

  final String attemptId;
  final String testId;
  final TestType testType;
  final AttemptStatus status;
  final double score;
  final int totalDurationSeconds;
  final DateTime startedAt;
  final DateTime submittedAt;
  final List<TestResultItemDto> items;

  factory TestAttemptResultDto.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? const <dynamic>[];
    return TestAttemptResultDto(
      attemptId: json['attempt_id'] as String,
      testId: json['test_id'] as String,
      testType: TestType.fromApi(json['test_type'] as String),
      status: AttemptStatus.fromApi(json['status'] as String),
      score: (json['score'] as num).toDouble(),
      totalDurationSeconds: (json['total_duration_seconds'] as num).toInt(),
      startedAt: DateTime.parse(json['started_at'] as String),
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      items: List<TestResultItemDto>.unmodifiable(
        rawItems.map(
          (item) => TestResultItemDto.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'attempt_id': attemptId,
      'test_id': testId,
      'test_type': testType.apiValue,
      'status': status.apiValue,
      'score': score,
      'total_duration_seconds': totalDurationSeconds,
      'started_at': startedAt.toIso8601String(),
      'submitted_at': submittedAt.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}
