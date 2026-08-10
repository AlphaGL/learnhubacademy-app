import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/exam_api_service.dart';
import '../../core/services/offline_cache_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../exams/models/exam_models.dart';
import '../exams/start_exam_helper.dart';
import 'models/material_model.dart';

class MaterialDetailScreen extends StatefulWidget {
  const MaterialDetailScreen({super.key, required this.material, this.isOffline = false});
  final MaterialModel material;

  /// True when this material was opened from an offline-cached copy
  /// (no live network fetch backing it) — shows a banner instead of the
  /// offline-toggle button, since toggling would need a network call.
  final bool isOffline;

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  MaterialModel get material => widget.material;
  bool? _cached; // null while loading

  @override
  void initState() {
    super.initState();
    if (!widget.isOffline) _loadCachedState();
  }

  Future<void> _loadCachedState() async {
    final cached = await OfflineCacheService.instance.isCached(material.id);
    if (mounted) setState(() => _cached = cached);
  }

  Future<void> _toggleOffline() async {
    if (_cached == null) return;
    if (_cached!) {
      await OfflineCacheService.instance.remove(material.id);
      if (mounted) setState(() => _cached = false);
    } else {
      await OfflineCacheService.instance.cache(material);
      if (mounted) setState(() => _cached = true);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_cached! ? 'Available offline' : 'Removed from offline'),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open link.')));
      }
    }
  }

  /// Mirrors the web app's "Explain with AI": opens ChatGPT with a rich prompt.
  Future<void> _explainWithAi(BuildContext context) async {
    final cleaned = material.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final excerpt =
        cleaned.length > 300 ? cleaned.substring(0, 300) : cleaned;
    final snippet = excerpt.isEmpty
        ? ''
        : ' For context, here is a short excerpt from my notes: "$excerpt".';
    final prompt =
        'I am a university student. I am finding the topic "${material.title}" '
        'difficult to understand. Please explain it clearly and simply, starting '
        'from the basics, with step-by-step reasoning, simple analogies, and at '
        'least one worked example. Highlight key points and common mistakes, then '
        'give me 3 short self-test questions with answers.$snippet';
    final url = 'https://chat.openai.com/?q=${Uri.encodeComponent(prompt)}';
    await _open(context, url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(material.title),
        actions: [
          if (!widget.isOffline)
            IconButton(
              tooltip: (_cached ?? false) ? 'Remove from offline' : 'Save for offline',
              icon: Icon(
                _cached == null
                    ? Icons.bookmark_border_rounded
                    : (_cached! ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
              ),
              onPressed: _cached == null ? null : _toggleOffline,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.isOffline)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.rSm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.offline_pin_rounded, color: AppTheme.warning, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Viewing an offline copy. Some content may be outdated.',
                        style: TextStyle(color: AppTheme.warning, fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (material.hasVideo)
                _ResourceButton(
                  icon: Icons.play_circle,
                  label: 'Watch video',
                  color: AppTheme.danger,
                  onTap: () => _open(context, material.videoUrl!),
                ),
              if (material.hasPdf)
                _ResourceButton(
                  icon: Icons.picture_as_pdf,
                  label: 'Open PDF',
                  color: AppTheme.brand,
                  onTap: () => _open(context, material.fileUrl!),
                ),
              _ResourceButton(
                icon: Icons.auto_awesome,
                label: 'Explain with AI',
                color: AppTheme.accent,
                onTap: () => _explainWithAi(context),
              ),
              _ResourceButton(
                icon: Icons.quiz_rounded,
                label: 'Take Quiz',
                color: AppTheme.success,
                onTap: () => startOrResumeExam(
                  context,
                  kind: ExamKind.material,
                  contentId: material.id,
                  title: material.title,
                  start: (mode) => ExamApiService.instance
                      .startMaterialExam(materialId: material.id, mode: mode),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (material.content.trim().isNotEmpty) ...[
            const SectionHeader(title: 'Notes'),
            PremiumCard(
              child: SelectableText(
                material.content,
                style: const TextStyle(height: 1.6, fontSize: 15),
              ),
            ),
          ] else
            const EmptyState(
              icon: Icons.notes_rounded,
              title: 'No written notes',
              message: 'Use the buttons above to open the PDF, video, or AI help.',
            ),
        ],
      ),
    );
  }
}

class _ResourceButton extends StatelessWidget {
  const _ResourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        backgroundColor: color.withOpacity(0.12),
        foregroundColor: color,
        minimumSize: const Size(0, 44),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
    );
  }
}
