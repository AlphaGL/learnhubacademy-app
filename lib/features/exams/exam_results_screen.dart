import 'package:flutter/material.dart';

import '../../core/services/exam_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'models/exam_models.dart';

class ExamResultsScreen extends StatefulWidget {
  const ExamResultsScreen({
    super.key,
    required this.kind,
    required this.examId,
    required this.title,
  });

  final ExamKind kind;
  final String examId;
  final String title;

  @override
  State<ExamResultsScreen> createState() => _ExamResultsScreenState();
}

class _ExamResultsScreenState extends State<ExamResultsScreen> {
  late Future<ExamResults> _future;

  @override
  void initState() {
    super.initState();
    _future = ExamApiService.instance.examResults(widget.kind, widget.examId);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).popUntil((r) => r.isFirst);
      },
      child: Scaffold(
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
        body: FutureBuilder<ExamResults>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load results',
                message: snap.error.toString(),
                onRetry: () => setState(() => _future =
                    ExamApiService.instance.examResults(widget.kind, widget.examId)),
              );
            }
            final results = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ScoreCard(results: results, title: widget.title),
                const SizedBox(height: 20),
                Text('Question breakdown',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ...results.questions.map((q) => _QuestionResultCard(question: q)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.results, required this.title});
  final ExamResults results;
  final String title;

  @override
  Widget build(BuildContext context) {
    final passed = results.score >= 50;
    return PremiumCard(
      gradient: AppTheme.brandGradient,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('${results.score.toStringAsFixed(0)}%',
              style: const TextStyle(
                  color: Colors.white, fontSize: 44, fontWeight: FontWeight.w800)),
          Text(passed ? 'Well done! 🎉' : 'Keep practicing 💪',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(label: 'Correct', value: '${results.correctAnswers}', color: Colors.white),
              _Stat(label: 'Incorrect', value: '${results.incorrectAnswers}', color: Colors.white),
              _Stat(label: 'Total', value: '${results.totalQuestions}', color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: color.withOpacity(0.85), fontSize: 12)),
      ],
    );
  }
}

class _QuestionResultCard extends StatelessWidget {
  const _QuestionResultCard({required this.question});
  final ExamResultQuestion question;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  question.selectedOptionId == null
                      ? Icons.remove_circle_outline_rounded
                      : (question.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded),
                  color: question.selectedOptionId == null
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : (question.isCorrect ? AppTheme.success : AppTheme.danger),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Q${question.number}. ${question.text}',
                      style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
                ),
              ],
            ),
            if (question.selectedOptionId == null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text('Not answered',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                        fontSize: 12.5)),
              ),
            ],
            const SizedBox(height: 10),
            ...question.options.map((option) {
              final isSelected = option.id == question.selectedOptionId;
              final isCorrect = option.isCorrect == true;
              Color? tint;
              if (isCorrect) {
                tint = AppTheme.success;
              } else if (isSelected) {
                tint = AppTheme.danger;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: tint?.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppTheme.rSm),
                    border: Border.all(
                        color: tint ?? scheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Text('${option.label}.',
                          style: TextStyle(fontWeight: FontWeight.w700, color: tint)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(option.text, style: TextStyle(color: tint))),
                      if (isCorrect) const Icon(Icons.check, size: 16, color: AppTheme.success),
                    ],
                  ),
                ),
              );
            }),
            if (question.explanation != null && question.explanation!.text.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(AppTheme.rSm),
                ),
                child: Text(question.explanation!.text,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, height: 1.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
