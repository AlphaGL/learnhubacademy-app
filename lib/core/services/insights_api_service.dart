import 'dart:convert';

import 'app_api_client.dart';

class InsightsException implements Exception {
  const InsightsException(this.message);
  final String message;
  @override
  String toString() => message;
}

enum WeakTopicKind { material, subject }

class WeakTopic {
  const WeakTopic({
    required this.kind,
    required this.materialId,
    required this.subjectId,
    required this.title,
    required this.subjectName,
    required this.attempts,
    required this.accuracy,
  });

  final WeakTopicKind kind;
  final int? materialId;
  final int subjectId;
  final String title;
  final String subjectName;
  final int attempts;
  final double accuracy;

  factory WeakTopic.fromJson(Map<String, dynamic> json) => WeakTopic(
        kind: json['kind'] == 'material' ? WeakTopicKind.material : WeakTopicKind.subject,
        materialId: json['material_id'] as int?,
        subjectId: json['subject_id'] as int,
        title: json['title'] as String,
        subjectName: json['subject_name'] as String,
        attempts: json['attempts'] as int,
        accuracy: (json['accuracy'] as num).toDouble(),
      );
}

class WeakTopicsResult {
  const WeakTopicsResult({required this.topics, required this.overallAccuracy});
  final List<WeakTopic> topics;
  final double? overallAccuracy;
}

/// Ranks the student's own exam/quiz accuracy by material/subject — same
/// aggregation the website's /insights/ page uses (learning/views.py
/// _weak_topics), reusing the exam-answer data already recorded, so this
/// needed no new tracking on either side.
class InsightsApiService {
  InsightsApiService._();
  static final InsightsApiService instance = InsightsApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<WeakTopicsResult> weakTopics() async {
    try {
      final resp = await _client.request('GET', '/api/insights/weak-topics/');
      _client.checkOk(resp);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return WeakTopicsResult(
        topics: (data['topics'] as List)
            .map((e) => WeakTopic.fromJson(e as Map<String, dynamic>))
            .toList(),
        overallAccuracy: (data['overall_accuracy'] as num?)?.toDouble(),
      );
    } on AppApiException catch (e) {
      throw InsightsException(e.message);
    }
  }
}
