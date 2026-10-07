import 'package:flutter/material.dart';

import '../../core/services/foundation_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';

class PracticeResultsScreen extends StatefulWidget {
  const PracticeResultsScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  State<PracticeResultsScreen> createState() => _PracticeResultsScreenState();
}

class _PracticeResultsScreenState extends State<PracticeResultsScreen> {
  late Future<PracticeResults> _future;

  @override
  void initState() {
    super.initState();
    _future = FoundationApiService.instance.practiceResults(widget.sessionId);
  }

  Color _scoreColor(double score) {
    if (score >= 70) return AppTheme.success;
    if (score >= 50) return AppTheme.warning;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Done'),
          ),
        ],
      ),
      body: FutureBuilder<PracticeResults>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList(count: 4, height: 110);
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load results',
              message: snap.error.toString(),
              onRetry: () =>
                  setState(() => _future = FoundationApiService.instance.practiceResults(widget.sessionId)),
            );
          }
          final data = snap.data!;
          final color = _scoreColor(data.score);
          final correctCount = data.questions.where((q) => q.selectedOptionId == q.correctOptionId).length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PremiumCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    Text('${data.subject} · ${data.year.year}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 14),
                    Container(
                      height: 110,
                      width: 110,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.12)),
                      child: Text('${data.score.toStringAsFixed(0)}%',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
                    ),
                    const SizedBox(height: 14),
                    Text('$correctCount of ${data.totalQuestions} correct',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Review'),
              for (final q in data.questions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReviewCard(question: q),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.question});
  final PracticeQuestion question;

  @override
  Widget build(BuildContext context) {
    final isCorrect = question.selectedOptionId != null && question.selectedOptionId == question.correctOptionId;
    final wasAnswered = question.selectedOptionId != null;
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                !wasAnswered
                    ? Icons.remove_circle_outline_rounded
                    : isCorrect
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                color: !wasAnswered ? AppTheme.warning : (isCorrect ? AppTheme.success : AppTheme.danger),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Q${question.number}. ${question.text}',
                    style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Builder(builder: (context) {
                final isTheCorrectOption = option.id == question.correctOptionId;
                final isSelected = option.id == question.selectedOptionId;
                Color? bg;
                if (isTheCorrectOption) bg = AppTheme.success.withOpacity(0.12);
                if (isSelected && !isTheCorrectOption) bg = AppTheme.danger.withOpacity(0.12);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Text('${option.label}.  ', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Expanded(child: Text(option.text)),
                      if (isSelected)
                        Text(wasAnswered ? 'Your answer' : '',
                            style: TextStyle(
                                fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                );
              }),
            ),
          if ((question.explanation ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(question.explanation!, style: const TextStyle(fontSize: 13, height: 1.5)),
            ),
          ],
        ],
      ),
    );
  }
}
