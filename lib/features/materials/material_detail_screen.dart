import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'models/material_model.dart';

class MaterialDetailScreen extends StatelessWidget {
  const MaterialDetailScreen({super.key, required this.material});
  final MaterialModel material;

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
      appBar: AppBar(title: Text(material.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
