import 'package:flutter/material.dart';

import '../../core/services/foundation_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'subject_detail_screen.dart';

class InstitutionSubjectsScreen extends StatefulWidget {
  const InstitutionSubjectsScreen({super.key, required this.institutionSlug, required this.institutionName});
  final String institutionSlug;
  final String institutionName;

  @override
  State<InstitutionSubjectsScreen> createState() => _InstitutionSubjectsScreenState();
}

class _InstitutionSubjectsScreenState extends State<InstitutionSubjectsScreen> {
  late Future<List<FoundationSubject>> _future;

  @override
  void initState() {
    super.initState();
    _future = FoundationApiService.instance.institutionSubjects(widget.institutionSlug);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.institutionName)),
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
              onRetry: () => setState(
                  () => _future = FoundationApiService.instance.institutionSubjects(widget.institutionSlug)),
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
                        color: AppTheme.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: AppTheme.accent),
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
