import 'package:flutter/material.dart';

import '../../core/services/foundation_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'institution_subjects_screen.dart';

class PredegreeHomeScreen extends StatefulWidget {
  const PredegreeHomeScreen({super.key});

  @override
  State<PredegreeHomeScreen> createState() => _PredegreeHomeScreenState();
}

class _PredegreeHomeScreenState extends State<PredegreeHomeScreen> {
  late Future<List<FoundationInstitution>> _future;

  @override
  void initState() {
    super.initState();
    _future = FoundationApiService.instance.predegreeInstitutions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pre-Degree')),
      body: FutureBuilder<List<FoundationInstitution>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load institutions',
              message: snap.error.toString(),
              onRetry: () =>
                  setState(() => _future = FoundationApiService.instance.predegreeInstitutions()),
            );
          }
          final institutions = snap.data ?? [];
          if (institutions.isEmpty) {
            return const EmptyState(
              icon: Icons.apartment_outlined,
              title: 'No institutions yet',
              message: 'Check back soon.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: institutions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final inst = institutions[i];
              return PremiumCard(
                padding: const EdgeInsets.all(14),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => InstitutionSubjectsScreen(
                          institutionSlug: inst.slug, institutionName: inst.name)),
                ),
                child: Row(
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        inst.shortName.isNotEmpty ? inst.shortName.substring(0, 1) : '?',
                        style: const TextStyle(
                            color: AppTheme.accent, fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inst.name,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Pill(inst.shortName, color: AppTheme.accent),
                              if (inst.subjectCount != null) ...[
                                const SizedBox(width: 8),
                                Text('${inst.subjectCount} subjects',
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        fontSize: 12.5)),
                              ],
                            ],
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
