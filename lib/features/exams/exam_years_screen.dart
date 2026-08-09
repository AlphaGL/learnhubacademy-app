import 'package:flutter/material.dart';

import '../../core/services/exam_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import '../subjects/models/subject.dart';
import 'models/exam_models.dart';
import 'start_exam_helper.dart';

/// Past-question / CBT practice exams for a subject, grouped by year —
/// mirrors the website's exam_years_list + take_exam flow.
class ExamYearsScreen extends StatefulWidget {
  const ExamYearsScreen({super.key, required this.subject});
  final Subject subject;

  @override
  State<ExamYearsScreen> createState() => _ExamYearsScreenState();
}

class _ExamYearsScreenState extends State<ExamYearsScreen> {
  late Future<List<ExamYearSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = ExamApiService.instance.examYears(widget.subject.id);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.subject.name} — Past Questions')),
      body: FutureBuilder<List<ExamYearSummary>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load past questions',
              message: snap.error.toString(),
              onRetry: () => setState(
                  () => _future = ExamApiService.instance.examYears(widget.subject.id)),
            );
          }
          final years = snap.data ?? [];
          if (years.isEmpty) {
            return const EmptyState(
              icon: Icons.quiz_outlined,
              title: 'No past questions yet',
              message: 'Practice exams for this course will appear here soon.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: years.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final ey = years[i];
              final hasQuestions = ey.questionCount > 0;
              return PremiumCard(
                padding: const EdgeInsets.all(14),
                onTap: hasQuestions
                    ? () => startOrResumeExam(
                          context,
                          kind: ExamKind.examYear,
                          contentId: ey.id,
                          title: '${widget.subject.name} — ${ey.label}',
                          start: (mode) => ExamApiService.instance
                              .startExam(examYearId: ey.id, mode: mode),
                        )
                    : null,
                child: Row(
                  children: [
                    Container(
                      height: 46,
                      width: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppTheme.brandGradient,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ey.label,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            hasQuestions
                                ? '${ey.questionCount} questions'
                                : 'No questions yet',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    if (hasQuestions)
                      Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
