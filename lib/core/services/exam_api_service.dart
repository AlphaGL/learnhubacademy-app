import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/exams/models/exam_models.dart';
import 'app_api_client.dart';

/// Talks to the website's exam/CBT JSON API (learning/views.py api_* on the
/// Django side) — the app has no exam-taking logic of its own; every
/// question, answer, and score goes through the same Django models and
/// scoring the website itself uses, so behavior can't drift between them.
///
/// Auth/transport is shared with every other app-facing Django feature via
/// [AppApiClient]; this class just maps exam endpoints onto it and adapts
/// errors to [ExamException] for the exam UI.
class ExamApiService {
  ExamApiService._();
  static final ExamApiService instance = ExamApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppApiException catch (e) {
      throw ExamException(e.message);
    }
  }

  void _checkOk(http.Response response) => _client.checkOk(
        response,
        subscriptionMessage: 'Subscribe to take practice exams.',
      );

  String _basePath(ExamKind kind) =>
      kind == ExamKind.examYear ? '/api/exam' : '/api/material-exam';

  Future<List<ExamYearSummary>> examYears(int subjectId) => _run(() async {
        final resp = await _client.request('GET', '/api/exam-years/$subjectId/');
        _checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['exam_years'] as List)
            .map((e) => ExamYearSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<ExamSession> startExam({
    required int examYearId,
    required String mode,
  }) =>
      _run(() async {
        final resp = await _client.request('POST', '/api/exam/start/',
            body: {'exam_year_id': examYearId, 'mode': mode});
        _checkOk(resp);
        return ExamSession.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>, ExamKind.examYear);
      });

  Future<ExamSession> startMaterialExam({
    required int materialId,
    required String mode,
  }) =>
      _run(() async {
        final resp = await _client.request('POST', '/api/material-exam/start/',
            body: {'material_id': materialId, 'mode': mode});
        _checkOk(resp);
        return ExamSession.fromJson(
            jsonDecode(resp.body) as Map<String, dynamic>, ExamKind.material);
      });

  /// Returns null if the exam was already completed (nothing to resume —
  /// caller should show results instead).
  Future<ExamSession?> resumeExam(ExamKind kind, String examId) => _run(() async {
        final resp = await _client.request('GET', '${_basePath(kind)}/$examId/state/');
        _checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['is_completed'] == true) return null;
        return ExamSession.fromJson(data, kind);
      });

  Future<AnswerResult> submitAnswer(
    ExamKind kind,
    String examId, {
    required int questionId,
    required int optionId,
    required int timeTakenSeconds,
  }) =>
      _run(() async {
        final resp = await _client.request('POST', '${_basePath(kind)}/$examId/answer/', body: {
          'question_id': questionId,
          'option_id': optionId,
          'time_taken': timeTakenSeconds,
        });
        _checkOk(resp);
        return AnswerResult.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });

  Future<void> finishExam(ExamKind kind, String examId) => _run(() async {
        final resp = await _client.request('POST', '${_basePath(kind)}/$examId/submit/');
        _checkOk(resp);
      });

  Future<ExamResults> examResults(ExamKind kind, String examId) => _run(() async {
        final resp = await _client.request('GET', '${_basePath(kind)}/$examId/results/');
        _checkOk(resp);
        return ExamResults.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });

  Future<List<ExamHistoryEntry>> examHistory() => _run(() async {
        final resp = await _client.request('GET', '/api/exam-history/');
        _checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['history'] as List)
            .map((e) => ExamHistoryEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  /// Called on sign-out so the next signed-in user (on a shared device)
  /// never accidentally reuses a stale token.
  void clearToken() => _client.clearToken();
}
