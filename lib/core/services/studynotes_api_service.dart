import 'dart:convert';

import 'app_api_client.dart';

class StudyNotesException implements Exception {
  const StudyNotesException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LevelOption {
  const LevelOption(this.value, this.label);
  final String value;
  final String label;

  factory LevelOption.fromJson(Map<String, dynamic> j) =>
      LevelOption(j['value'] as String, j['label'] as String);
}

class StudyNoteModel {
  const StudyNoteModel({
    required this.id,
    required this.title,
    required this.sourceFilename,
    required this.summary,
    required this.status,
    required this.audioUrl,
    required this.isUnlocked,
    required this.isPublished,
    required this.level,
    required this.courseName,
    required this.testType,
    required this.updatedAt,
  });
  final int id;
  final String title;
  final String sourceFilename;
  final String summary;
  final String status; // 'draft' | 'ready'
  final String audioUrl;
  final bool isUnlocked;
  final bool isPublished;
  final String level;
  final String courseName;
  final String testType; // '' | 'cbt' | 'theory'
  final String updatedAt;

  factory StudyNoteModel.fromJson(Map<String, dynamic> j) => StudyNoteModel(
        id: j['id'] as int,
        title: j['title'] as String,
        sourceFilename: (j['source_filename'] ?? '') as String,
        summary: (j['summary'] ?? '') as String,
        status: j['status'] as String,
        audioUrl: (j['audio_url'] ?? '') as String,
        isUnlocked: j['is_unlocked'] as bool,
        isPublished: (j['is_published'] ?? false) as bool,
        level: (j['level'] ?? '') as String,
        courseName: (j['course_name'] ?? '') as String,
        testType: (j['test_type'] ?? '') as String,
        updatedAt: j['updated_at'] as String,
      );
}

class LibraryNoteModel {
  const LibraryNoteModel({
    required this.id,
    required this.title,
    required this.level,
    required this.levelDisplay,
    required this.courseName,
    required this.testType,
    required this.testTypeDisplay,
    required this.owner,
    this.summary,
    this.questionCount,
    this.theoryQuestions,
  });
  final int id;
  final String title;
  final String level;
  final String levelDisplay;
  final String courseName;
  final String testType;
  final String testTypeDisplay;
  final String owner;
  final String? summary;
  final int? questionCount;
  final List<TheoryQuestionModel>? theoryQuestions;

  factory LibraryNoteModel.fromJson(Map<String, dynamic> j) => LibraryNoteModel(
        id: j['id'] as int,
        title: j['title'] as String,
        level: j['level'] as String,
        levelDisplay: j['level_display'] as String,
        courseName: (j['course_name'] ?? '') as String,
        testType: j['test_type'] as String,
        testTypeDisplay: j['test_type_display'] as String,
        owner: (j['owner'] ?? '') as String,
        summary: j['summary'] as String?,
        questionCount: j['question_count'] as int?,
        theoryQuestions: j['theory_questions'] == null
            ? null
            : (j['theory_questions'] as List)
                .map((e) => TheoryQuestionModel.fromJson(e as Map<String, dynamic>))
                .toList(),
      );
}

class TheoryQuestionModel {
  const TheoryQuestionModel({
    required this.id,
    required this.questionNumber,
    required this.questionText,
    required this.modelAnswer,
  });
  final int id;
  final int questionNumber;
  final String questionText;
  final String modelAnswer;

  factory TheoryQuestionModel.fromJson(Map<String, dynamic> j) => TheoryQuestionModel(
        id: j['id'] as int,
        questionNumber: j['question_number'] as int,
        questionText: j['question_text'] as String,
        modelAnswer: j['model_answer'] as String,
      );
}

class CbtOptionModel {
  const CbtOptionModel({
    required this.id,
    required this.label,
    required this.text,
    this.isCorrect,
  });
  final int id;
  final String label;
  final String text;
  final bool? isCorrect; // only present in results, not while taking the test

  factory CbtOptionModel.fromJson(Map<String, dynamic> j) => CbtOptionModel(
        id: j['id'] as int,
        label: j['label'] as String,
        text: j['text'] as String,
        isCorrect: j['is_correct'] as bool?,
      );
}

class CbtQuestionModel {
  const CbtQuestionModel({
    required this.id,
    required this.questionNumber,
    required this.questionText,
    required this.options,
    this.selectedOptionId,
    this.explanation,
  });
  final int id;
  final int questionNumber;
  final String questionText;
  final List<CbtOptionModel> options;
  final int? selectedOptionId;
  final String? explanation;

  factory CbtQuestionModel.fromJson(Map<String, dynamic> j) => CbtQuestionModel(
        id: j['id'] as int,
        questionNumber: j['question_number'] as int,
        questionText: j['question_text'] as String,
        options: (j['options'] as List)
            .map((e) => CbtOptionModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        selectedOptionId: j['selected_option_id'] as int?,
        explanation: j['explanation'] as String?,
      );
}

/// Mirrors studynotes/views.py — upload a PDF, AI reads and summarizes it.
/// Subscriber-only (no pay-per-use, unlike Document Studio), and capped at
/// one summary a day per student to bound Gemini token spend on
/// document-sized input. Also covers the Level/Course library: publishing
/// an already-summarized note with an AI-generated CBT or Theory test, and
/// browsing/taking other students' published notes.
class StudyNotesApiService {
  StudyNotesApiService._();
  static final StudyNotesApiService instance = StudyNotesApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppApiException catch (e) {
      throw StudyNotesException(e.message);
    }
  }

  Future<
      ({
        List<StudyNoteModel> notes,
        bool isSubscriber,
        bool usedToday,
        bool usedAudioToday,
        bool usedPublishToday,
        int maxUploadBytes,
        List<LevelOption> levelChoices,
      })> home() => _run(() async {
        final resp = await _client.request('GET', '/api/studynotes/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (
          notes: (data['notes'] as List)
              .map((e) => StudyNoteModel.fromJson(e as Map<String, dynamic>))
              .toList(),
          isSubscriber: data['is_subscriber'] as bool,
          usedToday: data['used_today'] as bool,
          usedAudioToday: data['used_audio_today'] as bool,
          usedPublishToday: data['used_publish_today'] as bool,
          maxUploadBytes: data['max_upload_bytes'] as int,
          levelChoices: (data['level_choices'] as List)
              .map((e) => LevelOption.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      });

  Future<StudyNoteModel> create({
    required String title,
    required List<int> fileBytes,
    required String filename,
  }) =>
      _run(() async {
        final resp = await _client.requestMultipart(
          '/api/studynotes/create/',
          fields: {'title': title},
          fileField: 'source_file',
          fileBytes: fileBytes,
          filename: filename,
          contentType: 'application/pdf',
        );
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return StudyNoteModel.fromJson(data['note'] as Map<String, dynamic>);
      });

  Future<StudyNoteModel> detail(int noteId) => _run(() async {
        final resp = await _client.request('GET', '/api/studynotes/$noteId/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return StudyNoteModel.fromJson(data['note'] as Map<String, dynamic>);
      });

  Future<void> deleteNote(int noteId) => _run(() async {
        final resp = await _client.request('POST', '/api/studynotes/$noteId/delete/');
        _client.checkOk(resp);
      });

  Future<StudyNoteModel> generate(int noteId) => _run(() async {
        final resp = await _client.request('POST', '/api/studynotes/$noteId/generate/');
        _client.checkOk(
          resp,
          subscriptionStatus: 429,
          subscriptionMessage: "You've used your AI summary for today — come back tomorrow.",
        );
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return StudyNoteModel.fromJson(data['note'] as Map<String, dynamic>);
      });

  Future<StudyNoteModel> generateAudio(int noteId) => _run(() async {
        final resp = await _client.request('POST', '/api/studynotes/$noteId/generate-audio/');
        _client.checkOk(
          resp,
          subscriptionStatus: 429,
          subscriptionMessage: "You've used your audio generation for today — come back tomorrow.",
        );
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return StudyNoteModel.fromJson(data['note'] as Map<String, dynamic>);
      });

  Future<StudyNoteModel> publish(
    int noteId, {
    required String level,
    required String courseName,
    required String testType,
  }) =>
      _run(() async {
        final resp = await _client.request('POST', '/api/studynotes/$noteId/publish/', body: {
          'level': level,
          'course_name': courseName,
          'test_type': testType,
        });
        _client.checkOk(
          resp,
          subscriptionStatus: 429,
          subscriptionMessage: "You've already published a note today — come back tomorrow.",
        );
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return StudyNoteModel.fromJson(data['note'] as Map<String, dynamic>);
      });

  // ── Level/Course library ────────────────────────────────────────────────
  Future<({List<LibraryNoteModel> notes, List<LevelOption> levelChoices})> library(
          {String? level}) =>
      _run(() async {
        final path = level == null || level.isEmpty
            ? '/api/studynotes/library/'
            : '/api/studynotes/library/?level=$level';
        final resp = await _client.request('GET', path);
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (
          notes: (data['notes'] as List)
              .map((e) => LibraryNoteModel.fromJson(e as Map<String, dynamic>))
              .toList(),
          levelChoices: (data['level_choices'] as List)
              .map((e) => LevelOption.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      });

  Future<LibraryNoteModel> libraryDetail(int noteId) => _run(() async {
        final resp = await _client.request('GET', '/api/studynotes/library/$noteId/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return LibraryNoteModel.fromJson(data['note'] as Map<String, dynamic>);
      });

  Future<({String examId, List<CbtQuestionModel> questions})> cbtStart(int noteId) =>
      _run(() async {
        final resp =
            await _client.request('POST', '/api/studynotes/library/$noteId/cbt/start/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (
          examId: data['exam_id'] as String,
          questions: (data['questions'] as List)
              .map((e) => CbtQuestionModel.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      });

  Future<void> cbtSubmit(String examId, Map<int, int> answers) => _run(() async {
        final resp = await _client.request(
          'POST', '/api/studynotes/cbt/$examId/submit/',
          body: {'answers': answers.map((qId, optId) => MapEntry(qId.toString(), optId))},
        );
        _client.checkOk(resp);
      });

  Future<({double score, int totalMarks, List<CbtQuestionModel> questions})> cbtResults(
          String examId) =>
      _run(() async {
        final resp = await _client.request('GET', '/api/studynotes/cbt/$examId/results/');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (
          score: (data['score'] as num).toDouble(),
          totalMarks: data['total_marks'] as int,
          questions: (data['questions'] as List)
              .map((e) => CbtQuestionModel.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      });
}
