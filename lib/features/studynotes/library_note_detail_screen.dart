import 'package:flutter/material.dart';

import '../../core/services/studynotes_api_service.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'cbt_take_screen.dart';
import 'theory_screen.dart';

class LibraryNoteDetailScreen extends StatefulWidget {
  const LibraryNoteDetailScreen({super.key, required this.noteId});
  final int noteId;

  @override
  State<LibraryNoteDetailScreen> createState() => _LibraryNoteDetailScreenState();
}

class _LibraryNoteDetailScreenState extends State<LibraryNoteDetailScreen> {
  late Future<LibraryNoteModel> _future;
  bool _startingCbt = false;

  @override
  void initState() {
    super.initState();
    _future = StudyNotesApiService.instance.libraryDetail(widget.noteId);
  }

  Future<void> _startCbt() async {
    setState(() => _startingCbt = true);
    try {
      final result = await StudyNotesApiService.instance.cbtStart(widget.noteId);
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CbtTakeScreen(examId: result.examId, questions: result.questions),
        ));
      }
    } on StudyNotesException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _startingCbt = false);
    }
  }

  void _openTheory(LibraryNoteModel note) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TheoryScreen(note: note)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Library')),
      body: FutureBuilder<LibraryNoteModel>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load this note',
              message: snap.error.toString(),
            );
          }
          final note = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PremiumCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 6),
                    Text('${note.levelDisplay} · ${note.courseName}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    Text('by ${note.owner}',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5)),
                    const SizedBox(height: 16),
                    if (note.testType == 'cbt')
                      GradientButton(
                        label: _startingCbt
                            ? 'Starting…'
                            : 'Take CBT (${note.questionCount} questions)',
                        icon: Icons.checklist_rounded,
                        loading: _startingCbt,
                        onPressed: _startingCbt ? null : _startCbt,
                      )
                    else
                      GradientButton(
                        label: 'Study Theory Questions',
                        icon: Icons.edit_note_rounded,
                        onPressed: () => _openTheory(note),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Summary'),
              PremiumCard(
                padding: const EdgeInsets.all(18),
                child: SelectableText(
                  note.summary ?? '',
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
