import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/insights_api_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import '../exams/exam_years_screen.dart';
import '../materials/material_detail_screen.dart';
import '../materials/models/material_model.dart';
import '../subjects/models/subject.dart';

class WeakTopicsScreen extends StatefulWidget {
  const WeakTopicsScreen({super.key});

  @override
  State<WeakTopicsScreen> createState() => _WeakTopicsScreenState();
}

class _WeakTopicsScreenState extends State<WeakTopicsScreen> {
  late Future<WeakTopicsResult> _future;
  final Set<int> _navigatingIndices = {};

  @override
  void initState() {
    super.initState();
    _future = InsightsApiService.instance.weakTopics();
  }

  Future<Subject?> _fetchSubject(int id) async {
    final row = await SupabaseService.client
        .from(AppConfig.tblSubject)
        .select('id, name, code, description, semester')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : Subject.fromMap(row);
  }

  Future<MaterialModel?> _fetchMaterial(int id) async {
    final row = await SupabaseService.client
        .from(AppConfig.tblMaterial)
        .select('id, subject_id, title, material_type, content, file_url, video_url, views')
        .eq('id', id)
        .maybeSingle();
    return row == null ? null : MaterialModel.fromMap(row);
  }

  Future<void> _openTopic(int index, WeakTopic topic) async {
    setState(() => _navigatingIndices.add(index));
    try {
      if (topic.kind == WeakTopicKind.material && topic.materialId != null) {
        final material = await _fetchMaterial(topic.materialId!);
        if (material != null && mounted) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => MaterialDetailScreen(material: material)));
        }
      } else {
        final subject = await _fetchSubject(topic.subjectId);
        if (subject != null && mounted) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ExamYearsScreen(subject: subject)));
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open this topic right now.')));
      }
    } finally {
      if (mounted) setState(() => _navigatingIndices.remove(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Insights')),
      body: FutureBuilder<WeakTopicsResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your insights',
              message: snap.error.toString(),
              onRetry: () =>
                  setState(() => _future = InsightsApiService.instance.weakTopics()),
            );
          }
          final result = snap.data!;
          return RefreshIndicator(
            onRefresh: () async =>
                setState(() => _future = InsightsApiService.instance.weakTopics()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _OverallCard(accuracy: result.overallAccuracy),
                const SizedBox(height: 20),
                if (result.topics.isEmpty)
                  const EmptyState(
                    icon: Icons.bar_chart_rounded,
                    title: 'Not enough data yet',
                    message:
                        'Complete a few questions on a topic and your weak spots will show up here.',
                  )
                else ...[
                  const SectionHeader(title: 'Topics to review'),
                  for (var i = 0; i < result.topics.length; i++)
                    _TopicCard(
                      topic: result.topics[i],
                      loading: _navigatingIndices.contains(i),
                      onTap: () => _openTopic(i, result.topics[i]),
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard({required this.accuracy});
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      gradient: AppTheme.brandGradient,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Text('Overall accuracy',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            accuracy == null ? '—' : '${accuracy!.toStringAsFixed(0)}%',
            style: const TextStyle(
                color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text('Across the exams and quizzes you\'ve completed',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic, required this.loading, required this.onTap});
  final WeakTopic topic;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = topic.accuracy < 50 ? AppTheme.danger : AppTheme.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        padding: const EdgeInsets.all(14),
        onTap: loading ? null : onTap,
        child: Row(
          children: [
            Container(
              height: 46,
              width: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text('${topic.accuracy.toStringAsFixed(0)}%',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 4),
                  Text(
                    topic.kind == WeakTopicKind.material
                        ? '${topic.subjectName} · ${topic.attempts} attempted'
                        : '${topic.attempts} questions attempted',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                  height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
