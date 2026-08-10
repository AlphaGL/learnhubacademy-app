import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'supabase_service.dart';

class AppApiException implements Exception {
  const AppApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Shared bearer-token JSON client for the website's app-facing API
/// (learning/api_auth.py) — every app feature that talks to Django (exams,
/// AI tutor, and future ones) goes through here, so token fetch/refresh
/// lives in exactly one place instead of being copied per feature.
class AppApiClient {
  AppApiClient._();
  static final AppApiClient instance = AppApiClient._();

  String? _token;

  /// Subscription status as of the last token fetch — Django is the single
  /// source of truth (same Subscription model the website's Paystack
  /// webhook updates), so this is what gates paid content in the app too,
  /// not Supabase's app_profiles.is_subscribed (which nothing ever writes
  /// to from a real payment, and which a signed-in user could otherwise
  /// self-edit via the client SDK).
  bool? _isSubscribed;
  bool? get cachedIsSubscribed => _isSubscribed;

  Future<String?> _fetchToken() async {
    final session = SupabaseService.client.auth.currentSession;
    if (session == null) return null;

    final resp = await http.post(
      Uri.parse('${AppConfig.siteUrl}/api/exam-token/'),
      headers: {'Authorization': 'Bearer ${session.accessToken}'},
    ).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) return null;
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    _isSubscribed = body['is_subscribed'] as bool?;
    return body['token'] as String?;
  }

  /// Re-fetches the token (and with it, subscription status) from Django.
  /// Cheap enough to call whenever a screen needs an up-to-date answer —
  /// e.g. right after returning from the website's payment flow.
  Future<bool> refreshSubscriptionStatus() async {
    _token = await _fetchToken();
    return _isSubscribed ?? false;
  }

  Future<http.Response> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    Future<http.Response> attempt(String token) {
      final uri = Uri.parse('${AppConfig.siteUrl}$path');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      return method == 'GET'
          ? http.get(uri, headers: headers).timeout(const Duration(seconds: 15))
          : http
              .post(uri, headers: headers, body: body != null ? jsonEncode(body) : null)
              .timeout(const Duration(seconds: 15));
    }

    _token ??= await _fetchToken();
    if (_token == null) {
      throw const AppApiException('Sign in again to use this feature.');
    }

    var response = await attempt(_token!);
    if (response.statusCode == 401) {
      // Token expired or was never valid — fetch a fresh one, once.
      _token = await _fetchToken();
      if (_token == null) {
        throw const AppApiException('Sign in again to use this feature.');
      }
      response = await attempt(_token!);
    }
    return response;
  }

  /// Raises [AppApiException] for non-2xx responses, using the server's
  /// `error` field when present. [subscriptionStatus]/[subscriptionMessage]
  /// let callers customize the 402 case (only exams gate on subscription
  /// today), everything else uses a generic message.
  void checkOk(
    http.Response response, {
    int subscriptionStatus = 402,
    String subscriptionMessage = 'A subscription is required for this feature.',
  }) {
    if (response.statusCode == subscriptionStatus) {
      throw AppApiException(subscriptionMessage);
    }
    if (response.statusCode >= 400) {
      var message = 'Something went wrong (${response.statusCode}).';
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['error'] is String) message = data['error'] as String;
      } catch (_) {/* fall back to the generic message above */}
      throw AppApiException(message);
    }
  }

  /// Called on sign-out so the next signed-in user (on a shared device)
  /// never accidentally reuses a stale token.
  void clearToken() {
    _token = null;
    _isSubscribed = null;
    debugPrint('App API token cleared');
  }
}
