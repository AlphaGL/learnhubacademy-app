import 'package:flutter/material.dart';

import '../../core/services/studynotes_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';

class CbtResultsScreen extends StatefulWidget {
  const CbtResultsScreen({super.key, required this.examId});
  final String examId;

  @override
  State<CbtResultsScreen> createState() => _CbtResultsScreenState();
}

class _CbtResultsScreenState extends State<CbtResultsScreen> {
  late Future<({double score, int totalMarks, List<CbtQuestionModel> questions})> _future;

  @override
  void initState() {
    super.initState();
    _future = StudyNotesApiService.instance.cbtResults(widget.examId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load results',
              message: snap.error.toString(),
            );
          }
          final result = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PremiumCard(
                gradient: AppTheme.brandGradient,
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('${result.score.round()}%',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w800, fontSize: 40)),
                ),
              ),
              const SizedBox(height: 16),
              for (final question in result.questions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: PremiumCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${question.questionNumber}. ${question.questionText}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                        const SizedBox(height: 8),
                        for (final option in question.options)
                          _ResultOptionRow(option: option, question: question),
                        if (question.explanation != null && question.explanation!.isNotEmpty) ...[
                          const Divider(height: 20),
                          Text(question.explanation!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 12.5)),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultOptionRow extends StatelessWidget {
  const _ResultOptionRow({required this.option, required this.question});
  final CbtOptionModel option;
  final CbtQuestionModel question;

  @override
  Widget build(BuildContext context) {
    final isCorrect = option.isCorrect ?? false;
    final isWrongPick = !isCorrect && option.id == question.selectedOptionId;
    Color? color;
    if (isCorrect) {
      color = AppTheme.success;
    } else if (isWrongPick) {
      color = AppTheme.danger;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (isCorrect)
            const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.success)
          else if (isWrongPick)
            const Icon(Icons.cancel_rounded, size: 16, color: AppTheme.danger)
          else
            const SizedBox(width: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text('${option.label}. ${option.text}',
                style: TextStyle(
                    color: color, fontWeight: color != null ? FontWeight.w700 : FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}
