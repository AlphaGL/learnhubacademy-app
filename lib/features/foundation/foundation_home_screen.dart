import 'package:flutter/material.dart';

import '../../core/services/foundation_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'jupeb_home_screen.dart';
import 'predegree_home_screen.dart';

/// Entry point for students not yet in university — JUPEB (Direct Entry)
/// and Pre-Degree programmes. Mirrors the website's foundation_home_view.
class FoundationHomeScreen extends StatefulWidget {
  const FoundationHomeScreen({super.key});

  @override
  State<FoundationHomeScreen> createState() => _FoundationHomeScreenState();
}

class _FoundationHomeScreenState extends State<FoundationHomeScreen> {
  late Future<FoundationHome> _future;

  @override
  void initState() {
    super.initState();
    _future = FoundationApiService.instance.home();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JUPEB & Pre-Degree')),
      body: FutureBuilder<FoundationHome>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList(count: 2, height: 140);
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load this page',
              message: snap.error.toString(),
              onRetry: () => setState(() => _future = FoundationApiService.instance.home()),
            );
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                "Not in university yet? We've got you too.",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                'Study notes and real past questions for JUPEB (Direct Entry into 200 '
                'Level) and university Pre-Degree programmes — instant explanations, no timer.',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.4),
              ),
              const SizedBox(height: 20),
              PremiumCard(
                gradient: AppTheme.brandGradient,
                padding: const EdgeInsets.all(20),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const JupebHomeScreen())),
                child: Row(
                  children: [
                    const Icon(Icons.school_rounded, color: Colors.white, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('JUPEB',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('${data.jupebSubjectCount} subjects — one national board',
                              style: TextStyle(color: Colors.white.withOpacity(0.9))),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              PremiumCard(
                padding: const EdgeInsets.all(20),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const PredegreeHomeScreen())),
                child: Row(
                  children: [
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.apartment_rounded, color: AppTheme.accent, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pre-Degree',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('${data.institutions.length} institutions — pick yours',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
