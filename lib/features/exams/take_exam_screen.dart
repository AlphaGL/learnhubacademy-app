import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/exam_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'exam_results_screen.dart';
import 'models/exam_models.dart';

/// The active quiz-taking UI, used for both exam-year and material-level
/// quizzes (identical shape server-side and client-side, just a different
/// content family — see ExamKind).
class TakeExamScreen extends StatefulWidget {
  const TakeExamScreen({
    super.key,
    required this.session,
    required this.title,
    required this.contentId,
  });

  final ExamSession session;
  final String title;

  /// The subject_id or material_id this exam belongs to — used only to key
  /// the "resume in progress" marker in shared_preferences.
  final int contentId;

  @override
  State<TakeExamScreen> createState() => _TakeExamScreenState();
}

class _TakeExamScreenState extends State<TakeExamScreen> {
  late ExamSession _session;
  int _index = 0;
  Timer? _timer;
  late int _secondsLeft;
  DateTime _questionShownAt = DateTime.now();
  final Map<int, int> _selected = {};
  final Map<int, AnswerResult> _feedback = {}; // test mode only
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _selected.addAll(_session.answers);
    _secondsLeft = _session.durationMinutes * 60;
    _persistResumeMarker();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _finish(auto: true);
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  String get _timeLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _persistResumeMarker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'active_exam',
      '${_session.kind.name}|${_session.examId}|${widget.contentId}|${widget.title}',
    );
  }

  Future<void> _clearResumeMarker() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_exam');
  }

  Future<void> _selectOption(ExamQuestion question, int optionId) async {
    if (_submitting) return;
    setState(() => _selected[question.id] = optionId);

    final timeTaken = DateTime.now().difference(_questionShownAt).inSeconds;
    try {
      final result = await ExamApiService.instance.submitAnswer(
        _session.kind,
        _session.examId,
        questionId: question.id,
        optionId: optionId,
        timeTakenSeconds: timeTaken,
      );
      if (_session.isTestMode && mounted) {
        setState(() => _feedback[question.id] = result);
      }
    } on ExamException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Answer not saved: $e')));
      }
    }
  }

  void _goTo(int index) {
    setState(() {
      _index = index;
      _questionShownAt = DateTime.now();
    });
  }

  Future<void> _confirmAndFinish() async {
    final answered = _selected.length;
    final total = _session.questions.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit exam?'),
        content: Text(answered < total
            ? "You've answered $answered of $total questions. Unanswered questions will be marked wrong."
            : "You've answered all $total questions."),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep going')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (confirmed == true) await _finish();
  }

  Future<void> _finish({bool auto = false}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ExamApiService.instance.finishExam(_session.kind, _session.examId);
      await _clearResumeMarker();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => ExamResultsScreen(
          kind: _session.kind,
          examId: _session.examId,
          title: widget.title,
        ),
      ));
    } on ExamException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not submit: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final question = _session.questions[_index];
    final feedback = _feedback[question.id];
    final selectedOptionId = _selected[question.id];
    final isLast = _index == _session.questions.length - 1;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave exam?'),
            content: const Text(
                'Your progress is saved — you can resume this exam later.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Stay')),
              FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Leave')),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined,
                        size: 18,
                        color: _secondsLeft < 60 ? AppTheme.danger : scheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(_timeLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _secondsLeft < 60 ? AppTheme.danger : null,
                        )),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _QuestionNav(
              count: _session.questions.length,
              current: _index,
              isAnswered: (i) => _selected.containsKey(_session.questions[i].id),
              onTap: _goTo,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Question ${question.number} of ${_session.questions.length}',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(question.text,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.4)),
                  const SizedBox(height: 20),
                  ...question.options.map((option) {
                    final isSelected = selectedOptionId == option.id;
                    Color? tint;
                    IconData? trailingIcon;
                    if (feedback != null) {
                      if (option.id == feedback.correctOptionId) {
                        tint = AppTheme.success;
                        trailingIcon = Icons.check_circle_rounded;
                      } else if (isSelected && !feedback.isCorrect) {
                        tint = AppTheme.danger;
                        trailingIcon = Icons.cancel_rounded;
                      }
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: tint?.withOpacity(0.1) ??
                            (isSelected ? scheme.primary.withOpacity(0.08) : scheme.surface),
                        borderRadius: BorderRadius.circular(AppTheme.rMd),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.rMd),
                          onTap: feedback != null ? null : () => _selectOption(question, option.id),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppTheme.rMd),
                              border: Border.all(
                                color: tint ??
                                    (isSelected
                                        ? scheme.primary
                                        : scheme.outlineVariant.withOpacity(0.6)),
                                width: isSelected || tint != null ? 1.6 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor:
                                      tint ?? (isSelected ? scheme.primary : scheme.surfaceContainerHighest),
                                  child: Text(option.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: (tint != null || isSelected) ? Colors.white : null,
                                      )),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(option.text, style: const TextStyle(fontSize: 14.5))),
                                if (trailingIcon != null) Icon(trailingIcon, color: tint, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  if (feedback?.explanation != null) ...[
                    const SizedBox(height: 8),
                    PremiumCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.lightbulb_outline_rounded, size: 18, color: scheme.primary),
                            const SizedBox(width: 8),
                            Text('Explanation',
                                style: TextStyle(fontWeight: FontWeight.w700, color: scheme.primary)),
                          ]),
                          const SizedBox(height: 8),
                          Text(feedback!.explanation!.text, style: const TextStyle(height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ],
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
                          onPressed: () => _goTo(_index - 1),
                          child: const Text('Previous'),
                        ),
                      ),
                    if (_index > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: isLast
                          ? GradientButton(
                              label: 'Submit exam',
                              loading: _submitting,
                              onPressed: _submitting ? null : _confirmAndFinish,
                            )
                          : GradientButton(
                              label: 'Next',
                              icon: Icons.arrow_forward_rounded,
                              onPressed: () => _goTo(_index + 1),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionNav extends StatelessWidget {
  const _QuestionNav({
    required this.count,
    required this.current,
    required this.isAnswered,
    required this.onTap,
  });

  final int count;
  final int current;
  final bool Function(int index) isAnswered;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final isCurrent = i == current;
          final answered = isAnswered(i);
          return InkWell(
            onTap: () => onTap(i),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isCurrent ? AppTheme.brandGradient : null,
                color: isCurrent
                    ? null
                    : answered
                        ? AppTheme.success.withOpacity(0.14)
                        : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${i + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                  color: isCurrent
                      ? Colors.white
                      : answered
                          ? AppTheme.success
                          : scheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
