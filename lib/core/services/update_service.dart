import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../config/app_config.dart';
import 'supabase_service.dart';

/// A row in the Supabase `app_release` table describing the latest build,
/// published by the GitHub Actions release workflow.
class AppRelease {
  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.mandatory,
    required this.notes,
  });

  final int versionCode; // matches the APK's build number
  final String versionName; // e.g. "1.1.0"
  final String apkUrl; // Cloudflare R2 download link
  final bool mandatory; // if true, the update dialog can't be dismissed
  final String notes; // "what's new", shown in the dialog

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
        versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
        versionName: (json['version_name'] as String?) ?? '',
        apkUrl: (json['apk_url'] as String?) ?? '',
        mandatory: (json['mandatory'] as bool?) ?? false,
        notes: (json['notes'] as String?) ?? '',
      );
}

/// Checks Supabase for a newer published build than the one installed.
///
/// The app isn't on the Play Store yet, so there's no store-driven
/// auto-update — this is the substitute: the release workflow publishes a
/// row per build, and the app compares it to its own build number on launch.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Returns the latest release if it's newer than the installed build,
  /// otherwise null. Never throws.
  Future<AppRelease?> check() async {
    try {
      final data = await SupabaseService.client
          .from(AppConfig.tblAppRelease)
          .select()
          .order('version_code', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;

      final release = AppRelease.fromJson(data);
      if (release.apkUrl.trim().isEmpty) return null;

      final info = await PackageInfo.fromPlatform();
      final installed = int.tryParse(info.buildNumber) ?? 0;

      return release.versionCode > installed ? release : null;
    } catch (e) {
      // Never let a flaky network/table check block app startup.
      debugPrint('Update check skipped/failed: $e');
      return null;
    }
  }
}
