import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/studynotes_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'study_note_create_screen.dart';
import 'study_note_detail_screen.dart';

class StudyNotesHomeScreen extends StatefulWidget {
  const StudyNotesHomeScreen({super.key});

  @override
  State<StudyNotesHomeScreen> createState() => _StudyNotesHomeScreenState();
}

class _StudyNotesHomeScreenState extends State<StudyNotesHomeScreen> {
  late Future<
      ({
        List<StudyNoteModel> notes,
        bool isSubscriber,
        bool usedToday,
        bool usedAudioToday,
        int maxUploadBytes
      })> _future;

  @override
  void initState() {
    super.initState();
    _future = StudyNotesApiService.instance.home();
  }

  Future<void> _refresh() async {
    setState(() => _future = StudyNotesApiService.instance.home());
    await _future;
  }

  void _openNote(int id) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => StudyNoteDetailScreen(noteId: id)))
        .then((_) => _refresh());
  }

  void _openCreate() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const StudyNoteCreateScreen()))
        .then((_) => _refresh());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Study Notes')),
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
                title: 'Could not load Study Notes',
                message: snap.error.toString(),
                onRetry: () => setState(() => _future = StudyNotesApiService.instance.home()),
              );
            }
            final result = snap.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PremiumCard(
                  gradient: AppTheme.brandGradient,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.file_present_rounded, color: Colors.white, size: 28),
                      const SizedBox(height: 10),
                      const Text('Upload a PDF, get an AI summary',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                      const SizedBox(height: 6),
                      Text(
                        result.isSubscriber
                            ? "You're a subscriber — Study Notes is free."
                            : 'Free for subscribers, or ₦500 per note.',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      const Text('Limited to one AI summary a day, so it stays available for everyone.',
                          style: TextStyle(color: Colors.white60, fontSize: 12.5)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _openCreate,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppTheme.brand,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.upload_file_rounded),
                          label: const Text('Upload a PDF', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Your notes'),
                if (result.notes.isEmpty)
                  const EmptyState(
                    icon: Icons.file_present_outlined,
                    title: 'No study notes yet',
                    message: 'Upload a PDF above to get your first AI summary.',
                  )
                else
                  for (final note in result.notes)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _NoteRow(note: note, onTap: () => _openNote(note.id)),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.onTap});
  final StudyNoteModel note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updated = DateTime.tryParse(note.updatedAt);
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
            child: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.brand, size: 20),
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
                Row(
                  children: [
                    Pill(note.status == 'ready' ? 'Summarized' : 'Not summarized',
                        color: note.status == 'ready' ? AppTheme.success : null),
                    const SizedBox(width: 6),
                    if (note.isUnlocked)
                      const Icon(Icons.lock_open_rounded, size: 13, color: AppTheme.success)
                    else
                      const Icon(Icons.lock_outline_rounded, size: 13, color: AppTheme.warning),
                    if (updated != null) ...[
                      const SizedBox(width: 6),
                      Text(DateFormat('MMM d').format(updated),
                          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
