import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/app_updater.dart';
import '../../core/services/update_service.dart';
import '../../core/theme/app_theme.dart';

/// Branded "update available" dialog. Tapping "Update Now" downloads the APK
/// in-app (with a progress bar) and hands off to the system installer.
///
/// When [release.mandatory] is true, the dialog cannot be dismissed and the
/// returned future never completes — callers should treat that as "stay here
/// until the user updates".
Future<void> showUpdateDialog(BuildContext context, AppRelease release) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !release.mandatory,
    builder: (context) => PopScope(
      canPop: !release.mandatory,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        backgroundColor: Colors.transparent,
        child: _UpdateDialogContent(release: release),
      ),
    ),
  );
}

class _UpdateDialogContent extends StatefulWidget {
  const _UpdateDialogContent({required this.release});

  final AppRelease release;

  @override
  State<_UpdateDialogContent> createState() => _UpdateDialogContentState();
}

class _UpdateDialogContentState extends State<_UpdateDialogContent> {
  double _progress = 0;
  bool _downloading = false;
  String? _error;

  Future<void> _update() async {
    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });
    final error = await AppUpdater.instance.downloadAndInstall(
      widget.release.apkUrl,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );
    if (!mounted) return;
    if (error == null) {
      // Installer launched — close the dialog; the OS takes over.
      Navigator.of(context).pop();
    } else {
      setState(() {
        _downloading = false;
        _error = error;
      });
    }
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.tryParse(widget.release.apkUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final release = widget.release;
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF17172A) : Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.rLg),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: const BoxDecoration(
                gradient: AppTheme.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              release.mandatory ? 'Update Required' : 'Update Available',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Version ${release.versionName} is ready.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (release.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppTheme.rSm),
                ),
                child: Text(
                  release.notes,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                ),
              ),
            ],
            if (release.mandatory && !_downloading) ...[
              const SizedBox(height: 12),
              const Text(
                'This update is required to keep using LearnHub.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.brand, fontSize: 13),
              ),
            ],
            if (_downloading) ...[
              const SizedBox(height: 18),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  color: AppTheme.brand,
                  backgroundColor: scheme.outlineVariant.withOpacity(0.4),
                  minHeight: 7,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _progress > 0
                    ? 'Updating ${(_progress * 100).toStringAsFixed(0)}%'
                    : 'Starting update…',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                '$_error. Try again or open in your browser.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 22),
            if (_downloading)
              Text('Please wait…',
                  style: TextStyle(color: scheme.onSurfaceVariant))
            else ...[
              _UpdateButton(
                label: _error == null ? 'Update Now' : 'Retry',
                onPressed: _update,
              ),
              if (_error != null) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _openInBrowser,
                  child: const Text('Open in browser'),
                ),
              ],
              if (!release.mandatory) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Later'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Gradient CTA button, matching the app's PremiumCard/GradientButton style.
class _UpdateButton extends StatelessWidget {
  const _UpdateButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        child: Ink(
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: AppTheme.brandGradient,
            borderRadius: BorderRadius.circular(AppTheme.rMd),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brand.withOpacity(0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.download_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
