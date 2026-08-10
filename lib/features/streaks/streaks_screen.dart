import 'package:flutter/material.dart';

import '../../core/services/streaks_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';

class StreaksScreen extends StatefulWidget {
  const StreaksScreen({super.key});

  @override
  State<StreaksScreen> createState() => _StreaksScreenState();
}

class _StreaksScreenState extends State<StreaksScreen> {
  late Future<StreaksResult> _future;

  @override
  void initState() {
    super.initState();
    _future = StreaksApiService.instance.streaks();
  }

  IconData _iconFor(String code) {
    if (code.startsWith('streak_')) return Icons.local_fire_department_rounded;
    if (code.startsWith('exams_')) return Icons.fact_check_rounded;
    if (code == 'sharpshooter') return Icons.track_changes_rounded;
    return Icons.emoji_events_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Streaks & Badges')),
      body: FutureBuilder<StreaksResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load your streak',
              message: snap.error.toString(),
              onRetry: () =>
                  setState(() => _future = StreaksApiService.instance.streaks()),
            );
          }
          final result = snap.data!;
          return RefreshIndicator(
            onRefresh: () async =>
                setState(() => _future = StreaksApiService.instance.streaks()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PremiumCard(
                  gradient: AppTheme.brandGradient,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 44)),
                      const SizedBox(height: 8),
                      Text('${result.currentStreak}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
                      const Text('day streak', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatMini(label: 'Longest streak', value: '${result.longestStreak}'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatMini(label: 'Exams completed', value: '${result.examsCompleted}'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatMini(
                        label: 'Accuracy',
                        value: result.overallAccuracy == null
                            ? '—'
                            : '${result.overallAccuracy!.toStringAsFixed(0)}%',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Badges earned'),
                if (result.badges.isEmpty)
                  const EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: 'No badges yet',
                    message: 'Complete exams and build a study streak to earn your first badge.',
                  )
                else
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: result.badges
                        .map((b) => _BadgeTile(icon: _iconFor(b.code), label: b.label))
                        .toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5)),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.gold, Color(0xFFF4C542)]),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
