import 'package:flutter/material.dart';

import '../../core/services/foundation_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'subject_detail_screen.dart';

class JupebHomeScreen extends StatefulWidget {
  const JupebHomeScreen({super.key});

  @override
  State<JupebHomeScreen> createState() => _JupebHomeScreenState();
}

class _JupebHomeScreenState extends State<JupebHomeScreen> {
  late Future<List<FoundationSubject>> _future;

  @override
  void initState() {
    super.initState();
    _future = FoundationApiService.instance.jupebSubjects();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JUPEB Subjects')),
      body: FutureBuilder<List<FoundationSubject>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load subjects',
              message: snap.error.toString(),
              onRetry: () => setState(() => _future = FoundationApiService.instance.jupebSubjects()),
            );
          }
          final subjects = snap.data ?? [];
          if (subjects.isEmpty) {
            return const EmptyState(
              icon: Icons.menu_book_outlined,
              title: 'No subjects yet',
              message: 'Check back soon.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: subjects.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final s = subjects[i];
              final years = s.years.fold<int>(0, (sum, y) => sum + y.questionCount);
              return PremiumCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SubjectDetailScreen(subjectId: s.id, subjectName: s.name)),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.brand.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_iconFor(s.icon), color: AppTheme.brand),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            s.years.isEmpty
                                ? 'No past questions yet'
                                : '${s.years.length} year${s.years.length == 1 ? '' : 's'} · $years questions',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Maps the website's Bootstrap Icons class names to the closest Material
/// icon — the two icon sets don't line up 1:1, so this is a best-effort
/// mapping with a sensible fallback.
IconData _iconFor(String bootstrapIcon) {
  const map = {
    'bi-calculator': Icons.calculate_rounded,
    'bi-lightning-charge': Icons.bolt_rounded,
    'bi-droplet': Icons.science_rounded,
    'bi-flower1': Icons.eco_rounded,
    'bi-graph-up': Icons.show_chart_rounded,
    'bi-bank': Icons.account_balance_rounded,
    'bi-cash-coin': Icons.payments_rounded,
    'bi-tree': Icons.park_rounded,
    'bi-briefcase': Icons.work_rounded,
    'bi-book': Icons.menu_book_rounded,
    'bi-chat-quote': Icons.chat_rounded,
    'bi-globe-americas': Icons.public_rounded,
    'bi-hourglass-split': Icons.hourglass_bottom_rounded,
    'bi-translate': Icons.translate_rounded,
    'bi-journal-bookmark': Icons.bookmark_rounded,
    'bi-music-note-beamed': Icons.music_note_rounded,
    'bi-palette': Icons.palette_rounded,
  };
  return map[bootstrapIcon] ?? Icons.menu_book_rounded;
}
