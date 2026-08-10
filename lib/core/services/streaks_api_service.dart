import 'dart:convert';

import 'app_api_client.dart';

class StreaksException implements Exception {
  const StreaksException(this.message);
  final String message;
  @override
  String toString() => message;
}

class Badge {
  const Badge({required this.code, required this.label, required this.icon});
  final String code;
  final String label;
  final String icon; // Bootstrap-icon-style code from the backend, unused for display icon mapping

  factory Badge.fromJson(Map<String, dynamic> json) => Badge(
        code: json['code'] as String,
        label: json['label'] as String,
        icon: json['icon'] as String,
      );
}

class StreaksResult {
  const StreaksResult({
    required this.currentStreak,
    required this.longestStreak,
    required this.examsCompleted,
    required this.overallAccuracy,
    required this.badges,
  });

  final int currentStreak;
  final int longestStreak;
  final int examsCompleted;
  final double? overallAccuracy;
  final List<Badge> badges;

  factory StreaksResult.fromJson(Map<String, dynamic> json) => StreaksResult(
        currentStreak: json['current_streak'] as int,
        longestStreak: json['longest_streak'] as int,
        examsCompleted: json['exams_completed'] as int,
        overallAccuracy: (json['overall_accuracy'] as num?)?.toDouble(),
        badges: (json['badges'] as List)
            .map((e) => Badge.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Mirrors the website's /streaks/ page (learning/views.py
/// _record_streak_activity/_badges_for) — the streak itself is recorded
/// server-side whenever an exam/quiz is submitted, so this service only
/// ever reads the current state.
class StreaksApiService {
  StreaksApiService._();
  static final StreaksApiService instance = StreaksApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<StreaksResult> streaks() async {
    try {
      final resp = await _client.request('GET', '/api/streaks/');
      _client.checkOk(resp);
      return StreaksResult.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    } on AppApiException catch (e) {
      throw StreaksException(e.message);
    }
  }
}
