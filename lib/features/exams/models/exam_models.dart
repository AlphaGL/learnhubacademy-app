/// Which content family an exam session belongs to — mirrors the two
/// parallel model families on the website (Exam/Question/Option vs
/// MaterialExam/MaterialQuestion/MaterialOption).
enum ExamKind { examYear, material }

class ExamYearSummary {
  const ExamYearSummary({
    required this.id,
    required this.year,
    required this.session,
    required this.description,
    required this.questionCount,
  });

  final int id;
  final int year;
  final String session;
  final String description;
  final int questionCount;

  factory ExamYearSummary.fromJson(Map<String, dynamic> j) => ExamYearSummary(
        id: j['id'] as int,
        year: j['year'] as int,
        session: (j['session'] ?? '') as String,
        description: (j['description'] ?? '') as String,
        questionCount: (j['question_count'] ?? 0) as int,
      );

  String get label => session.isNotEmpty ? '$year ($session)' : '$year';
}

class ExamOption {
  const ExamOption({
    required this.id,
    required this.label,
    required this.text,
    this.isCorrect,
  });

  final int id;
  final String label;
  final String text;
  final bool? isCorrect; // only ever present once the exam is over

  factory ExamOption.fromJson(Map<String, dynamic> j) => ExamOption(
        id: j['id'] as int,
        label: (j['label'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        isCorrect: j['is_correct'] as bool?,
      );
}

class ExamQuestion {
  const ExamQuestion({
    required this.id,
    required this.number,
    required this.text,
    required this.marks,
    required this.options,
  });

  final int id;
  final int number;
  final String text;
  final int marks;
  final List<ExamOption> options;

  factory ExamQuestion.fromJson(Map<String, dynamic> j) => ExamQuestion(
        id: j['id'] as int,
        number: j['question_number'] as int,
        text: (j['question_text'] ?? '') as String,
        marks: (j['marks'] ?? 1) as int,
        options: (j['options'] as List)
            .map((o) => ExamOption.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
}

class ExamSession {
  const ExamSession({
    required this.kind,
    required this.examId,
    required this.mode,
    required this.durationMinutes,
    required this.questions,
    required this.answers,
  });

  final ExamKind kind;
  final String examId;
  final String mode; // 'exam' | 'test'
  final int durationMinutes;
  final List<ExamQuestion> questions;
  final Map<int, int> answers; // question id -> previously-selected option id

  bool get isTestMode => mode == 'test';

  factory ExamSession.fromJson(Map<String, dynamic> j, ExamKind kind) {
    final rawAnswers = j['answers'] as Map<String, dynamic>?;
    return ExamSession(
      kind: kind,
      examId: j['exam_id'] as String,
      mode: j['mode'] as String,
      durationMinutes: (j['duration_minutes'] ?? 30) as int,
      questions: (j['questions'] as List)
          .map((q) => ExamQuestion.fromJson(q as Map<String, dynamic>))
          .toList(),
      answers: rawAnswers == null
          ? {}
          : rawAnswers.map((k, v) => MapEntry(int.parse(k), v as int)),
    );
  }
}

class ExplanationData {
  const ExplanationData({required this.text, required this.resources});

  final String text;
  final String resources;

  factory ExplanationData.fromJson(Map<String, dynamic> j) => ExplanationData(
        text: (j['text'] ?? '') as String,
        resources: (j['resources'] ?? '') as String,
      );
}

class AnswerResult {
  const AnswerResult({
    required this.isCorrect,
    required this.answeredCount,
    required this.totalQuestions,
    this.correctOptionId,
    this.explanation,
  });

  final bool isCorrect;
  final int answeredCount;
  final int totalQuestions;
  final int? correctOptionId;
  final ExplanationData? explanation;

  factory AnswerResult.fromJson(Map<String, dynamic> j) => AnswerResult(
        isCorrect: (j['is_correct'] ?? false) as bool,
        answeredCount: (j['answered_count'] ?? 0) as int,
        totalQuestions: (j['total_questions'] ?? 0) as int,
        correctOptionId: j['correct_option_id'] as int?,
        explanation: j['explanation'] != null
            ? ExplanationData.fromJson(j['explanation'] as Map<String, dynamic>)
            : null,
      );
}

class ExamResultQuestion {
  const ExamResultQuestion({
    required this.questionId,
    required this.number,
    required this.text,
    required this.selectedOptionId,
    required this.isCorrect,
    required this.options,
    this.explanation,
  });

  final int questionId;
  final int number;
  final String text;

  /// Null when the student never answered this question (left the exam
  /// early, or time ran out) — still counted as wrong, just with nothing
  /// to highlight as "your answer".
  final int? selectedOptionId;
  final bool isCorrect;
  final List<ExamOption> options;
  final ExplanationData? explanation;

  factory ExamResultQuestion.fromJson(Map<String, dynamic> j) => ExamResultQuestion(
        questionId: j['question_id'] as int,
        number: j['question_number'] as int,
        text: (j['question_text'] ?? '') as String,
        selectedOptionId: j['selected_option_id'] as int?,
        isCorrect: (j['is_correct'] ?? false) as bool,
        options: (j['options'] as List)
            .map((o) => ExamOption.fromJson(o as Map<String, dynamic>))
            .toList(),
        explanation: j['explanation'] != null
            ? ExplanationData.fromJson(j['explanation'] as Map<String, dynamic>)
            : null,
      );
}

class ExamResults {
  const ExamResults({
    required this.examId,
    required this.mode,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.questions,
  });

  final String examId;
  final String mode;
  final double score;
  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final List<ExamResultQuestion> questions;

  factory ExamResults.fromJson(Map<String, dynamic> j) => ExamResults(
        examId: j['exam_id'] as String,
        mode: (j['mode'] ?? '') as String,
        score: ((j['score'] as num?) ?? 0).toDouble(),
        totalQuestions: (j['total_questions'] ?? 0) as int,
        correctAnswers: (j['correct_answers'] ?? 0) as int,
        incorrectAnswers: (j['incorrect_answers'] ?? 0) as int,
        questions: (j['questions'] as List)
            .map((q) => ExamResultQuestion.fromJson(q as Map<String, dynamic>))
            .toList(),
      );
}

class ExamHistoryEntry {
  const ExamHistoryEntry({
    required this.examId,
    required this.kind,
    required this.title,
    required this.mode,
    this.score,
    this.submittedAt,
  });

  final String examId;
  final String kind; // 'exam_year' | 'material'
  final String title;
  final String mode;
  final double? score;
  final DateTime? submittedAt;

  factory ExamHistoryEntry.fromJson(Map<String, dynamic> j) => ExamHistoryEntry(
        examId: j['exam_id'] as String,
        kind: (j['kind'] ?? '') as String,
        title: (j['title'] ?? '') as String,
        mode: (j['mode'] ?? '') as String,
        score: (j['score'] as num?)?.toDouble(),
        submittedAt: j['submitted_at'] != null
            ? DateTime.tryParse(j['submitted_at'] as String)
            : null,
      );
}

class ExamException implements Exception {
  const ExamException(this.message);
  final String message;
  @override
  String toString() => message;
}
