import 'dart:convert';

import '../../features/exams/models/exam_models.dart';
import 'app_api_client.dart';

class FlashcardsException implements Exception {
  const FlashcardsException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A due flashcard — same question/option shape the exam feature already
/// parses (learning/views.py _serialize_question), plus flashcard-specific
/// fields. Reuses ExamQuestion/ExamOption instead of duplicating them.
class FlashcardItem {
  const FlashcardItem({
    required this.flashcardId,
    required this.question,
    required this.box,
    required this.dueDate,
    required this.explanation,
    required this.source,
  });

  final int flashcardId;
  final ExamQuestion question;
  final int box;
  final String dueDate;
  final String? explanation;
  final String source;

  factory FlashcardItem.fromJson(Map<String, dynamic> j) => FlashcardItem(
        flashcardId: j['flashcard_id'] as int,
        question: ExamQuestion.fromJson(j),
        box: j['box'] as int,
        dueDate: j['due_date'] as String,
        explanation: j['explanation'] as String?,
        source: (j['source'] ?? '') as String,
      );
}

/// Deck is auto-populated server-side from wrong exam/quiz answers (see
/// Answer.save()/MaterialAnswer.save() in learning/models.py) — this
/// service only reads due cards and reports review outcomes back.
class FlashcardsApiService {
  FlashcardsApiService._();
  static final FlashcardsApiService instance = FlashcardsApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<List<FlashcardItem>> due() async {
    try {
      final resp = await _client.request('GET', '/api/flashcards/due/');
      _client.checkOk(resp);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return (data['cards'] as List)
          .map((e) => FlashcardItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on AppApiException catch (e) {
      throw FlashcardsException(e.message);
    }
  }

  Future<void> review(int flashcardId, bool gotIt) async {
    try {
      final resp = await _client
          .request('POST', '/api/flashcards/$flashcardId/review/', body: {'got_it': gotIt});
      _client.checkOk(resp);
    } on AppApiException catch (e) {
      throw FlashcardsException(e.message);
    }
  }
}
