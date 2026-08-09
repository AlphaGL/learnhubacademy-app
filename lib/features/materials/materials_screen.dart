import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import '../subjects/models/subject.dart';
import 'material_detail_screen.dart';
import 'models/material_model.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key, required this.subject});
  final Subject subject;

  @override
  State<MaterialsScreen> createState() => _MaterialsScreenState();
}

class _MaterialsScreenState extends State<MaterialsScreen> {
  late Future<List<MaterialModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<MaterialModel>> _load() async {
    final rows = await SupabaseService.client
        .from(AppConfig.tblMaterial)
        .select(
            'id, subject_id, title, material_type, content, file_url, video_url, views')
        .eq('subject_id', widget.subject.id)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => MaterialModel.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  ({IconData icon, Color color, String label}) _kindOf(MaterialModel m) {
    if (m.hasVideo) {
      return (icon: Icons.play_circle_rounded, color: AppTheme.danger, label: 'Video');
    }
    if (m.hasPdf || m.materialType == 'pdf') {
      return (icon: Icons.picture_as_pdf_rounded, color: AppTheme.brand, label: 'PDF');
    }
    if (m.materialType == 'image') {
      return (icon: Icons.image_rounded, color: AppTheme.accent, label: 'Slides');
    }
    return (icon: Icons.article_rounded, color: AppTheme.success, label: 'Notes');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(26),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 10),
              child: Pill(widget.subject.code),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<MaterialModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load materials',
              message: snap.error.toString(),
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.inbox_rounded,
              title: 'Nothing here yet',
              message: 'Materials for this course will appear here soon.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final m = items[i];
                final k = _kindOf(m);
                return PremiumCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => MaterialDetailScreen(material: m)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 50,
                        width: 50,
                        decoration: BoxDecoration(
                          color: k.color.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(k.icon, color: k.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Pill(k.label, color: k.color),
                                const SizedBox(width: 8),
                                Icon(Icons.visibility_outlined,
                                    size: 14,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text('${m.views}',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
