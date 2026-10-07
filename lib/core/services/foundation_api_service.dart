import 'dart:convert';

import 'app_api_client.dart';

class FoundationException implements Exception {
  const FoundationException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FoundationInstitution {
  const FoundationInstitution({
    required this.slug,
    required this.name,
    required this.shortName,
    required this.logoUrl,
    this.subjectCount,
  });
  final String slug;
  final String name;
  final String shortName;
  final String logoUrl;
  final int? subjectCount;

  factory FoundationInstitution.fromJson(Map<String, dynamic> j) => FoundationInstitution(
        slug: j['slug'] as String,
        name: j['name'] as String,
        shortName: j['short_name'] as String,
        logoUrl: j['logo_url'] as String,
        subjectCount: j['subject_count'] as int?,
      );
}

class FoundationHome {
  const FoundationHome({required this.jupebSubjectCount, required this.institutions});
  final int jupebSubjectCount;
  final List<FoundationInstitution> institutions;

  factory FoundationHome.fromJson(Map<String, dynamic> j) => FoundationHome(
        jupebSubjectCount: j['jupeb_subject_count'] as int,
        institutions: (j['institutions'] as List)
            .map((e) => FoundationInstitution.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class FoundationYear {
  const FoundationYear({
    required this.id,
    required this.year,
    required this.sessionNote,
    required this.questionCount,
  });
  final int id;
  final int year;
  final String sessionNote;
  final int questionCount;

  factory FoundationYear.fromJson(Map<String, dynamic> j) => FoundationYear(
        id: j['id'] as int,
        year: j['year'] as int,
        sessionNote: j['session_note'] as String,
        questionCount: j['question_count'] as int,
      );
}

class FoundationSubject {
  const FoundationSubject({
    required this.id,
    required this.program,
    required this.name,
    required this.slug,
    required this.description,
    required this.icon,
    this.institution,
    this.years = const [],
  });
  final int id;
  final String program;
  final String name;
  final String slug;
  final String description;
  final String icon;
  final FoundationInstitution? institution;
  final List<FoundationYear> years;

  factory FoundationSubject.fromJson(Map<String, dynamic> j) => FoundationSubject(
        id: j['id'] as int,
        program: j['program'] as String,
        name: j['name'] as String,
        slug: j['slug'] as String,
        description: j['description'] as String,
        icon: j['icon'] as String,
        institution: j['institution'] == null
            ? null
            : FoundationInstitution.fromJson(j['institution'] as Map<String, dynamic>),
        years: j['years'] == null
            ? const []
            : (j['years'] as List).map((e) => FoundationYear.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class FoundationTopic {
  const FoundationTopic({required this.id, required this.title, required this.order, this.content});
  final int id;
  final String title;
  final int order;
  final String? content;

  factory FoundationTopic.fromJson(Map<String, dynamic> j) => FoundationTopic(
        id: j['id'] as int,
        title: j['title'] as String,
        order: j['order'] as int,
        content: j['content'] as String?,
      );
}

class SubjectDetail {
  const SubjectDetail({
    required this.subject,
    required this.topics,
    required this.years,
    required this.isSubscriber,
  });
  final FoundationSubject subject;
  final List<FoundationTopic> topics;
  final List<FoundationYear> years;
  final bool isSubscriber;

  factory SubjectDetail.fromJson(Map<String, dynamic> j) => SubjectDetail(
        subject: FoundationSubject.fromJson(j['subject'] as Map<String, dynamic>),
        topics:
            (j['topics'] as List).map((e) => FoundationTopic.fromJson(e as Map<String, dynamic>)).toList(),
        years: (j['years'] as List).map((e) => FoundationYear.fromJson(e as Map<String, dynamic>)).toList(),
        isSubscriber: j['is_subscriber'] as bool,
      );
}

class PracticeOption {
  const PracticeOption({required this.id, required this.label, required this.text});
  final int id;
  final String label;
  final String text;

  factory PracticeOption.fromJson(Map<String, dynamic> j) => PracticeOption(
        id: j['id'] as int,
        label: j['option_label'] as String,
        text: j['option_text'] as String,
      );
}

class PracticeQuestion {
  const PracticeQuestion({
    required this.id,
    required this.number,
    required this.text,
    required this.options,
    this.selectedOptionId,
    this.correctOptionId,
    this.explanation,
    this.answerVerifiedBy,
  });
  final int id;
  final int number;
  final String text;
  final List<PracticeOption> options;
  final int? selectedOptionId;
  final int? correctOptionId;
  final String? explanation;
  final String? answerVerifiedBy;

  factory PracticeQuestion.fromJson(Map<String, dynamic> j) => PracticeQuestion(
        id: j['id'] as int,
        number: j['question_number'] as int,
        text: j['question_text'] as String,
        options:
            (j['options'] as List).map((e) => PracticeOption.fromJson(e as Map<String, dynamic>)).toList(),
        selectedOptionId: j['selected_option_id'] as int?,
        correctOptionId: j['correct_option_id'] as int?,
        explanation: j['explanation'] as String?,
        answerVerifiedBy: j['answer_verified_by'] as String?,
      );
}

class PracticeTakeData {
  const PracticeTakeData({
    required this.completed,
    required this.sessionId,
    this.subject,
    this.year,
    this.questions = const [],
  });
  final bool completed;
  final String sessionId;
  final String? subject;
  final FoundationYear? year;
  final List<PracticeQuestion> questions;

  factory PracticeTakeData.fromJson(Map<String, dynamic> j) => PracticeTakeData(
        completed: j['completed'] as bool,
        sessionId: j['session_id'] as String,
        subject: j['subject'] as String?,
        year: j['year'] == null ? null : FoundationYear.fromJson(j['year'] as Map<String, dynamic>),
        questions: j['questions'] == null
            ? const []
            : (j['questions'] as List)
                .map((e) => PracticeQuestion.fromJson(e as Map<String, dynamic>))
                .toList(),
      );
}

class AnswerResult {
  const AnswerResult({
    required this.isCorrect,
    this.correctOptionLabel,
    required this.explanation,
    required this.answerVerifiedBy,
  });
  final bool isCorrect;
  final String? correctOptionLabel;
  final String explanation;
  final String answerVerifiedBy;

  factory AnswerResult.fromJson(Map<String, dynamic> j) => AnswerResult(
        isCorrect: j['is_correct'] as bool,
        correctOptionLabel: j['correct_option_label'] as String?,
        explanation: j['explanation'] as String,
        answerVerifiedBy: j['answer_verified_by'] as String,
      );
}

class PracticeResults {
  const PracticeResults({
    required this.sessionId,
    required this.subject,
    required this.year,
    required this.score,
    required this.totalQuestions,
    required this.questions,
  });
  final String sessionId;
  final String subject;
  final FoundationYear year;
  final double score;
  final int totalQuestions;
  final List<PracticeQuestion> questions;

  factory PracticeResults.fromJson(Map<String, dynamic> j) => PracticeResults(
        sessionId: j['session_id'] as String,
        subject: j['subject'] as String,
        year: FoundationYear.fromJson(j['year'] as Map<String, dynamic>),
        score: (j['score'] as num).toDouble(),
        totalQuestions: j['total_questions'] as int,
        questions:
            (j['questions'] as List).map((e) => PracticeQuestion.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

/// Mirrors foundation/views.py — JUPEB & Pre-Degree study notes and past
/// questions, reached from the app via the same bearer-token API the exam
/// and ambassador features established.
class FoundationApiService {
  FoundationApiService._();
  static final FoundationApiService instance = FoundationApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppApiException catch (e) {
      throw FoundationException(e.message);
    }
  }

  static const _subscriptionMessage =
      'JUPEB & Pre-Degree past questions are a subscriber feature — subscribe to unlock them.';

  Future<FoundationHome> home() => _run(() async {
        final resp = await _client.request('GET', '/api/foundation/home/');
        _client.checkOk(resp);
        return FoundationHome.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });

  Future<List<FoundationSubject>> jupebSubjects() => _run(() async {
        final resp = await _client.request('GET', '/api/foundation/jupeb/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['subjects'] as List)
            .map((e) => FoundationSubject.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<List<FoundationInstitution>> predegreeInstitutions() => _run(() async {
        final resp = await _client.request('GET', '/api/foundation/predegree/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['institutions'] as List)
            .map((e) => FoundationInstitution.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<List<FoundationSubject>> institutionSubjects(String institutionSlug) => _run(() async {
        final resp = await _client.request('GET', '/api/foundation/predegree/$institutionSlug/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['subjects'] as List)
            .map((e) => FoundationSubject.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<SubjectDetail> subjectDetail(int subjectId) => _run(() async {
        final resp = await _client.request('GET', '/api/foundation/subject/$subjectId/');
        _client.checkOk(resp);
        return SubjectDetail.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });

  Future<FoundationTopic> topicDetail(int topicId) => _run(() async {
        final resp = await _client.request('GET', '/api/foundation/topic/$topicId/');
        _client.checkOk(resp, subscriptionMessage: _subscriptionMessage);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return FoundationTopic.fromJson(data['topic'] as Map<String, dynamic>);
      });

  Future<String> practiceStart(int yearId) => _run(() async {
        final resp = await _client.request('POST', '/api/foundation/practice/year/$yearId/start/');
        _client.checkOk(resp, subscriptionMessage: _subscriptionMessage);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['session_id'] as String;
      });

  Future<PracticeTakeData> practiceTake(String sessionId) => _run(() async {
        final resp = await _client.request('GET', '/api/foundation/practice/$sessionId/');
        _client.checkOk(resp, subscriptionMessage: _subscriptionMessage);
        return PracticeTakeData.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });

  Future<AnswerResult> practiceAnswer(String sessionId, int questionId, int optionId) => _run(() async {
        final resp = await _client.request('POST', '/api/foundation/practice/$sessionId/answer/', body: {
          'question_id': questionId,
          'option_id': optionId,
        });
        _client.checkOk(resp);
        return AnswerResult.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });

  Future<void> practiceFinish(String sessionId) => _run(() async {
        final resp = await _client.request('POST', '/api/foundation/practice/$sessionId/finish/');
        _client.checkOk(resp);
      });

  Future<PracticeResults> practiceResults(String sessionId) => _run(() async {
        final resp = await _client.request('GET', '/api/foundation/practice/$sessionId/results/');
        _client.checkOk(resp);
        return PracticeResults.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });
}
