import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import '../ai_tutor/ai_tutor_screen.dart';
import '../cgpa/cgpa_calculator_screen.dart';
import '../insights/weak_topics_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../notifications/notifications_screen.dart';
import '../subjects/subjects_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final client = SupabaseService.client;
    final user = SupabaseService.currentUser;

    final subjectsCount =
        await client.from(AppConfig.tblSubject).count(CountOption.exact);

    int materialsCount = 0;
    try {
      materialsCount =
          await client.from(AppConfig.tblMaterial).count(CountOption.exact);
    } catch (_) {}

    bool subscribed = false;
    try {
      final sub = await client
          .from(AppConfig.tblAppProfile)
          .select('is_subscribed')
          .eq('user_id', user!.id)
          .maybeSingle();
      subscribed = (sub?['is_subscribed'] as bool?) ?? false;
    } catch (_) {}

    return _DashboardData(
      subjectsCount: subjectsCount,
      materialsCount: materialsCount,
      subscribed: subscribed,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.currentUser;
    final name =
        (user?.userMetadata?['full_name'] as String?)?.split(' ').first ??
            user?.email?.split('@').first ??
            'there';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const AppLogo(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting,
                            style:
                                TextStyle(color: scheme.onSurfaceVariant)),
                        Text(name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FutureBuilder<_DashboardData>(
              future: _future,
              builder: (context, snap) {
                final data = snap.data;
                final loading =
                    snap.connectionState == ConnectionState.waiting;
                return Column(
                  children: [
                    _HeroCard(
                      subscribed: data?.subscribed ?? false,
                      loading: loading,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.menu_book_rounded,
                            label: 'Courses',
                            value: loading ? '—' : '${data!.subjectsCount}',
                            color: AppTheme.brand,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.description_rounded,
                            label: 'Materials',
                            value: loading ? '—' : '${data!.materialsCount}',
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            const SectionHeader(title: 'Quick actions'),
            _ActionTile(
              icon: Icons.menu_book_rounded,
              title: 'Browse courses',
              subtitle: 'Notes, slides, past questions & CBT',
              color: AppTheme.brand,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SubjectsScreen()),
              ),
            ),
            _ActionTile(
              icon: Icons.calculate_rounded,
              title: 'CGPA Calculator',
              subtitle: 'Track GPA & CGPA across semesters',
              color: AppTheme.success,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const CgpaCalculatorScreen()),
              ),
            ),
            _ActionTile(
              icon: Icons.smart_toy_rounded,
              title: 'AI Tutor',
              subtitle: 'Ask questions, get step-by-step explanations',
              color: AppTheme.brand2,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiTutorScreen()),
              ),
            ),
            _ActionTile(
              icon: Icons.insights_rounded,
              title: 'My Insights',
              subtitle: 'Weak topics from your past exams & quizzes',
              color: AppTheme.warning,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WeakTopicsScreen()),
              ),
            ),
            _ActionTile(
              icon: Icons.emoji_events_rounded,
              title: 'Leaderboard',
              subtitle: 'See how you rank against other students',
              color: AppTheme.danger,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardData {
  final int subjectsCount;
  final int materialsCount;
  final bool subscribed;
  _DashboardData({
    required this.subjectsCount,
    required this.materialsCount,
    required this.subscribed,
  });
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.subscribed, required this.loading});
  final bool subscribed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const SkeletonBox(height: 140);
    return PremiumCard(
      gradient: AppTheme.brandGradient,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                        subscribed
                            ? Icons.workspace_premium_rounded
                            : Icons.lock_open_rounded,
                        color: Colors.white,
                        size: 16),
                    const SizedBox(width: 6),
                    Text(subscribed ? 'Premium' : 'Free plan',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            subscribed
                ? 'You have full access. Keep going! 🚀'
                : 'Unlock every material & past question',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.25),
          ),
          const SizedBox(height: 4),
          Text(
            subscribed
                ? 'Premium learning, anytime, anywhere.'
                : 'Upgrade to study without limits.',
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
