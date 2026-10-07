import 'package:flutter/material.dart';

import '../../core/services/foundation_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'practice_results_screen.dart';

/// Untimed, one-question-at-a-time practice with instant right/wrong +
/// explanation — deliberately not a timed CBT engine, see
/// foundation/models.py's PracticeSession docstring for why.
class PracticeTakeScreen extends StatefulWidget {
  const PracticeTakeScreen({super.key, required this.sessionId});
  final String sessionId;

  @override
  State<PracticeTakeScreen> createState() => _PracticeTakeScreenState();
}

class _PracticeTakeScreenState extends State<PracticeTakeScreen> {
  late Future<PracticeTakeData> _future;
  int _index = 0;
  bool _finishing = false;

  // Per-question local state, keyed by question id.
  final Map<int, int> _selected = {};
  final Map<int, AnswerResult> _results = {};
  final Set<int> _submitting = {};

  @override
  void initState() {
    super.initState();
    _future = FoundationApiService.instance.practiceTake(widget.sessionId);
  }

  Future<void> _answer(PracticeQuestion q, PracticeOption option) async {
    if (_selected.containsKey(q.id) || _submitting.contains(q.id)) return;
    setState(() => _submitting.add(q.id));
    try {
      final result = await FoundationApiService.instance.practiceAnswer(widget.sessionId, q.id, option.id);
      if (mounted) {
        setState(() {
          _selected[q.id] = option.id;
          _results[q.id] = result;
        });
      }
    } on FoundationException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting.remove(q.id));
    }
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    try {
      await FoundationApiService.instance.practiceFinish(widget.sessionId);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => PracticeResultsScreen(sessionId: widget.sessionId)),
        );
      }
    } on FoundationException catch (e) {
      if (mounted) {
        setState(() => _finishing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: FutureBuilder<PracticeTakeData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList(count: 3, height: 140);
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load this practice session',
              message: snap.error.toString(),
              onRetry: () =>
                  setState(() => _future = FoundationApiService.instance.practiceTake(widget.sessionId)),
            );
          }
          final data = snap.data!;
          if (data.completed) {
            // Already finished (re-opened from history) — go straight to results.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => PracticeResultsScreen(sessionId: widget.sessionId)),
              );
            });
            return const Center(child: CircularProgressIndicator());
          }
          final questions = data.questions;
          if (questions.isEmpty) {
            return const EmptyState(icon: Icons.inbox_outlined, title: 'No questions in this set');
          }
          final q = questions[_index];
          // Seed local state from any answers the session already had
          // (e.g. the app was closed mid-session and reopened).
          if (q.selectedOptionId != null && !_selected.containsKey(q.id)) {
            _selected[q.id] = q.selectedOptionId!;
          }
          final answered = _selected.containsKey(q.id);
          final result = _results[q.id];

          return Column(
            children: [
              LinearProgressIndicator(value: (_index + 1) / questions.length, minHeight: 4),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Pill('${data.subject ?? ''} · ${data.year?.year ?? ''}'),
                          const Spacer(),
                          Text('Question ${_index + 1} of ${questions.length}',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(q.text, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, height: 1.4)),
                      const SizedBox(height: 18),
                      for (final option in q.options)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _OptionTile(
                            option: option,
                            isSelected: _selected[q.id] == option.id,
                            isCorrectAnswer: answered &&
                                result != null &&
                                result.correctOptionLabel == option.label,
                            answered: answered,
                            onTap: () => _answer(q, option),
                          ),
                        ),
                      if (answered && result != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: (result.isCorrect ? AppTheme.success : AppTheme.danger).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.rSm),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    result.isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    color: result.isCorrect ? AppTheme.success : AppTheme.danger,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    result.isCorrect ? 'Correct' : 'Incorrect',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: result.isCorrect ? AppTheme.success : AppTheme.danger),
                                  ),
                                  if (result.answerVerifiedBy != 'official') ...[
                                    const SizedBox(width: 8),
                                    Pill(
                                      result.answerVerifiedBy == 'ai' ? 'AI-solved — verify' : 'Unverified',
                                      color: AppTheme.warning,
                                    ),
                                  ],
                                ],
                              ),
                              if (result.explanation.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(result.explanation, style: const TextStyle(height: 1.5)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      if (_index > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => setState(() => _index--),
                            child: const Text('Previous'),
                          ),
                        ),
                      if (_index > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _index < questions.length - 1
                            ? GradientButton(
                                label: 'Next',
                                onPressed: () => setState(() => _index++),
                              )
                            : GradientButton(
                                label: 'Finish',
                                loading: _finishing,
                                onPressed: _finishing ? null : _finish,
                              ),
                      ),
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

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.option,
    required this.isSelected,
    required this.isCorrectAnswer,
    required this.answered,
    required this.onTap,
  });
  final PracticeOption option;
  final bool isSelected;
  final bool isCorrectAnswer;
  final bool answered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Color? bg;
    Color? border;
    if (answered) {
      if (isCorrectAnswer) {
        bg = AppTheme.success.withOpacity(0.12);
        border = AppTheme.success;
      } else if (isSelected) {
        bg = AppTheme.danger.withOpacity(0.12);
        border = AppTheme.danger;
      }
    }
    return Material(
      color: bg ?? Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppTheme.rSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.rSm),
        onTap: answered ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.rSm),
            border: Border.all(
              color: border ?? Theme.of(context).colorScheme.outlineVariant,
              width: border != null ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: (border ?? Theme.of(context).colorScheme.outlineVariant).withOpacity(0.18),
                child: Text(option.label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: border ?? Theme.of(context).colorScheme.onSurface)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(option.text)),
              if (answered && isCorrectAnswer) const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
              if (answered && isSelected && !isCorrectAnswer)
                const Icon(Icons.cancel_rounded, color: AppTheme.danger, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
