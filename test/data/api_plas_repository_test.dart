import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/network/dio_client.dart';
import 'package:plasmobile/core/network/idempotency_interceptor.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/repositories/api_plas_repository.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';

class _FakeHttpAdapter implements HttpClientAdapter {
  _FakeHttpAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> capturedRequests = [];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    capturedRequests.add(options);
    return handler(options);
  }
}

ResponseBody _jsonResponse(int statusCode, Object? body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: const {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

({PlasRepository repo, _FakeHttpAdapter adapter}) _buildRepo(
  Future<ResponseBody> Function(RequestOptions options) handler,
) {
  final adapter = _FakeHttpAdapter(handler);
  final dio = createPlasDio(
    baseUrl: 'https://api.plas.test/api',
    getAccessToken: () async => 'test-jwt',
    httpClientAdapter: adapter,
  );
  return (repo: ApiPlasRepository(dio: dio), adapter: adapter);
}

Map<String, dynamic> _sampleProfileJson({Map<String, dynamic>? kelas}) {
  return <String, dynamic>{
    'mahasiswa_id': 'mhs-01',
    'nama': 'Budi Santoso',
    'nim': '220101001',
    'kelas': kelas,
    'pre_test_submitted': false,
    'remaining_ai_quota': 10,
  };
}

Map<String, dynamic> _sampleClassJson() {
  return <String, dynamic>{
    'kelas_id': 'kls-01',
    'nama': 'TI-2A',
    'kode': 'TS-2026-A',
    'tahun_akademik': '2025/2026',
    'semester': 'Genap',
    'dosen_nama': 'Dr. Sinta',
  };
}

Map<String, dynamic> _sampleAttemptJson({String status = 'IN_PROGRESS'}) {
  return <String, dynamic>{
    'attempt_id': 'att-1',
    'exercise_id': 'ex-01',
    'attempt_number': 1,
    'status': status,
    'score': status == 'SUBMITTED' ? 100.0 : null,
    'started_at': '2026-11-19T10:00:00.000Z',
    'submitted_at':
        status == 'SUBMITTED' ? '2026-11-19T10:05:00.000Z' : null,
    'questions': <Map<String, dynamic>>[
      <String, dynamic>{
        'question_id': 'q-1',
        'sequence': 1,
        'question_text': 'Keyword untuk nilai tetap?',
        'question_type': 'MC',
        'hint': 'Gunakan c...',
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
}

Map<String, dynamic> _sampleActiveQuestionJson({int sequence = 1}) {
  return <String, dynamic>{
    'sequence': sequence,
    'total_questions': 15,
    'question_text': 'TypeScript bersifat statically typed.',
    'question_type': 'TF',
    'options': const <Map<String, dynamic>>[],
    'question_started_at': '2026-11-19T10:10:00.000Z',
  };
}

Map<String, dynamic> _sampleTestResultJson() {
  return <String, dynamic>{
    'attempt_id': 't-att-1',
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
}

void main() {
  group('ApiPlasRepository', () {
    test('4.1 profile, onboarding, and class endpoints attach Bearer JWT and nullable kelas_id', () async {
      final setup = _buildRepo((options) async {
        switch ('${options.method} ${options.path}') {
          case 'GET /me':
            return _jsonResponse(200, _sampleProfileJson(kelas: _sampleClassJson()));
          case 'POST /me':
            return _jsonResponse(201, _sampleProfileJson(kelas: _sampleClassJson()));
          case 'GET /classes':
            return _jsonResponse(200, <Map<String, dynamic>>[_sampleClassJson()]);
          case 'PATCH /me/class':
            return _jsonResponse(200, _sampleProfileJson(kelas: null));
          default:
            return _jsonResponse(404, <String, dynamic>{});
        }
      });

      final me = await setup.repo.getMe();
      expect(me.mahasiswaId, 'mhs-01');
      expect(me.kelas?.kelasId, 'kls-01');
      expect(
        setup.adapter.capturedRequests.last.headers['Authorization'],
        'Bearer test-jwt',
      );

      final created = await setup.repo.createProfile(
        const CreateProfileRequest(
          nama: 'Budi Santoso',
          nim: '220101001',
          kelasId: 'kls-01',
        ),
      );
      expect(created.nim, '220101001');
      expect(setup.adapter.capturedRequests.last.data, <String, dynamic>{
        'nama': 'Budi Santoso',
        'nim': '220101001',
        'kelas_id': 'kls-01',
      });

      final classes = await setup.repo.getClasses();
      expect(classes, hasLength(1));
      expect(classes.single.kode, 'TS-2026-A');

      final updated = await setup.repo.updateClass(null);
      expect(updated.kelas, isNull);
      final patchReq = setup.adapter.capturedRequests.last;
      expect(patchReq.method, 'PATCH');
      expect(patchReq.path, '/me/class');
      expect(patchReq.data, <String, dynamic>{'kelas_id': null});
      expect((patchReq.data as Map).containsKey('kelas_id'), isTrue);
    });

    test('4.2 materials endpoints map list, detail, and sub-material', () async {
      final setup = _buildRepo((options) async {
        switch ('${options.method} ${options.path}') {
          case 'GET /materials':
            return _jsonResponse(200, <Map<String, dynamic>>[
              <String, dynamic>{
                'material_id': 'mat-01',
                'sequence': 1,
                'title': 'Dasar TypeScript',
                'description': 'Variabel dan tipe primitif.',
                'submaterial_count': 3,
                'completed_exercises': 1,
              },
            ]);
          case 'GET /materials/mat-01':
            return _jsonResponse(200, <String, dynamic>{
              'material_id': 'mat-01',
              'sequence': 1,
              'title': 'Dasar TypeScript',
              'description': 'Variabel dan tipe primitif.',
              'submaterials': <Map<String, dynamic>>[
                <String, dynamic>{
                  'submaterial_id': 'sub-01',
                  'sequence': 1,
                  'title': 'let dan const',
                  'has_submitted_exercise': true,
                  'attempts_used': 1,
                  'max_attempts': 3,
                },
              ],
            });
          case 'GET /sub-materials/sub-01':
            return _jsonResponse(200, <String, dynamic>{
              'submaterial_id': 'sub-01',
              'material_id': 'mat-01',
              'sequence': 1,
              'title': 'let dan const',
              'content_markdown': '# Materi\nGunakan `const`.',
              'exercise': <String, dynamic>{
                'exercise_id': 'ex-01',
                'title': 'Latihan let dan const',
                'question_type': 'MC',
                'latest_attempt_status': 'SUBMITTED',
                'attempts_used': 1,
                'remaining_attempts': 2,
                'max_attempts': 3,
                'best_score': 100.0,
              },
            });
          default:
            return _jsonResponse(404, <String, dynamic>{});
        }
      });

      final materials = await setup.repo.getMaterials();
      expect(materials.single.materialId, 'mat-01');

      final detail = await setup.repo.getMaterialDetail('mat-01');
      expect(detail.submaterials.single.submaterialId, 'sub-01');

      final subMaterial = await setup.repo.getSubMaterial('sub-01');
      expect(subMaterial.exercise.exerciseId, 'ex-01');
      expect(subMaterial.exercise.questionType, QuestionType.mc);
    });

    test('4.3 exercise endpoints enforce Idempotency-Key and strict P6 answer payload', () async {
      final setup = _buildRepo((options) async {
        switch ('${options.method} ${options.path}') {
          case 'GET /sub-materials/sub-01/exercise':
            return _jsonResponse(200, <String, dynamic>{
              'exercise_id': 'ex-01',
              'submaterial_id': 'sub-01',
              'title': 'Latihan let dan const',
              'question_type': 'MC',
              'questions': <Map<String, dynamic>>[
                <String, dynamic>{
                  'question_id': 'q-1',
                  'sequence': 1,
                  'question_text': 'Keyword untuk nilai tetap?',
                  'question_type': 'MC',
                  'options': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'option_id': 'opt-1',
                      'text': 'const',
                      'sequence': 1,
                    },
                  ],
                },
              ],
            });
          case 'POST /exercises/ex-01/attempts':
            return _jsonResponse(201, _sampleAttemptJson());
          case 'POST /exercise-attempts/att-1/answers':
            return _jsonResponse(200, <String, dynamic>{
              'attempt_id': 'att-1',
              'question_id': 'q-1',
              'is_correct': true,
              'explanation': 'const membuat binding tidak dapat direassign.',
              'hint': null,
              'answered_at': '2026-11-19T10:01:00.000Z',
            });
          case 'POST /exercise-attempts/att-1/submit':
            return _jsonResponse(200, _sampleAttemptJson(status: 'SUBMITTED'));
          case 'GET /exercises/ex-01/attempts':
            return _jsonResponse(200, <Map<String, dynamic>>[
              _sampleAttemptJson(status: 'SUBMITTED'),
            ]);
          case 'GET /exercise-attempts/att-1':
            return _jsonResponse(200, <String, dynamic>{
              'attempt_id': 'att-1',
              'exercise_id': 'ex-01',
              'exercise_title': 'Latihan let dan const',
              'attempt_number': 1,
              'status': 'SUBMITTED',
              'score': 100.0,
              'started_at': '2026-11-19T10:00:00.000Z',
              'submitted_at': '2026-11-19T10:05:00.000Z',
              'items': <Map<String, dynamic>>[
                <String, dynamic>{
                  'question_id': 'q-1',
                  'sequence': 1,
                  'question_text': 'Keyword untuk nilai tetap?',
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
                  'explanation': 'const membuat binding tidak dapat direassign.',
                  'hint': null,
                  'time_spent_seconds': 18,
                },
              ],
            });
          default:
            return _jsonResponse(404, <String, dynamic>{});
        }
      });

      final exercise = await setup.repo.getExercise('sub-01');
      expect(exercise.exerciseId, 'ex-01');

      final attempt = await setup.repo.createExerciseAttempt(
        exerciseId: 'ex-01',
        creationRequestId: 'req-create-ex-1',
      );
      expect(attempt.attemptId, 'att-1');
      expect(
        setup.adapter.capturedRequests.last.headers[kIdempotencyHeader],
        'req-create-ex-1',
      );

      final answerResp = await setup.repo.submitExerciseAnswer(
        attemptId: 'att-1',
        questionId: 'q-1',
        answer: const McAnswer('opt-1'),
        timeSpentSeconds: 18,
        submissionRequestId: 'req-ans-1',
      );
      expect(answerResp.isCorrect, isTrue);
      final ansReq = setup.adapter.capturedRequests.last;
      expect(ansReq.headers[kIdempotencyHeader], 'req-ans-1');
      expect(ansReq.data, <String, dynamic>{
        'question_id': 'q-1',
        'answer': <String, dynamic>{'option_id': 'opt-1'},
        'time_spent_seconds': 18,
      });
      final answerMap = (ansReq.data as Map<String, dynamic>)['answer']
          as Map<String, dynamic>;
      expect(answerMap.containsKey('type'), isFalse);

      final submitted = await setup.repo.submitExerciseAttempt(
        attemptId: 'att-1',
        idempotencyKey: 'req-submit-ex-1',
      );
      expect(submitted.status, AttemptStatus.submitted);
      expect(
        setup.adapter.capturedRequests.last.headers[kIdempotencyHeader],
        'req-submit-ex-1',
      );

      final attempts = await setup.repo.getExerciseAttempts('ex-01');
      expect(attempts, hasLength(1));

      final attemptDetail = await setup.repo.getExerciseAttemptDetail('att-1');
      expect(attemptDetail.items.single.studentAnswer, const McAnswer('opt-1'));
    });

    test('4.4 pre-test and post-test endpoints enforce sequence, P6 answer, and optional idempotencyKey', () async {
      final setup = _buildRepo((options) async {
        switch ('${options.method} ${options.path}') {
          case 'GET /tests':
            return _jsonResponse(200, <String, dynamic>{
              'pre_test': <String, dynamic>{
                'test_id': 'test-pre',
                'test_type': 'PRE',
                'title': 'Pre-test TypeScript',
                'question_count': 15,
                'status': 'NOT_STARTED',
                'active_attempt_id': null,
                'score': null,
                'is_eligible': true,
                'completed_exercises': 0,
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
                'completed_exercises': 0,
                'total_exercises': 21,
              },
            });
          case 'POST /tests/test-pre/attempts':
            return _jsonResponse(201, <String, dynamic>{
              'attempt_id': 't-att-1',
              'test_id': 'test-pre',
              'test_type': 'PRE',
              'status': 'IN_PROGRESS',
              'total_questions': 15,
              'current_sequence': 1,
              'started_at': '2026-11-19T10:10:00.000Z',
              'first_question': _sampleActiveQuestionJson(sequence: 1),
            });
          case 'POST /test-attempts/t-att-1/questions/1/start':
            return _jsonResponse(200, _sampleActiveQuestionJson(sequence: 1));
          case 'POST /test-attempts/t-att-1/questions/2/start':
            return _jsonResponse(200, _sampleActiveQuestionJson(sequence: 2));
          case 'POST /test-attempts/t-att-1/questions/1/answers':
            return _jsonResponse(200, <String, dynamic>{
              'attempt_id': 't-att-1',
              'sequence': 1,
              'is_recorded': true,
              'answered_at': '2026-11-19T10:10:30.000Z',
              'next_sequence': 2,
            });
          case 'GET /test-attempts/t-att-1/resume':
            return _jsonResponse(200, _sampleActiveQuestionJson(sequence: 2));
          case 'POST /test-attempts/t-att-1/submit':
            return _jsonResponse(200, _sampleTestResultJson());
          case 'GET /test-attempts/t-att-1':
            return _jsonResponse(200, _sampleTestResultJson());
          default:
            return _jsonResponse(404, <String, dynamic>{});
        }
      });

      final tests = await setup.repo.getTests();
      expect(tests.preTest.testId, 'test-pre');
      expect(tests.postTest.isEligible, isFalse);

      final created = await setup.repo.createTestAttempt(
        testId: 'test-pre',
        creationRequestId: 'req-create-test-1',
      );
      expect(created.attemptId, 't-att-1');
      expect(
        setup.adapter.capturedRequests.last.headers[kIdempotencyHeader],
        'req-create-test-1',
      );

      final startedWithKey = await setup.repo.startTestQuestion(
        attemptId: 't-att-1',
        sequence: 1,
        idempotencyKey: 'req-start-q1',
      );
      expect(startedWithKey.sequence, 1);
      expect(
        setup.adapter.capturedRequests.last.headers[kIdempotencyHeader],
        'req-start-q1',
      );

      final startedWithoutKey = await setup.repo.startTestQuestion(
        attemptId: 't-att-1',
        sequence: 2,
      );
      expect(startedWithoutKey.sequence, 2);
      expect(
        setup.adapter.capturedRequests.last.headers[kIdempotencyHeader],
        isNull,
      );

      final ack = await setup.repo.submitTestAnswer(
        attemptId: 't-att-1',
        sequence: 1,
        answer: const TfAnswer(true),
        submissionRequestId: 'req-test-ans-1',
      );
      expect(ack.isRecorded, isTrue);
      expect(ack.nextSequence, 2);
      final testAnsReq = setup.adapter.capturedRequests.last;
      expect(testAnsReq.headers[kIdempotencyHeader], 'req-test-ans-1');
      expect(testAnsReq.data, <String, dynamic>{
        'answer': <String, dynamic>{'value': true},
      });

      final resumed = await setup.repo.resumeTestAttempt('t-att-1');
      expect(resumed.sequence, 2);

      final submitted = await setup.repo.submitTestAttempt(
        attemptId: 't-att-1',
        idempotencyKey: 'req-test-submit-1',
      );
      expect(submitted.score, 80.0);
      expect(
        setup.adapter.capturedRequests.last.headers[kIdempotencyHeader],
        'req-test-submit-1',
      );

      final result = await setup.repo.getTestAttemptResult('t-att-1');
      expect(result.items.single.isCorrect, isTrue);
    });

    test('4.5 AI endpoints use 35s timeout and handle success + already_processed', () async {
      var askCallCount = 0;
      final setup = _buildRepo((options) async {
        switch ('${options.method} ${options.path}') {
          case 'GET /ai/quota':
            return _jsonResponse(200, <String, dynamic>{
              'remaining_quota': 9,
              'daily_limit': 10,
              'usage_date': '2026-11-19',
            });
          case 'POST /ai/ask':
            askCallCount++;
            if (askCallCount == 1) {
              return _jsonResponse(200, <String, dynamic>{
                'status': 'success',
                'answer': 'Gunakan const untuk binding tetap.',
                'hint_level': 2,
                'remaining_quota': 8,
              });
            }
            return _jsonResponse(200, <String, dynamic>{
              'status': 'already_processed',
              'answer': null,
              'hint_level': null,
              'remaining_quota': 8,
            });
          default:
            return _jsonResponse(404, <String, dynamic>{});
        }
      });

      final quota = await setup.repo.getAiQuota();
      expect(quota.remainingQuota, 9);
      expect(quota.dailyLimit, 10);

      const askRequest = AiAskRequestDto(
        question: 'Apa beda let dan const?',
        submaterialId: 'sub-01',
        hintLevel: AiHintLevel.strategi,
      );

      final firstResponse = await setup.repo.askAi(
        request: askRequest,
        requestId: 'req-ai-1',
      );
      expect(firstResponse.status, AiAskStatus.success);
      expect(firstResponse.answer, 'Gunakan const untuk binding tetap.');
      expect(firstResponse.hintLevel, AiHintLevel.strategi);
      expect(firstResponse.remainingQuota, 8);

      final aiReq = setup.adapter.capturedRequests.last;
      expect(aiReq.path, '/ai/ask');
      expect(aiReq.headers[kIdempotencyHeader], 'req-ai-1');
      expect(aiReq.receiveTimeout, kAiRequestTimeout);
      expect(aiReq.data, <String, dynamic>{
        'question': 'Apa beda let dan const?',
        'submaterial_id': 'sub-01',
        'hint_level': 2,
      });

      final duplicateResponse = await setup.repo.askAi(
        request: askRequest,
        requestId: 'req-ai-1',
      );
      expect(duplicateResponse.status, AiAskStatus.alreadyProcessed);
      expect(duplicateResponse.answer, isNull);
      expect(duplicateResponse.hintLevel, isNull);
      expect(duplicateResponse.remainingQuota, 8);
    });

    test('4.6 progress and activities endpoints decode summary and list', () async {
      final setup = _buildRepo((options) async {
        switch ('${options.method} ${options.path}') {
          case 'GET /progress':
            return _jsonResponse(200, <String, dynamic>{
              'completed_materials': 3,
              'total_materials': 7,
              'completed_exercises': 9,
              'total_exercises': 21,
              'pre_test_status': 'SUBMITTED',
              'pre_test_score': 75.0,
              'post_test_status': 'NOT_STARTED',
              'post_test_score': null,
              'is_post_test_eligible': false,
              'ai_quota': <String, dynamic>{
                'remaining_quota': 9,
                'daily_limit': 10,
                'usage_date': '2026-11-19',
              },
            });
          case 'GET /activities':
            return _jsonResponse(200, <Map<String, dynamic>>[
              <String, dynamic>{
                'attempt_id': 'att-1',
                'exercise_id': 'ex-01',
                'material_title': 'Dasar TypeScript',
                'submaterial_title': 'let dan const',
                'question_type': 'MC',
                'attempt_number': 1,
                'status': 'SUBMITTED',
                'score': 100.0,
                'created_at': '2026-11-19T10:00:00.000Z',
                'submitted_at': '2026-11-19T10:05:00.000Z',
              },
            ]);
          default:
            return _jsonResponse(404, <String, dynamic>{});
        }
      });

      final progress = await setup.repo.getProgress();
      expect(progress.completedMaterials, 3);
      expect(progress.preTestStatus, TestOverviewStatus.submitted);
      expect(progress.aiQuota.dailyLimit, 10);

      final activities = await setup.repo.getActivities();
      expect(activities, hasLength(1));
      expect(activities.single.submaterialTitle, 'let dan const');
    });

    test('replayPendingSyncItem preserves method, path, body, and Idempotency-Key', () async {
      final setup = _buildRepo((options) async {
        return _jsonResponse(200, <String, dynamic>{'ok': true});
      });

      const item = PendingSyncItem(
        idempotencyKey: 'sync-key-123',
        method: 'POST',
        path: '/exercise-attempts/att-1/answers',
        body: <String, dynamic>{
          'question_id': 'q-1',
          'answer': <String, dynamic>{'value': 'const'},
          'time_spent_seconds': 14,
        },
        createdAtIso: '2026-11-19T10:02:00.000Z',
        operationLabel: 'Kirim jawaban latihan',
      );

      await setup.repo.replayPendingSyncItem(item);

      final replayed = setup.adapter.capturedRequests.single;
      expect(replayed.method, 'POST');
      expect(replayed.path, '/exercise-attempts/att-1/answers');
      expect(replayed.headers[kIdempotencyHeader], 'sync-key-123');
      expect(replayed.headers['Authorization'], 'Bearer test-jwt');
      expect(replayed.data, item.body);
    });

    test('unwraps ErrorInterceptor domain errors and connection failures to PlasApiException', () async {
      final lockedSetup = _buildRepo((options) async {
        return _jsonResponse(409, <String, dynamic>{
          'error': <String, dynamic>{
            'code': ApiErrorCodes.classLocked,
            'message': 'Class locked after pre-test submission',
          },
        });
      });

      await expectLater(
        () => lockedSetup.repo.updateClass('kls-02'),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.classLocked)
              .having((e) => e.statusCode, 'statusCode', 409)
              .having((e) => e.isOffline, 'isOffline', isFalse),
        ),
      );

      final prereqSetup = _buildRepo((options) async {
        return _jsonResponse(409, <String, dynamic>{
          'error': <String, dynamic>{
            'code': ApiErrorCodes.prerequisiteNotMet,
            'message': 'Complete all mandatory exercises first',
          },
        });
      });

      await expectLater(
        () => prereqSetup.repo.createTestAttempt(
          testId: 'test-post',
          creationRequestId: 'req-post-1',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.prerequisiteNotMet)
              .having((e) => e.statusCode, 'statusCode', 409),
        ),
      );

      final quotaSetup = _buildRepo((options) async {
        return _jsonResponse(403, <String, dynamic>{
          'error': <String, dynamic>{
            'code': ApiErrorCodes.quotaExceeded,
            'message': 'Daily quota exhausted',
          },
        });
      });

      await expectLater(
        () => quotaSetup.repo.askAi(
          request: const AiAskRequestDto(question: 'Apa itu interface?'),
          requestId: 'req-ai-quota',
        ),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.quotaExceeded)
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );

      final offlineSetup = _buildRepo((options) async {
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'Socket closed',
        );
      });

      await expectLater(
        () => offlineSetup.repo.getMaterials(),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.networkOffline)
              .having((e) => e.isOffline, 'isOffline', isTrue)
              .having((e) => e.isRetryable, 'isRetryable', isTrue),
        ),
      );
    });

    test('throws PlasApiException when response body shape is invalid', () async {
      final setup = _buildRepo((options) async {
        return _jsonResponse(200, 'unexpected-string-payload');
      });

      await expectLater(
        () => setup.repo.getMe(),
        throwsA(
          isA<PlasApiException>()
              .having((e) => e.code, 'code', ApiErrorCodes.serverError)
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });
  });
}
