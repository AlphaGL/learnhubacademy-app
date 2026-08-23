import 'package:flutter/material.dart';

import '../../core/services/studynotes_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import 'cbt_results_screen.dart';

class CbtTakeScreen extends StatefulWidget {
  const CbtTakeScreen({super.key, required this.examId, required this.questions});
  final String examId;
  final List<CbtQuestionModel> questions;

  @override
  State<CbtTakeScreen> createState() => _CbtTakeScreenState();
}

class _CbtTakeScreenState extends State<CbtTakeScreen> {
  final Map<int, int> _answers = {};
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await StudyNotesApiService.instance.cbtSubmit(widget.examId, _answers);
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => CbtResultsScreen(examId: widget.examId)),
        );
      }
    } on StudyNotesException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.questions.length} questions'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          for (final question in widget.questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: PremiumCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${question.questionNumber}. ${question.questionText}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 10),
                    for (final option in question.options)
                      _OptionTile(
                        option: option,
                        selected: _answers[question.id] == option.id,
                        onTap: () => setState(() => _answers[question.id] = option.id),
                      ),
                  ],
                ),
              ),
            ),
          GradientButton(
            label: _submitting ? 'Submitting…' : 'Submit Test',
            icon: Icons.check_circle_rounded,
            loading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.option, required this.selected, required this.onTap});
  final CbtOptionModel option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? AppTheme.brand : scheme.outlineVariant, width: 1.5),
          borderRadius: BorderRadius.circular(10),
          color: selected ? AppTheme.brand.withOpacity(0.08) : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: selected ? AppTheme.brand : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text('${option.label}. ${option.text}',
                  style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
            ),
          ],
        ),
      ),
    );
  }
}
