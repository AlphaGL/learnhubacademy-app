import 'dart:convert';

import '../../features/exams/models/exam_models.dart';
import 'app_api_client.dart';

class QotdException implements Exception {
  const QotdException(this.message);
  final String message;
  @override
  String toString() => message;
}

class QotdAnswerResult {
  const QotdAnswerResult({required this.isCorrect, required this.correctOptionId});
  final bool isCorrect;
  final int? correctOptionId;

  factory QotdAnswerResult.fromJson(Map<String, dynamic> j) => QotdAnswerResult(
        isCorrect: j['is_correct'] as bool,
        correctOptionId: j['correct_option_id'] as int?,
      );
}

class QuestionOfTheDay {
  const QuestionOfTheDay({
    required this.question,
    required this.source,
    required this.alreadyAnswered,
    required this.wasCorrect,
  });

  final ExamQuestion? question;
  final String? source;
  final bool alreadyAnswered;
  final bool? wasCorrect;

  factory QuestionOfTheDay.fromJson(Map<String, dynamic> j) {
    final q = j['question'] as Map<String, dynamic>?;
    return QuestionOfTheDay(
      question: q == null ? null : ExamQuestion.fromJson(q),
      source: q?['source'] as String?,
      alreadyAnswered: j['already_answered'] as bool,
      wasCorrect: j['was_correct'] as bool?,
    );
  }
}

/// Mirrors the website's /question-of-the-day/ page — same question for
/// every student on a given day (learning/views.py _qotd), computed
/// server-side and not leaked to the client until answered.
class QuestionOfTheDayApiService {
  QuestionOfTheDayApiService._();
  static final QuestionOfTheDayApiService instance = QuestionOfTheDayApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<QuestionOfTheDay> fetch() async {
    try {
      final resp = await _client.request('GET', '/api/question-of-the-day/');
      _client.checkOk(resp);
      return QuestionOfTheDay.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    } on AppApiException catch (e) {
      throw QotdException(e.message);
    }
  }

  Future<QotdAnswerResult> answer(int optionId) async {
    try {
      final resp = await _client.request('POST', '/api/question-of-the-day/answer/',
          body: {'option_id': optionId});
      _client.checkOk(resp);
      return QotdAnswerResult.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    } on AppApiException catch (e) {
      throw QotdException(e.message);
    }
  }
}
