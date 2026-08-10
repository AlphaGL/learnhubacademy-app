import 'package:flutter/material.dart';

import '../../core/services/question_of_the_day_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';

class QuestionOfTheDayScreen extends StatefulWidget {
  const QuestionOfTheDayScreen({super.key});

  @override
  State<QuestionOfTheDayScreen> createState() => _QuestionOfTheDayScreenState();
}

class _QuestionOfTheDayScreenState extends State<QuestionOfTheDayScreen> {
  late Future<QuestionOfTheDay> _future;
  bool _answered = false;
  bool? _wasCorrect;
  int? _selectedOptionId;
  int? _correctOptionId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<QuestionOfTheDay> _load() async {
    final qotd = await QuestionOfTheDayApiService.instance.fetch();
    if (mounted) {
      setState(() {
        _answered = qotd.alreadyAnswered;
        _wasCorrect = qotd.wasCorrect;
      });
    }
    return qotd;
  }

  Future<void> _select(int optionId) async {
    if (_answered || _submitting) return;
    setState(() => _submitting = true);
    try {
      final result = await QuestionOfTheDayApiService.instance.answer(optionId);
      setState(() {
        _answered = true;
        _wasCorrect = result.isCorrect;
        _selectedOptionId = optionId;
        _correctOptionId = result.correctOptionId;
      });
    } on QotdException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Question of the Day')),
      body: FutureBuilder<QuestionOfTheDay>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load today\'s question',
              message: snap.error.toString(),
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final qotd = snap.data!;
          if (qotd.question == null) {
            return const EmptyState(
              icon: Icons.inbox_rounded,
              title: 'No question available yet',
              message: 'Check back once some past questions or quizzes have been uploaded.',
            );
          }
          return _buildQuestion(context, qotd);
        },
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, QuestionOfTheDay qotd) {
    final scheme = Theme.of(context).colorScheme;
    final question = qotd.question!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_answered)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_wasCorrect ?? false)
                    ? AppTheme.success.withOpacity(0.12)
                    : AppTheme.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppTheme.rSm),
              ),
              child: Text(
                (_wasCorrect ?? false)
                    ? '✅ Correct! Nicely done.'
                    : '❌ Not quite — the correct answer is highlighted below.',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: (_wasCorrect ?? false) ? AppTheme.success : AppTheme.danger,
                ),
              ),
            ),
          PremiumCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((qotd.source ?? '').isNotEmpty)
                  Text(qotd.source!,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5)),
                const SizedBox(height: 6),
                Text(question.text,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16.5, height: 1.4)),
                const SizedBox(height: 16),
                for (final option in question.options)
                  _OptionTile(
                    label: option.label,
                    text: option.text,
                    answered: _answered,
                    isSelected: option.id == _selectedOptionId,
                    isCorrect: _answered ? option.id == _correctOptionId : null,
                    onTap: () => _select(option.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.text,
    required this.answered,
    required this.isSelected,
    required this.isCorrect,
    required this.onTap,
  });

  final String label;
  final String text;
  final bool answered;
  final bool isSelected;
  final bool? isCorrect;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color? tint;
    if (answered) {
      if (isCorrect == true) {
        tint = AppTheme.success;
      } else if (isSelected) {
        tint = AppTheme.danger;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(AppTheme.rSm),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: tint?.withOpacity(0.1),
            border: Border.all(color: tint ?? scheme.outlineVariant.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(AppTheme.rSm),
          ),
          child: Row(
            children: [
              Text('$label.', style: TextStyle(fontWeight: FontWeight.w700, color: tint)),
              const SizedBox(width: 8),
              Expanded(child: Text(text, style: TextStyle(color: tint))),
              if (answered && isCorrect == true)
                const Icon(Icons.check, size: 16, color: AppTheme.success),
            ],
          ),
        ),
      ),
    );
  }
}
