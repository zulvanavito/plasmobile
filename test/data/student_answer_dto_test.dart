import 'package:flutter_test/flutter_test.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/utils/levenshtein.dart';
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/exercise_dto.dart';
import 'package:plasmobile/data/dto/material_dto.dart';
import 'package:plasmobile/data/dto/progress_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/dto/test_dto.dart';

Matcher _throwsInvalidAnswer() => throwsA(
      isA<PlasApiException>()
          .having((e) => e.code, 'code', ApiErrorCodes.invalidAnswer)
          .having((e) => e.statusCode, 'statusCode', 422),
    );

void main() {
  group('StudentAnswer P6 canonical payloads & validation', () {
    test('McAnswer, TfAnswer, FibAnswer emit strictly 1 canonical key', () {
      final mc = const McAnswer('opt-1').toJson();
      expect(mc, <String, dynamic>{'option_id': 'opt-1'});
      expect(mc.containsKey('type'), isFalse);

      final tf = const TfAnswer(true).toJson();
      expect(tf, <String, dynamic>{'value': true});
      expect(tf.containsKey('type'), isFalse);

      final fib = const FibAnswer('const').toJson();
      expect(fib, <String, dynamic>{'value': 'const'});
      expect(fib.containsKey('type'), isFalse);
    });

    test('rejects extra keys, empty option_id, wrong types, and >255 FIB', () {
      expect(
        () => StudentAnswer.fromJson(
          QuestionType.mc,
          <String, dynamic>{'type': 'MC', 'option_id': 'opt-1'},
        ),
        _throwsInvalidAnswer(),
      );
      expect(
        () => StudentAnswer.fromJson(
          QuestionType.mc,
          <String, dynamic>{'option_id': '   '},
        ),
        _throwsInvalidAnswer(),
      );
      expect(
        () => const McAnswer('').toJson(),
        _throwsInvalidAnswer(),
      );
      expect(
        () => StudentAnswer.fromJson(
          QuestionType.tf,
          <String, dynamic>{'value': 'true'},
        ),
        _throwsInvalidAnswer(),
      );
      expect(
        () => StudentAnswer.fromJson(
          QuestionType.fib,
          <String, dynamic>{'value': 123},
        ),
        _throwsInvalidAnswer(),
      );

      final maxValid = 'a' * kMaxFibLength;
      final parsedValid = StudentAnswer.fromJson(
        QuestionType.fib,
        <String, dynamic>{'value': maxValid},
      );
      expect(parsedValid, FibAnswer(maxValid));
      expect(parsedValid.toJson(), <String, dynamic>{'value': maxValid});

      final tooLong = 'a' * (kMaxFibLength + 1);
      expect(
        () => StudentAnswer.fromJson(
          QuestionType.fib,
          <String, dynamic>{'value': tooLong},
        ),
        _throwsInvalidAnswer(),
      );
      expect(
        () => FibAnswer(tooLong).toJson(),
        _throwsInvalidAnswer(),
      );
    });

    test('enum parsing rejects unknown values including EXPIRED', () {
      expect(
        () => AttemptStatus.fromApi('EXPIRED'),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.validationError)
              .having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
      expect(
        () => QuestionType.fromApi('ESSAY'),
        throwsA(isA<PlasApiException>()),
      );
      expect(
        () => AiHintLevel.fromValue(99),
        throwsA(isA<PlasApiException>()),
      );
    });
  });

  group('DTO round-trips & P13 safety', () {
    test('StudentProfileDto & CreateProfileRequest round-trip', () {
      final profileJson = <String, dynamic>{
        'mahasiswa_id': 'mhs-1',
        'nama': 'Budi Santoso',
        'nim': '220101001',
        'kelas': <String, dynamic>{
          'kelas_id': 'kls-1',
          'nama': 'TI-2A',
          'kode': 'TS-2026-A',
          'tahun_akademik': '2025/2026',
          'semester': 'Genap',
          'dosen_nama': 'Dr. Sinta',
        },
        'pre_test_submitted': true,
        'remaining_ai_quota': 8,
      };

      final dto = StudentProfileDto.fromJson(profileJson);
      expect(dto.toJson(), profileJson);

      final updated = dto.copyWith(clearKelas: true, remainingAiQuota: 7);
      expect(updated.kelas, isNull);
      expect(updated.remainingAiQuota, 7);

      const req = CreateProfileRequest(
        nama: 'Budi Santoso',
        nim: '220101001',
        kelasId: 'kls-1',
      );
      expect(req.toJson(), <String, dynamic>{
        'nama': 'Budi Santoso',
        'nim': '220101001',
        'kelas_id': 'kls-1',
      });
    });

    test('MaterialDetailDto & SubMaterialDetailDto round-trip', () {
      final materialJson = <String, dynamic>{
        'material_id': 'mat-1',
        'sequence': 1,
        'title': 'Dasar TypeScript',
        'description': 'Variabel dan tipe primitif.',
        'submaterials': <Map<String, dynamic>>[
          <String, dynamic>{
            'submaterial_id': 'sub-1',
            'sequence': 1,
            'title': 'let dan const',
            'has_submitted_exercise': true,
            'attempts_used': 1,
            'max_attempts': 3,
          },
        ],
      };
      final material = MaterialDetailDto.fromJson(materialJson);
      expect(material.toJson(), materialJson);

      final subMaterialJson = <String, dynamic>{
        'submaterial_id': 'sub-1',
        'material_id': 'mat-1',
        'sequence': 1,
        'title': 'let dan const',
        'content_markdown': '# Materi\nGunakan `const`.',
        'exercise': <String, dynamic>{
          'exercise_id': 'ex-1',
          'title': 'Latihan let dan const',
          'question_type': 'MC',
          'latest_attempt_status': 'SUBMITTED',
          'attempts_used': 1,
          'remaining_attempts': 2,
          'max_attempts': 3,
          'best_score': 100.0,
        },
      };
      final subMaterial = SubMaterialDetailDto.fromJson(subMaterialJson);
      expect(subMaterial.toJson(), subMaterialJson);
    });

    test('Exercise DTOs round-trip cleanly', () {
      final attemptJson = <String, dynamic>{
        'attempt_id': 'att-1',
        'exercise_id': 'ex-1',
        'attempt_number': 1,
        'status': 'IN_PROGRESS',
        'score': null,
        'started_at': '2026-11-19T10:00:00.000Z',
        'submitted_at': null,
        'questions': <Map<String, dynamic>>[
          <String, dynamic>{
            'question_id': 'q-1',
            'sequence': 1,
            'question_text': 'Keyword untuk konstanta?',
            'question_type': 'MC',
            'hint': 'Dimulai huruf c',
            'options': <Map<String, dynamic>>[
              <String, dynamic>{
                'option_id': 'opt-1',
                'text': 'const',
                'sequence': 1,
              },
            ],
          },
        ],
      };
      final attempt = ExerciseAttemptDto.fromJson(attemptJson);
      expect(attempt.toJson(), attemptJson);

      final answerRespJson = <String, dynamic>{
        'attempt_id': 'att-1',
        'question_id': 'q-1',
        'is_correct': true,
        'explanation': 'const mendefinisikan binding tetap.',
        'hint': null,
        'answered_at': '2026-11-19T10:01:00.000Z',
      };
      final answerResp = ExerciseAnswerResponseDto.fromJson(answerRespJson);
      expect(answerResp.toJson(), answerRespJson);

      final detailJson = <String, dynamic>{
        'attempt_id': 'att-1',
        'exercise_id': 'ex-1',
        'exercise_title': 'Latihan 1',
        'attempt_number': 1,
        'status': 'SUBMITTED',
        'score': 100.0,
        'started_at': '2026-11-19T10:00:00.000Z',
        'submitted_at': '2026-11-19T10:05:00.000Z',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'question_id': 'q-1',
            'sequence': 1,
            'question_text': 'Keyword untuk konstanta?',
            'question_type': 'MC',
            'options': <Map<String, dynamic>>[
              <String, dynamic>{
                'option_id': 'opt-1',
                'text': 'const',
                'sequence': 1,
              },
            ],
            'student_answer': <String, dynamic>{'option_id': 'opt-1'},
            'is_correct': true,
            'explanation': 'const tidak bisa direassign.',
            'hint': 'Perhatikan immutability.',
            'time_spent_seconds': 24,
          },
        ],
      };
      final detail = ExerciseAttemptDetailDto.fromJson(detailJson);
      expect(detail.toJson(), detailJson);
    });

    test('Test DTOs round-trip cleanly', () {
      final overviewJson = <String, dynamic>{
        'pre_test': <String, dynamic>{
          'test_id': 'test-pre',
          'test_type': 'PRE',
          'title': 'Pre-test TypeScript',
          'question_count': 15,
          'status': 'SUBMITTED',
          'active_attempt_id': null,
          'score': 73.3,
          'is_eligible': true,
          'completed_exercises': 10,
          'total_exercises': 21,
        },
        'post_test': <String, dynamic>{
          'test_id': 'test-post',
          'test_type': 'POST',
          'title': 'Post-test TypeScript',
          'question_count': 15,
          'status': 'NOT_STARTED',
          'active_attempt_id': null,
          'score': null,
          'is_eligible': false,
          'completed_exercises': 10,
          'total_exercises': 21,
        },
      };
      final overview = TestsOverviewDto.fromJson(overviewJson);
      expect(overview.toJson(), overviewJson);

      final startJson = <String, dynamic>{
        'attempt_id': 'tatt-1',
        'test_id': 'test-pre',
        'test_type': 'PRE',
        'status': 'IN_PROGRESS',
        'total_questions': 15,
        'current_sequence': 1,
        'started_at': '2026-11-19T10:10:00.000Z',
        'first_question': <String, dynamic>{
          'sequence': 1,
          'total_questions': 15,
          'question_text': 'TypeScript bersifat statically typed.',
          'question_type': 'TF',
          'options': <Map<String, dynamic>>[],
          'question_started_at': '2026-11-19T10:10:00.000Z',
        },
      };
      final start = TestAttemptStartDto.fromJson(startJson);
      expect(start.toJson(), startJson);

      final ackJson = <String, dynamic>{
        'attempt_id': 'tatt-1',
        'sequence': 1,
        'is_recorded': true,
        'answered_at': '2026-11-19T10:10:30.000Z',
        'next_sequence': 2,
      };
      final ack = TestAnswerAckDto.fromJson(ackJson);
      expect(ack.toJson(), ackJson);

      final resultJson = <String, dynamic>{
        'attempt_id': 'tatt-1',
        'test_id': 'test-pre',
        'test_type': 'PRE',
        'status': 'SUBMITTED',
        'score': 80.0,
        'total_duration_seconds': 320,
        'started_at': '2026-11-19T10:10:00.000Z',
        'submitted_at': '2026-11-19T10:15:20.000Z',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'sequence': 1,
            'question_text': 'TypeScript bersifat statically typed.',
            'question_type': 'TF',
            'is_correct': true,
            'time_spent_seconds': 30,
          },
        ],
      };
      final result = TestAttemptResultDto.fromJson(resultJson);
      expect(result.toJson(), resultJson);
    });

    test('AI and Progress DTOs round-trip including already_processed', () {
      final quotaJson = <String, dynamic>{
        'remaining_quota': 9,
        'daily_limit': 10,
        'usage_date': '2026-11-19',
      };
      final quota = AiQuotaDto.fromJson(quotaJson);
      expect(quota.toJson(), quotaJson);

      const askReq = AiAskRequestDto(
        question: 'Apa beda let dan const?',
        submaterialId: 'sub-1',
        hintLevel: AiHintLevel.strategi,
      );
      expect(askReq.toJson(), <String, dynamic>{
        'question': 'Apa beda let dan const?',
        'submaterial_id': 'sub-1',
        'hint_level': 2,
      });

      final successJson = <String, dynamic>{
        'status': 'success',
        'answer': 'Gunakan const jika nilai tidak direassign.',
        'hint_level': 1,
        'remaining_quota': 9,
      };
      final successResp = AiAskResponseDto.fromJson(successJson);
      expect(successResp.toJson(), successJson);

      final duplicateJson = <String, dynamic>{
        'status': 'already_processed',
        'answer': null,
        'hint_level': null,
        'remaining_quota': 9,
      };
      final duplicateResp = AiAskResponseDto.fromJson(duplicateJson);
      expect(duplicateResp.status, AiAskStatus.alreadyProcessed);
      expect(duplicateResp.answer, isNull);
      expect(duplicateResp.hintLevel, isNull);
      expect(duplicateResp.toJson(), duplicateJson);

      final activityJson = <String, dynamic>{
        'attempt_id': 'att-1',
        'exercise_id': 'ex-1',
        'material_title': 'Dasar TypeScript',
        'submaterial_title': 'let dan const',
        'question_type': 'MC',
        'attempt_number': 1,
        'status': 'SUBMITTED',
        'score': 100.0,
        'created_at': '2026-11-19T10:00:00.000Z',
        'submitted_at': '2026-11-19T10:05:00.000Z',
      };
      final activity = ActivityItemDto.fromJson(activityJson);
      expect(activity.toJson(), activityJson);

      final progressJson = <String, dynamic>{
        'completed_materials': 2,
        'total_materials': 7,
        'completed_exercises': 6,
        'total_exercises': 21,
        'pre_test_status': 'SUBMITTED',
        'pre_test_score': 75.0,
        'post_test_status': 'NOT_STARTED',
        'post_test_score': null,
        'is_post_test_eligible': false,
        'ai_quota': quotaJson,
      };
      final progress = ProgressSummaryDto.fromJson(progressJson);
      expect(progress.toJson(), progressJson);
    });

    test('P13 safety: student DTOs omit all answer-key & restricted fields', () {
      const forbiddenAnswerKeyFields = <String>[
        'correct_option_id',
        'correct_boolean',
        'correct_text',
        'correct_answer',
        'correct_answer_snapshot',
      ];

      final optionMap = const QuestionOptionDto(
        optionId: 'opt-1',
        text: 'const',
        sequence: 1,
      ).toJson();
      final exerciseQuestionMap = const ExerciseQuestionDto(
        questionId: 'q-1',
        sequence: 1,
        questionText: 'Pertanyaan',
        questionType: QuestionType.mc,
        options: <QuestionOptionDto>[
          QuestionOptionDto(optionId: 'opt-1', text: 'const', sequence: 1),
        ],
      ).toJson();
      final activeTestQuestionMap = TestActiveQuestionDto(
        sequence: 1,
        totalQuestions: 15,
        questionText: 'Pertanyaan tes',
        questionType: QuestionType.tf,
        questionStartedAt: DateTime.utc(2026, 11, 19),
      ).toJson();
      final testResultItemMap = const TestResultItemDto(
        sequence: 1,
        questionText: 'Pertanyaan tes',
        questionType: QuestionType.tf,
        isCorrect: true,
        timeSpentSeconds: 12,
      ).toJson();
      final reviewItemMap = const ExerciseReviewItemDto(
        questionId: 'q-1',
        sequence: 1,
        questionText: 'Pertanyaan',
        questionType: QuestionType.fib,
        studentAnswer: FibAnswer('const'),
        isCorrect: true,
        explanation: 'Benar',
        timeSpentSeconds: 15,
      ).toJson();

      for (final map in <Map<String, dynamic>>[
        optionMap,
        exerciseQuestionMap,
        activeTestQuestionMap,
        testResultItemMap,
        reviewItemMap,
      ]) {
        for (final key in forbiddenAnswerKeyFields) {
          expect(map.containsKey(key), isFalse, reason: 'Found $key');
        }
      }

      expect(optionMap.containsKey('is_correct'), isFalse);
      expect(exerciseQuestionMap.containsKey('explanation'), isFalse);
      expect(activeTestQuestionMap.containsKey('explanation'), isFalse);
      expect(testResultItemMap.containsKey('explanation'), isFalse);
    });
  });
}
