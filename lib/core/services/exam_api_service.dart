import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/exams/models/exam_models.dart';
import '../config/app_config.dart';
import 'supabase_service.dart';

/// Talks to the website's exam/CBT JSON API (learning/views.py api_* on the
/// Django side) — the app has no exam-taking logic of its own; every
/// question, answer, and score goes through the same Django models and
/// scoring the website itself uses, so behavior can't drift between them.
///
/// Auth is a bearer token exchanged for the app's own Supabase session (see
/// exam_token_view on the website) — works no matter how the app user
/// signed in, and is fetched lazily/refetched once on a 401.
class ExamApiService {
  ExamApiService._();
  static final ExamApiService instance = ExamApiService._();

  String? _token;

  Future<String?> _fetchToken() async {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return null;

    final resp = await http.post(
      Uri.parse('${AppConfig.siteUrl}/api/exam-token/'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) return null;
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return body['token'] as String?;
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    Future<http.Response> attempt(String token) {
      final uri = Uri.parse('${AppConfig.siteUrl}$path');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      return method == 'GET'
          ? http.get(uri, headers: headers).timeout(const Duration(seconds: 15))
          : http
              .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(const Duration(seconds: 15));
    }

    _token ??= await _fetchToken();
    if (_token == null) {
      throw const ExamException('Sign in again to take exams.');
    }

    var response = await attempt(_token!);
    if (response.statusCode == 401) {
      // Token expired or was never valid — fetch a fresh one, once.
      _token = await _fetchToken();
      if (_token == null) {
        throw const ExamException('Sign in again to take exams.');
      }
      response = await attempt(_token!);
    }
    return response;
  }

  void _checkOk(http.Response response) {
    if (response.statusCode == 402) {
      throw const ExamException('Subscribe to take practice exams.');
    }
    if (response.statusCode >= 400) {
      var message = 'Something went wrong (${response.statusCode}).';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] is String) message = data['error'] as String;
      } catch (_) {/* fall back to the generic message above */}
      throw ExamException(message);
    }
  }

  String _basePath(ExamKind kind) =>
      kind == ExamKind.examYear ? '/api/exam' : '/api/material-exam';

  Future<List<ExamYearSummary>> examYears(int subjectId) async {
    final resp = await _request('GET', '/api/exam-years/$subjectId/');
    _checkOk(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['exam_years'] as List)
        .map((e) => ExamYearSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExamSession> startExam({
    required int examYearId,
    required String mode,
  }) async {
    final resp = await _request('POST', '/api/exam/start/',
        body: {'exam_year_id': examYearId, 'mode': mode});
    _checkOk(resp);
    return ExamSession.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>, ExamKind.examYear);
  }

  Future<ExamSession> startMaterialExam({
    required int materialId,
    required String mode,
  }) async {
    final resp = await _request('POST', '/api/material-exam/start/',
        body: {'material_id': materialId, 'mode': mode});
    _checkOk(resp);
    return ExamSession.fromJson(
        jsonDecode(resp.body) as Map<String, dynamic>, ExamKind.material);
  }

  /// Returns null if the exam was already completed (nothing to resume —
  /// caller should show results instead).
  Future<ExamSession?> resumeExam(ExamKind kind, String examId) async {
    final resp = await _request('GET', '${_basePath(kind)}/$examId/state/');
    _checkOk(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['is_completed'] == true) return null;
    return ExamSession.fromJson(data, kind);
  }

  Future<AnswerResult> submitAnswer(
    ExamKind kind,
    String examId, {
    required int questionId,
    required int optionId,
    required int timeTakenSeconds,
  }) async {
    final resp = await _request('POST', '${_basePath(kind)}/$examId/answer/', body: {
      'question_id': questionId,
      'option_id': optionId,
      'time_taken': timeTakenSeconds,
    });
    _checkOk(resp);
    return AnswerResult.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> finishExam(ExamKind kind, String examId) async {
    final resp = await _request('POST', '${_basePath(kind)}/$examId/submit/');
    _checkOk(resp);
  }

  Future<ExamResults> examResults(ExamKind kind, String examId) async {
    final resp = await _request('GET', '${_basePath(kind)}/$examId/results/');
    _checkOk(resp);
    return ExamResults.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<List<ExamHistoryEntry>> examHistory() async {
    final resp = await _request('GET', '/api/exam-history/');
    _checkOk(resp);
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return (data['history'] as List)
        .map((e) => ExamHistoryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Called on sign-out so the next signed-in user (on a shared device)
  /// never accidentally reuses a stale token.
  void clearToken() {
    _token = null;
    debugPrint('Exam API token cleared');
  }
}
