import 'package:flutter/material.dart';

import '../../core/services/studynotes_api_service.dart';
import '../../shared/widgets/app_widgets.dart';

class TheoryScreen extends StatefulWidget {
  const TheoryScreen({super.key, required this.note});
  final LibraryNoteModel note;

  @override
  State<TheoryScreen> createState() => _TheoryScreenState();
}

class _TheoryScreenState extends State<TheoryScreen> {
  final Set<int> _revealed = {};

  @override
  Widget build(BuildContext context) {
    final questions = widget.note.theoryQuestions ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(widget.note.title, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Write your own answer first, then reveal the model answer to self-check.',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          for (final question in questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TheoryCard(
                question: question,
                revealed: _revealed.contains(question.id),
                onToggle: () => setState(() {
                  if (!_revealed.add(question.id)) _revealed.remove(question.id);
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _TheoryCard extends StatefulWidget {
  const _TheoryCard({required this.question, required this.revealed, required this.onToggle});
  final TheoryQuestionModel question;
  final bool revealed;
  final VoidCallback onToggle;

  @override
  State<_TheoryCard> createState() => _TheoryCardState();
}

class _TheoryCardState extends State<_TheoryCard> {
  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.question.questionNumber}. ${widget.question.questionText}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          const SizedBox(height: 10),
          TextField(
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Write your own answer here (not saved — just for your own thinking)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: widget.onToggle,
            icon: Icon(widget.revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 18),
            label: Text(widget.revealed ? 'Hide model answer' : 'Reveal model answer'),
          ),
          if (widget.revealed) ...[
            const Divider(height: 24),
            Text(widget.question.modelAnswer, style: const TextStyle(fontSize: 13.5, height: 1.5)),
          ],
        ],
      ),
    );
  }
}
