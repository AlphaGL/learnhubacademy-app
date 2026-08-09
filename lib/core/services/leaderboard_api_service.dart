import 'dart:convert';

import 'app_api_client.dart';

class LeaderboardException implements Exception {
  const LeaderboardException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LeaderboardRow {
  const LeaderboardRow({
    required this.studentId,
    required this.name,
    required this.examsTaken,
    required this.averageScore,
    required this.rank,
  });

  final int studentId;
  final String name;
  final int examsTaken;
  final double averageScore;
  final int rank;

  factory LeaderboardRow.fromJson(Map<String, dynamic> json) => LeaderboardRow(
        studentId: json['student_id'] as int,
        name: json['name'] as String,
        examsTaken: json['exams_taken'] as int,
        averageScore: (json['average_score'] as num).toDouble(),
        rank: json['rank'] as int,
      );
}

class LeaderboardResult {
  const LeaderboardResult({required this.rows, required this.myRow});
  final List<LeaderboardRow> rows;
  final LeaderboardRow? myRow;
}

/// Ranks students by average completed-exam score — same aggregation as
/// the website's /leaderboard/ page (learning/views.py _leaderboard_full).
class LeaderboardApiService {
  LeaderboardApiService._();
  static final LeaderboardApiService instance = LeaderboardApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<LeaderboardResult> leaderboard() async {
    try {
      final resp = await _client.request('GET', '/api/leaderboard/');
      _client.checkOk(resp);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return LeaderboardResult(
        rows: (data['rows'] as List)
            .map((e) => LeaderboardRow.fromJson(e as Map<String, dynamic>))
            .toList(),
        myRow: data['my_row'] != null
            ? LeaderboardRow.fromJson(data['my_row'] as Map<String, dynamic>)
            : null,
      );
    } on AppApiException catch (e) {
      throw LeaderboardException(e.message);
    }
  }
}
