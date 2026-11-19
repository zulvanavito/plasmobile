import 'package:dio/dio.dart';
import 'package:plasmobile/core/constants/api_error_codes.dart';
import 'package:plasmobile/core/errors/plas_exception.dart';
import 'package:plasmobile/core/network/dio_client.dart';
import 'package:plasmobile/core/network/idempotency_interceptor.dart';
import 'package:plasmobile/core/sync/pending_sync_queue.dart';
import 'package:plasmobile/data/dto/ai_dto.dart';
import 'package:plasmobile/data/dto/exercise_dto.dart';
import 'package:plasmobile/data/dto/material_dto.dart';
import 'package:plasmobile/data/dto/progress_dto.dart';
import 'package:plasmobile/data/dto/student_answer.dart';
import 'package:plasmobile/data/dto/student_profile_dto.dart';
import 'package:plasmobile/data/dto/test_dto.dart';
import 'package:plasmobile/data/repositories/plas_repository.dart';

class ApiPlasRepository implements PlasRepository {
  const ApiPlasRepository({required this.dio});

  final Dio dio;

  @override
  Future<StudentProfileDto> getMe() {
    return _getObject('/me', StudentProfileDto.fromJson);
  }

  @override
  Future<StudentProfileDto> createProfile(CreateProfileRequest request) {
    return _postObject(
      '/me',
      StudentProfileDto.fromJson,
      data: request.toJson(),
    );
  }

  @override
  Future<List<ClassInfoDto>> getClasses() {
    return _getObjectList('/classes', ClassInfoDto.fromJson);
  }

  @override
  Future<StudentProfileDto> updateClass(String? kelasId) {
    return _guard(() async {
      final response = await dio.patch<dynamic>(
        '/me/class',
        data: <String, dynamic>{'kelas_id': kelasId},
      );
      return StudentProfileDto.fromJson(_asMap(response.data));
    });
  }

  @override
  Future<List<MaterialSummaryDto>> getMaterials() {
    return _getObjectList('/materials', MaterialSummaryDto.fromJson);
  }

  @override
  Future<MaterialDetailDto> getMaterialDetail(String materialId) {
    return _getObject('/materials/$materialId', MaterialDetailDto.fromJson);
  }

  @override
  Future<SubMaterialDetailDto> getSubMaterial(String submaterialId) {
    return _getObject(
      '/sub-materials/$submaterialId',
      SubMaterialDetailDto.fromJson,
    );
  }

  @override
  Future<ExerciseDetailDto> getExercise(String submaterialId) {
    return _getObject(
      '/sub-materials/$submaterialId/exercise',
      ExerciseDetailDto.fromJson,
    );
  }

  @override
  Future<ExerciseAttemptDto> createExerciseAttempt({
    required String exerciseId,
    required String creationRequestId,
  }) {
    return _postObject(
      '/exercises/$exerciseId/attempts',
      ExerciseAttemptDto.fromJson,
      options: _idempotentOptions(creationRequestId),
    );
  }

  @override
  Future<ExerciseAnswerResponseDto> submitExerciseAnswer({
    required String attemptId,
    required String questionId,
    required StudentAnswer answer,
    required int timeSpentSeconds,
    required String submissionRequestId,
  }) {
    return _postObject(
      '/exercise-attempts/$attemptId/answers',
      ExerciseAnswerResponseDto.fromJson,
      data: <String, dynamic>{
        'question_id': questionId,
        'answer': answer.toJson(),
        'time_spent_seconds': timeSpentSeconds,
      },
      options: _idempotentOptions(submissionRequestId),
    );
  }

  @override
  Future<ExerciseAttemptDto> submitExerciseAttempt({
    required String attemptId,
    required String idempotencyKey,
  }) {
    return _postObject(
      '/exercise-attempts/$attemptId/submit',
      ExerciseAttemptDto.fromJson,
      options: _idempotentOptions(idempotencyKey),
    );
  }

  @override
  Future<List<ExerciseAttemptDto>> getExerciseAttempts(String exerciseId) {
    return _getObjectList(
      '/exercises/$exerciseId/attempts',
      ExerciseAttemptDto.fromJson,
    );
  }

  @override
  Future<ExerciseAttemptDetailDto> getExerciseAttemptDetail(String attemptId) {
    return _getObject(
      '/exercise-attempts/$attemptId',
      ExerciseAttemptDetailDto.fromJson,
    );
  }

  @override
  Future<TestsOverviewDto> getTests() {
    return _getObject('/tests', TestsOverviewDto.fromJson);
  }

  @override
  Future<TestAttemptStartDto> createTestAttempt({
    required String testId,
    required String creationRequestId,
  }) {
    return _postObject(
      '/tests/$testId/attempts',
      TestAttemptStartDto.fromJson,
      options: _idempotentOptions(creationRequestId),
    );
  }

  @override
  Future<TestActiveQuestionDto> startTestQuestion({
    required String attemptId,
    required int sequence,
    String? idempotencyKey,
  }) {
    return _postObject(
      '/test-attempts/$attemptId/questions/$sequence/start',
      TestActiveQuestionDto.fromJson,
      options:
          idempotencyKey != null ? _idempotentOptions(idempotencyKey) : null,
    );
  }

  @override
  Future<TestAnswerAckDto> submitTestAnswer({
    required String attemptId,
    required int sequence,
    required StudentAnswer answer,
    required String submissionRequestId,
  }) {
    return _postObject(
      '/test-attempts/$attemptId/questions/$sequence/answers',
      TestAnswerAckDto.fromJson,
      data: <String, dynamic>{'answer': answer.toJson()},
      options: _idempotentOptions(submissionRequestId),
    );
  }

  @override
  Future<TestActiveQuestionDto> resumeTestAttempt(String attemptId) {
    return _getObject(
      '/test-attempts/$attemptId/resume',
      TestActiveQuestionDto.fromJson,
    );
  }

  @override
  Future<TestAttemptResultDto> submitTestAttempt({
    required String attemptId,
    required String idempotencyKey,
  }) {
    return _postObject(
      '/test-attempts/$attemptId/submit',
      TestAttemptResultDto.fromJson,
      options: _idempotentOptions(idempotencyKey),
    );
  }

  @override
  Future<TestAttemptResultDto> getTestAttemptResult(String attemptId) {
    return _getObject(
      '/test-attempts/$attemptId',
      TestAttemptResultDto.fromJson,
    );
  }

  @override
  Future<AiQuotaDto> getAiQuota() {
    return _getObject('/ai/quota', AiQuotaDto.fromJson);
  }

  @override
  Future<AiAskResponseDto> askAi({
    required AiAskRequestDto request,
    required String requestId,
  }) {
    return _postObject(
      '/ai/ask',
      AiAskResponseDto.fromJson,
      data: request.toJson(),
      options: _idempotentOptions(
        requestId,
        receiveTimeout: kAiRequestTimeout,
      ),
    );
  }

  @override
  Future<ProgressSummaryDto> getProgress() {
    return _getObject('/progress', ProgressSummaryDto.fromJson);
  }

  @override
  Future<List<ActivityItemDto>> getActivities() {
    return _getObjectList('/activities', ActivityItemDto.fromJson);
  }

  @override
  Future<void> replayPendingSyncItem(PendingSyncItem item) {
    return _guard(() async {
      await dio.request<dynamic>(
        item.path,
        data: item.body,
        options: Options(
          method: item.method,
          extra: <String, dynamic>{
            kRequireIdempotencyExtra: true,
            kIdempotencyKeyExtra: item.idempotencyKey,
          },
        ),
      );
    });
  }

  Future<T> _getObject<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    return _guard(() async {
      final response = await dio.get<dynamic>(path);
      return fromJson(_asMap(response.data));
    });
  }

  Future<List<T>> _getObjectList<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson,
  ) {
    return _guard(() async {
      final response = await dio.get<dynamic>(path);
      final items = _asList(response.data);
      return List<T>.unmodifiable(
        items.map((item) => fromJson(_asMap(item))),
      );
    });
  }

  Future<T> _postObject<T>(
    String path,
    T Function(Map<String, dynamic> json) fromJson, {
    Object? data,
    Options? options,
  }) {
    return _guard(() async {
      final response = await dio.post<dynamic>(
        path,
        data: data,
        options: options,
      );
      return fromJson(_asMap(response.data));
    });
  }

  Options _idempotentOptions(String key, {Duration? receiveTimeout}) {
    return Options(
      receiveTimeout: receiveTimeout,
      extra: <String, dynamic>{
        kRequireIdempotencyExtra: true,
        kIdempotencyKeyExtra: key,
      },
    );
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw PlasApiException.fromApiCode(
      ApiErrorCodes.serverError,
      statusCode: 500,
      serverMessage: 'Expected JSON object response, got ${data.runtimeType}.',
    );
  }

  List<dynamic> _asList(dynamic data) {
    if (data is List<dynamic>) return data;
    if (data is List) return List<dynamic>.from(data);
    throw PlasApiException.fromApiCode(
      ApiErrorCodes.serverError,
      statusCode: 500,
      serverMessage: 'Expected JSON array response, got ${data.runtimeType}.',
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PlasApiException {
      rethrow;
    } on DioException catch (e) {
      final inner = e.error;
      if (inner is PlasApiException) {
        throw inner;
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw PlasApiException.offline(e.message);
      }
      throw PlasApiException.fromApiCode(
        ApiErrorCodes.serverError,
        statusCode: e.response?.statusCode,
        serverMessage: e.message ?? inner?.toString(),
      );
    }
  }
}
