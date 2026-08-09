import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/exam_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'exam_results_screen.dart';
import 'models/exam_models.dart';

/// Past exam/quiz attempts across both content families — no direct website
/// equivalent (StudentProgress tracks aggregate stats there, but nothing
/// lists individual attempts), added for the app since reviewing past
/// results matters more without a desktop-sized dashboard to show them on.
class ExamHistoryScreen extends StatefulWidget {
  const ExamHistoryScreen({super.key});

  @override
  State<ExamHistoryScreen> createState() => _ExamHistoryScreenState();
}

class _ExamHistoryScreenState extends State<ExamHistoryScreen> {
  late Future<List<ExamHistoryEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = ExamApiService.instance.examHistory();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('My Results')),
      body: FutureBuilder<List<ExamHistoryEntry>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your results',
              message: snap.error.toString(),
              onRetry: () =>
                  setState(() => _future = ExamApiService.instance.examHistory()),
            );
          }
          final history = snap.data ?? [];
          if (history.isEmpty) {
            return const EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No exams taken yet',
              message: 'Practice exams you complete will show up here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                setState(() => _future = ExamApiService.instance.examHistory()),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final entry = history[i];
                final score = entry.score ?? 0;
                final color = score >= 50 ? AppTheme.success : AppTheme.danger;
                return PremiumCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ExamResultsScreen(
                      kind: entry.kind == 'material' ? ExamKind.material : ExamKind.examYear,
                      examId: entry.examId,
                      title: entry.title,
                    ),
                  )),
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
                        child: Text('${score.toStringAsFixed(0)}%',
                            style: TextStyle(
                                color: color, fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Pill(entry.mode == 'test' ? 'Test Mode' : 'Exam Mode'),
                                const SizedBox(width: 8),
                                if (entry.submittedAt != null)
                                  Text(
                                    DateFormat('MMM d, y').format(entry.submittedAt!),
                                    style: TextStyle(
                                        color: scheme.onSurfaceVariant, fontSize: 12),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
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
