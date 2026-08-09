import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Thin wrapper around the Supabase client so the rest of the app never
/// imports Supabase directly and we have one place to init.
class SupabaseService {
  SupabaseService._();

  static Future<void> init() async {
    if (!AppConfig.isConfigured) {
      // Fail loud in debug so a misconfigured build is obvious.
      throw StateError(
        'Supabase is not configured. Pass --dart-define=SUPABASE_URL=... and '
        '--dart-define=SUPABASE_ANON_KEY=... See docs/SUPABASE_SETUP.md.',
      );
    }
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static SupabaseClient get client => Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  static bool get isSignedIn => currentUser != null;
}
