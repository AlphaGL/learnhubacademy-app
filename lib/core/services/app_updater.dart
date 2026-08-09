import 'package:background_downloader/background_downloader.dart';

/// Downloads a new APK inside the app and launches the system installer, so
/// users update without leaving LearnHub or going through an external browser.
///
/// Requires the REQUEST_INSTALL_PACKAGES permission in AndroidManifest.
class AppUpdater {
  AppUpdater._();
  static final AppUpdater instance = AppUpdater._();

  /// Downloads [apkUrl] and opens the system installer.
  /// Calls [onProgress] with 0..1. Returns null on success, else an error label.
  Future<String?> downloadAndInstall(
    String apkUrl, {
    required void Function(double) onProgress,
  }) async {
    try {
      final task = DownloadTask(
        url: apkUrl,
        filename: 'learnhub-update.apk',
        directory: 'updates',
        baseDirectory: BaseDirectory.applicationSupport,
        updates: Updates.statusAndProgress,
        allowPause: false,
        retries: 1,
      );
      final result = await FileDownloader().download(
        task,
        onProgress: (p) {
          if (p >= 0) onProgress(p.clamp(0.0, 1.0));
        },
      );
      if (result.status != TaskStatus.complete) {
        return 'Download ${result.status.name}';
      }
      final opened = await FileDownloader().openFile(
        task: task,
        mimeType: 'application/vnd.android.package-archive',
      );
      return opened ? null : 'Could not open installer';
    } catch (_) {
      return 'Update failed';
    }
  }
}
