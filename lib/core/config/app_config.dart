/// Central configuration.
///
/// Supabase URL + anon key are PUBLIC values (safe to ship in a client app)
/// because access is governed by Row-Level Security on the database side.
/// They are still injected at build time via --dart-define so you can keep
/// dev/prod separate and out of source control.
///
/// Run / build like:
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJhbGci...
///
/// Or create a dart_define.json and pass --dart-define-from-file=dart_define.json
class AppConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Web OAuth client id from Google Cloud / Firebase (used for native Google
  /// sign-in that we exchange for a Supabase session). See docs/FIREBASE_SETUP.md.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// Public Cloudinary cloud name — used to build/transform image URLs.
  static const String cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'ddvoehikn',
  );

  /// Paystack PUBLIC key — safe in-app. The SECRET key must stay on the server.
  static const String paystackPublicKey = String.fromEnvironment(
    'PAYSTACK_PUBLIC_KEY',
    defaultValue: '',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const String appName = 'LearnHub Academy';

  /// Django creates tables as `<app_label>_<model>`. These are the ones the
  /// app reads directly through Supabase/PostgREST.
  static const String tblSubject = 'learning_subject';
  static const String tblMaterial = 'learning_material';
  static const String tblMaterialImage = 'learning_materialimage';
  static const String tblSubscription = 'learning_subscription';
  static const String tblStudentProfile = 'learning_studentprofile';

  /// App-owned table (created by us, see sql/supabase_setup.sql) that links a
  /// Supabase Auth user to their LearnHub profile + device push token.
  static const String tblAppProfile = 'app_profiles';
  static const String tblDeviceToken = 'app_device_tokens';
  static const String tblCgpaRecord = 'app_cgpa_records';

  /// Drives the in-app "update available" check (no Play Store yet — see
  /// UpdateService + sql/supabase_setup.sql section 6). Rows are published by
  /// the GitHub Actions release workflow, not by the app.
  static const String tblAppRelease = 'app_release';
}
