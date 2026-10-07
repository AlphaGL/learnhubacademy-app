import 'package:flutter/material.dart';

import '../../core/services/app_api_client.dart';
import '../../core/services/foundation_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'practice_take_screen.dart';
import 'topic_detail_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  const SubjectDetailScreen({super.key, required this.subjectId, required this.subjectName});
  final int subjectId;
  final String subjectName;

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> {
  late Future<SubjectDetail> _future;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _future = FoundationApiService.instance.subjectDetail(widget.subjectId);
  }

  Future<void> _startPractice(FoundationYear year) async {
    setState(() => _starting = true);
    try {
      final sessionId = await FoundationApiService.instance.practiceStart(year.id);
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PracticeTakeScreen(sessionId: sessionId)),
        );
      }
    } on FoundationException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subjectName)),
      body: FutureBuilder<SubjectDetail>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load this subject',
              message: snap.error.toString(),
              onRetry: () =>
                  setState(() => _future = FoundationApiService.instance.subjectDetail(widget.subjectId)),
            );
          }
          final data = snap.data!;
          final isSubscriber = data.isSubscriber || AppApiClient.instance.cachedIsSubscribed == true;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!isSubscriber)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(AppTheme.rSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppTheme.warning),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Subscribe to unlock study notes and practice past questions.',
                          style: TextStyle(color: AppTheme.warning),
                        ),
                      ),
                    ],
                  ),
                ),
              if (data.topics.isNotEmpty) ...[
                const SectionHeader(title: 'Study Notes'),
                for (final topic in data.topics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => TopicDetailScreen(topicId: topic.id, topicTitle: topic.title)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSubscriber ? Icons.article_outlined : Icons.lock_outline_rounded,
                            color: AppTheme.brand,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(topic.title,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
              ],
              if (data.years.isNotEmpty) ...[
                const SectionHeader(title: 'Past Questions'),
                for (final year in data.years)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            height: 44,
                            width: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withOpacity(0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.history_edu_rounded, color: AppTheme.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${year.year}${year.sessionNote.isNotEmpty ? ' — ${year.sessionNote}' : ''}',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                Text('${year.questionCount} questions',
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5)),
                              ],
                            ),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: (_starting || year.questionCount == 0)
                                ? null
                                : () => _startPractice(year),
                            child: _starting
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Practice'),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
              if (data.topics.isEmpty && data.years.isEmpty)
                const EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'Nothing here yet',
                  message: 'Study notes and past questions for this subject are coming soon.',
                ),
            ],
          );
        },
      ),
    );
  }
}
