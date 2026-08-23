import 'package:flutter/material.dart';

import '../../core/services/studynotes_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'library_note_detail_screen.dart';

class StudyLibraryScreen extends StatefulWidget {
  const StudyLibraryScreen({super.key});

  @override
  State<StudyLibraryScreen> createState() => _StudyLibraryScreenState();
}

class _StudyLibraryScreenState extends State<StudyLibraryScreen> {
  String? _selectedLevel;
  late Future<({List<LibraryNoteModel> notes, List<LevelOption> levelChoices})> _future;

  @override
  void initState() {
    super.initState();
    _future = StudyNotesApiService.instance.library();
  }

  void _selectLevel(String? level) {
    setState(() {
      _selectedLevel = level;
      _future = StudyNotesApiService.instance.library(level: level);
    });
  }

  Future<void> _refresh() async {
    setState(() => _future = StudyNotesApiService.instance.library(level: _selectedLevel));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Library')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SkeletonList();
            }
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load the library',
                message: snap.error.toString(),
                onRetry: _refresh,
              );
            }
            final result = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Notes other students have published, organized by level.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 14),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _LevelChip(
                        label: 'All Levels',
                        selected: _selectedLevel == null,
                        onTap: () => _selectLevel(null),
                      ),
                      const SizedBox(width: 8),
                      for (final level in result.levelChoices) ...[
                        _LevelChip(
                          label: level.label,
                          selected: _selectedLevel == level.value,
                          onTap: () => _selectLevel(level.value),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (result.notes.isEmpty)
                  const EmptyState(
                    icon: Icons.school_outlined,
                    title: 'No published notes yet',
                    message: 'Publish one of your own summarized notes to get the library started!',
                  )
                else
                  for (final note in result.notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LibraryRow(
                        note: note,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => LibraryNoteDetailScreen(noteId: note.id),
                        )),
                      ),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.brand,
      labelStyle: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.note, required this.onTap});
  final LibraryNoteModel note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppTheme.brand.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              note.testType == 'cbt' ? Icons.checklist_rounded : Icons.edit_note_rounded,
              color: AppTheme.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                const SizedBox(height: 4),
                Text('${note.levelDisplay} · ${note.courseName} · ${note.testTypeDisplay}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                Text('by ${note.owner}',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
