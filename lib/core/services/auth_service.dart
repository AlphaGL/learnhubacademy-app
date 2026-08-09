import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'supabase_service.dart';

/// All authentication goes through Supabase Auth so that database Row-Level
/// Security (which keys off auth.uid()) works. Google sign-in is performed
/// natively and exchanged for a Supabase session.
class AuthService extends ChangeNotifier {
  AuthService() {
    _sub = SupabaseService.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription _sub;

  User? get user => SupabaseService.currentUser;
  bool get isSignedIn => user != null;

  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) {
    return SupabaseService.client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        if (phone != null && phone.isNotEmpty) 'phone_number': phone,
      },
    );
  }

  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with phone + password, matching the website's login flow.
  /// Supabase Auth itself only signs in by email (or phone via OTP, not
  /// password), so this first resolves the phone number to its account's
  /// email via the get_email_for_phone RPC, then signs in normally.
  ///
  /// If no Supabase account exists for that phone yet, it may still be a
  /// valid website (Django) account — in that case, ask the website to
  /// verify it and provision a matching Supabase account, then retry once.
  /// This is what makes one phone+password work on both the app and site.
  Future<AuthResponse> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    var email = await _emailForPhone(phone);

    if (email == null) {
      final bridged = await _bridgeFromWebsite(phone, password);
      if (bridged) {
        email = await _emailForPhone(phone);
      }
    }

    if (email == null || email.isEmpty) {
      throw const AuthException('No account found with that phone number.');
    }
    return SupabaseService.client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<String?> _emailForPhone(String phone) async {
    return await SupabaseService.client
        .rpc('get_email_for_phone', params: {'p_phone': phone}) as String?;
  }

  /// Asks the website to verify phone+password against its own (Django)
  /// accounts and, if valid, create a matching Supabase account. Returns
  /// false (never throws) on any failure — the caller falls through to the
  /// normal "no account found" error either way.
  Future<bool> _bridgeFromWebsite(String phone, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.siteUrl}/api/bridge-login/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone_number': phone, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['bridged'] == true;
    } catch (e) {
      debugPrint('Website account bridge skipped/failed: $e');
      return false;
    }
  }

  /// Resets a forgotten password by confirming email + phone together —
  /// mirrors the website's two-step identity verification (no email link).
  /// Throws if the email/phone pair doesn't match an existing account.
  Future<void> resetPasswordWithIdentity({
    required String email,
    required String phone,
    required String newPassword,
  }) async {
    final ok = await SupabaseService.client.rpc(
      'reset_password_with_identity',
      params: {
        'p_email': email,
        'p_phone': phone,
        'p_new_password': newPassword,
      },
    ) as bool;
    if (!ok) {
      throw const AuthException(
          "We couldn't verify that email and phone number together.");
    }
  }

  /// Native Google sign-in → Supabase session.
  /// Requires GOOGLE_WEB_CLIENT_ID (see docs/FIREBASE_SETUP.md).
  Future<AuthResponse> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: AppConfig.googleWebClientId.isNotEmpty
          ? AppConfig.googleWebClientId
          : null,
    );
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw const AuthException('Google sign-in was cancelled.');
    }
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null) {
      throw const AuthException('No ID token from Google.');
    }
    return SupabaseService.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {/* not signed in via google — ignore */}
    await SupabaseService.client.auth.signOut();
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
