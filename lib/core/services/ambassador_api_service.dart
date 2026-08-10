import 'dart:convert';

import 'app_api_client.dart';

class AmbassadorException implements Exception {
  const AmbassadorException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AmbassadorTier {
  const AmbassadorTier({
    required this.label,
    required this.minReferrals,
    required this.commissionRate,
    required this.perks,
  });
  final String label;
  final int minReferrals;
  final String commissionRate;
  final List<String> perks;

  factory AmbassadorTier.fromJson(Map<String, dynamic> j) => AmbassadorTier(
        label: j['label'] as String,
        minReferrals: j['min_referrals'] as int,
        commissionRate: j['commission_rate'] as String,
        perks: (j['perks'] as List).cast<String>(),
      );
}

class AmbassadorStatus {
  const AmbassadorStatus({
    required this.isAmbassador,
    required this.hasSubscription,
    required this.tierConfig,
    required this.holdDays,
    required this.minPayout,
  });
  final bool isAmbassador;
  final bool hasSubscription;
  final Map<String, AmbassadorTier> tierConfig;
  final int holdDays;
  final String minPayout;

  factory AmbassadorStatus.fromJson(Map<String, dynamic> j) => AmbassadorStatus(
        isAmbassador: j['is_ambassador'] as bool,
        hasSubscription: j['has_subscription'] as bool,
        tierConfig: (j['tier_config'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, AmbassadorTier.fromJson(v as Map<String, dynamic>))),
        holdDays: j['hold_days'] as int,
        minPayout: j['min_payout'] as String,
      );
}

class NextTierInfo {
  const NextTierInfo({
    required this.label,
    required this.minReferrals,
    required this.commissionRate,
    required this.needed,
  });
  final String label;
  final int minReferrals;
  final String commissionRate;
  final int needed;

  factory NextTierInfo.fromJson(Map<String, dynamic> j) => NextTierInfo(
        label: j['label'] as String,
        minReferrals: j['min_referrals'] as int,
        commissionRate: j['commission_rate'] as String,
        needed: j['needed'] as int,
      );
}

class Referral {
  const Referral({
    required this.referredEmail,
    required this.status,
    required this.registeredAt,
    required this.commissionAmount,
    required this.isPaidOut,
  });
  final String referredEmail;
  final String status;
  final String registeredAt;
  final String? commissionAmount;
  final bool isPaidOut;

  factory Referral.fromJson(Map<String, dynamic> j) => Referral(
        referredEmail: j['referred_email'] as String,
        status: j['status'] as String,
        registeredAt: j['registered_at'] as String,
        commissionAmount: j['commission_amount'] as String?,
        isPaidOut: j['is_paid_out'] as bool,
      );
}

class AmbassadorDashboard {
  const AmbassadorDashboard({
    required this.referralCode,
    required this.referralUrl,
    required this.tier,
    required this.tierLabel,
    required this.totalEarnings,
    required this.totalPaidOut,
    required this.pendingEarnings,
    required this.progressPct,
    required this.nextTier,
    required this.stats,
    required this.recentReferrals,
    required this.unreadNotifications,
  });
  final String referralCode;
  final String referralUrl;
  final String tier;
  final String tierLabel;
  final String totalEarnings;
  final String totalPaidOut;
  final String pendingEarnings;
  final int progressPct;
  final NextTierInfo? nextTier;
  final Map<String, dynamic> stats;
  final List<Referral> recentReferrals;
  final int unreadNotifications;

  factory AmbassadorDashboard.fromJson(Map<String, dynamic> j) => AmbassadorDashboard(
        referralCode: j['referral_code'] as String,
        referralUrl: j['referral_url'] as String,
        tier: j['tier'] as String,
        tierLabel: j['tier_label'] as String,
        totalEarnings: j['total_earnings'] as String,
        totalPaidOut: j['total_paid_out'] as String,
        pendingEarnings: j['pending_earnings'] as String,
        progressPct: j['progress_pct'] as int,
        nextTier: j['next_tier'] == null
            ? null
            : NextTierInfo.fromJson(j['next_tier'] as Map<String, dynamic>),
        stats: j['stats'] as Map<String, dynamic>,
        recentReferrals: (j['recent_referrals'] as List)
            .map((e) => Referral.fromJson(e as Map<String, dynamic>))
            .toList(),
        unreadNotifications: j['unread_notifications'] as int,
      );
}

class Payout {
  const Payout({
    required this.amount,
    required this.status,
    required this.initiatedAt,
  });
  final String amount;
  final String status;
  final String initiatedAt;

  factory Payout.fromJson(Map<String, dynamic> j) => Payout(
        amount: j['amount'] as String,
        status: j['status'] as String,
        initiatedAt: j['initiated_at'] as String,
      );
}

class PayoutsResult {
  const PayoutsResult({
    required this.payouts,
    required this.hasBankDetails,
    required this.hasOpenRequest,
    required this.canRequest,
    required this.pendingEarnings,
    required this.minPayout,
  });
  final List<Payout> payouts;
  final bool hasBankDetails;
  final bool hasOpenRequest;
  final bool canRequest;
  final String pendingEarnings;
  final String minPayout;

  factory PayoutsResult.fromJson(Map<String, dynamic> j) => PayoutsResult(
        payouts:
            (j['payouts'] as List).map((e) => Payout.fromJson(e as Map<String, dynamic>)).toList(),
        hasBankDetails: j['has_bank_details'] as bool,
        hasOpenRequest: j['has_open_request'] as bool,
        canRequest: j['can_request'] as bool,
        pendingEarnings: j['pending_earnings'] as String,
        minPayout: j['min_payout'] as String,
      );
}

/// Mirrors ambassador/views.py — the website's referral programme, now
/// reachable from the app via the same bearer-token API the exam feature
/// established.
class AmbassadorApiService {
  AmbassadorApiService._();
  static final AmbassadorApiService instance = AmbassadorApiService._();

  final AppApiClient _client = AppApiClient.instance;

  Future<T> _run<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on AppApiException catch (e) {
      throw AmbassadorException(e.message);
    }
  }

  Future<AmbassadorStatus> status() => _run(() async {
        final resp = await _client.request('GET', '/api/ambassador/status/');
        _client.checkOk(resp);
        return AmbassadorStatus.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });

  Future<void> join() => _run(() async {
        final resp = await _client.request('POST', '/api/ambassador/join/');
        _client.checkOk(resp,
            subscriptionMessage: 'An active subscription is required to join.');
      });

  Future<AmbassadorDashboard> dashboard() => _run(() async {
        final resp = await _client.request('GET', '/api/ambassador/dashboard/');
        _client.checkOk(resp);
        return AmbassadorDashboard.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });

  Future<List<Referral>> referrals({String status = 'all'}) => _run(() async {
        final resp = await _client.request('GET', '/api/ambassador/referrals/?status=$status');
        _client.checkOk(resp);
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return (data['referrals'] as List)
            .map((e) => Referral.fromJson(e as Map<String, dynamic>))
            .toList();
      });

  Future<PayoutsResult> payouts() => _run(() async {
        final resp = await _client.request('GET', '/api/ambassador/payouts/');
        _client.checkOk(resp);
        return PayoutsResult.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
      });

  Future<void> requestPayout() => _run(() async {
        final resp = await _client.request('POST', '/api/ambassador/payouts/request/');
        _client.checkOk(resp);
      });

  Future<Map<String, dynamic>> getSettings() => _run(() async {
        final resp = await _client.request('GET', '/api/ambassador/settings/');
        _client.checkOk(resp);
        return jsonDecode(resp.body) as Map<String, dynamic>;
      });

  Future<void> saveSettings({
    required String bankName,
    required String accountNumber,
    required String accountName,
    required String payoutPreference,
  }) =>
      _run(() async {
        final resp = await _client.request('POST', '/api/ambassador/settings/', body: {
          'bank_name': bankName,
          'account_number': accountNumber,
          'account_name': accountName,
          'payout_preference': payoutPreference,
        });
        _client.checkOk(resp);
      });
}
