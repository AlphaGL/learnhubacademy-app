import 'dart:convert';

import 'app_api_client.dart';

class AwardsException implements Exception {
  const AwardsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AwardSeason {
  const AwardSeason({
    required this.id,
    required this.title,
    required this.description,
    required this.paidVotePrice,
  });
  final int id;
  final String title;
  final String description;
  final String paidVotePrice;

  factory AwardSeason.fromJson(Map<String, dynamic> j) => AwardSeason(
        id: j['id'] as int,
        title: j['title'] as String,
        description: (j['description'] ?? '') as String,
        paidVotePrice: j['paid_vote_price'] as String,
      );
}

class CourseRep {
  const CourseRep({
    required this.id,
    required this.name,
    required this.department,
    required this.photo,
    required this.quote,
    required this.rawVoteCount,
    required this.votePercentage,
    required this.rank,
    required this.rankLabel,
  });
  final int id;
  final String name;
  final String department;
  final String photo;
  final String quote;
  final int rawVoteCount;
  final double votePercentage;
  final int? rank;
  final String rankLabel;

  factory CourseRep.fromJson(Map<String, dynamic> j) => CourseRep(
        id: j['id'] as int,
        name: j['name'] as String,
        department: (j['department'] ?? '') as String,
        photo: (j['photo'] ?? '') as String,
        quote: (j['quote'] ?? '') as String,
        rawVoteCount: j['raw_vote_count'] as int,
        votePercentage: (j['vote_percentage'] as num).toDouble(),
        rank: j['rank'] as int?,
        rankLabel: (j['rank_label'] ?? '') as String,
      );
}

class AwardFaculty {
  const AwardFaculty({required this.id, required this.name, required this.reps});
  final int id;
  final String name;
  final List<CourseRep> reps;

  factory AwardFaculty.fromJson(Map<String, dynamic> j) => AwardFaculty(
        id: j['id'] as int,
        name: j['name'] as String,
        reps: (j['reps'] as List).map((e) => CourseRep.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class AwardsHome {
  const AwardsHome({
    required this.season,
    required this.faculties,
    required this.isSubscriber,
    required this.subscriberHasVoted,
  });
  final AwardSeason? season;
  final List<AwardFaculty> faculties;
  final bool isSubscriber;
  final bool subscriberHasVoted;

  factory AwardsHome.fromJson(Map<String, dynamic> j) => AwardsHome(
        season: j['season'] == null ? null : AwardSeason.fromJson(j['season'] as Map<String, dynamic>),
        faculties: (j['faculties'] as List)
            .map((e) => AwardFaculty.fromJson(e as Map<String, dynamic>))
            .toList(),
        isSubscriber: j['is_subscriber'] as bool,
        subscriberHasVoted: j['subscriber_has_voted'] as bool,
      );
}

/// Mirrors awards/views.py — the website's Excellence Awards voting.
class AwardsApiService {
  AwardsApiService._();
  static final AwardsApiService instance = AwardsApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppApiException catch (e) {
      throw AwardsException(e.message);
    }
  }

  Future<AwardsHome> home() => _run(() async {
        final resp = await _client.request('GET', '/api/awards/home/');
        _client.checkOk(resp);
        return AwardsHome.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });

  Future<void> castVote(int repId) => _run(() async {
        final resp = await _client.request('POST', '/api/awards/vote/$repId/');
        _client.checkOk(resp,
            subscriptionMessage: 'Subscriber vote requires an active LearnHub subscription.');
      });

  Future<String> initiatePayment(int repId, int quantity) => _run(() async {
        final resp = await _client.request('POST', '/api/awards/vote/$repId/pay/',
            body: {'quantity': quantity});
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['authorization_url'] as String;
      });
}
