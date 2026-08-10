import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/services/exam_api_service.dart';
import '../../core/services/offline_cache_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../exams/models/exam_models.dart';
import '../exams/start_exam_helper.dart';
import 'models/material_image.dart';
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
  YoutubePlayerController? _ytController;
  List<MaterialImage> _images = [];

  @override
  void initState() {
    super.initState();
    if (!widget.isOffline) {
      _loadCachedState();
      _loadImages();
    }
    if (material.hasVideo) {
      final videoId = YoutubePlayer.convertUrlToId(material.videoUrl!);
      if (videoId != null) {
        _ytController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
        );
      }
    }
  }

  @override
  void dispose() {
    _ytController?.dispose();
    super.dispose();
  }

  Future<void> _loadCachedState() async {
    final cached = await OfflineCacheService.instance.isCached(material.id);
    if (mounted) setState(() => _cached = cached);
  }

  Future<void> _loadImages() async {
    try {
      final rows = await SupabaseService.client
          .from(AppConfig.tblMaterialImage)
          .select('id, material_id, image_url, caption, order')
          .eq('material_id', material.id)
          .order('order');
      final images =
          (rows as List).map((e) => MaterialImage.fromMap(e as Map<String, dynamic>)).toList();
      if (mounted) setState(() => _images = images);
    } catch (_) {
      // Slide images are a bonus, not essential — fail quietly.
    }
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
          if (_ytController != null) ...[
            const SectionHeader(title: 'Video'),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.rMd),
              child: YoutubePlayer(controller: _ytController!),
            ),
            const SizedBox(height: 20),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (material.hasVideo && _ytController == null)
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
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'Slides'),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final image = _images[i];
                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => _SlideGalleryScreen(images: _images, initialIndex: i),
                    )),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.rSm),
                      child: CachedNetworkImage(
                        imageUrl: image.imageUrl,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        placeholder: (context, _) => Container(
                          width: 120,
                          height: 120,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                        errorWidget: (context, _, __) => Container(
                          width: 120,
                          height: 120,
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SlideGalleryScreen extends StatelessWidget {
  const _SlideGalleryScreen({required this.images, required this.initialIndex});
  final List<MaterialImage> images;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${initialIndex + 1} / ${images.length}'),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: images.length,
        itemBuilder: (context, i) {
          final image = images[i];
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: InteractiveViewer(
                  child: CachedNetworkImage(
                    imageUrl: image.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              if (image.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(image.caption,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70)),
                ),
            ],
          );
        },
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
