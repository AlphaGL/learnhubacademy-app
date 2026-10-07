import 'package:flutter/material.dart';

import '../../core/services/ambassador_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'ambassador_dashboard_screen.dart';

/// Entry point — routes to the join screen or straight to the dashboard
/// depending on whether the student is already an ambassador.
class AmbassadorHomeScreen extends StatefulWidget {
  const AmbassadorHomeScreen({super.key});

  @override
  State<AmbassadorHomeScreen> createState() => _AmbassadorHomeScreenState();
}

class _AmbassadorHomeScreenState extends State<AmbassadorHomeScreen> {
  late Future<AmbassadorStatus> _future;

  @override
  void initState() {
    super.initState();
    _future = AmbassadorApiService.instance.status();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ambassador Programme')),
      body: FutureBuilder<AmbassadorStatus>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load this page',
              message: snap.error.toString(),
              onRetry: () =>
                  setState(() => _future = AmbassadorApiService.instance.status()),
            );
          }
          final status = snap.data!;
          if (status.isAmbassador) {
            return const AmbassadorDashboardScreen(embedded: true);
          }
          return _buildJoin(status);
        },
      ),
    );
  }

  Widget _buildJoin(AmbassadorStatus status) {
    final scheme = Theme.of(context).colorScheme;
    final tier1 = status.tierConfig['tier1'];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PremiumCard(
          gradient: AppTheme.brandGradient,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.people_alt_rounded, color: Colors.white, size: 32),
              const SizedBox(height: 12),
              const Text('Earn by referring students',
                  style: TextStyle(
                      color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Share your referral link. When someone subscribes through it, '
                'you earn a commission — paid monthly to your bank account.',
                style: TextStyle(color: Colors.white.withOpacity(0.9), height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'How tiers work'),
        for (final entry in status.tierConfig.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PremiumCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(entry.value.label,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                      Pill('${(double.parse(entry.value.commissionRate) * 100).toStringAsFixed(0)}%'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${entry.value.minReferrals}+ confirmed referrals',
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppTheme.rSm),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded, color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "The programme is invite-only. Our team reviews applications and "
                  "personally selects ambassadors — if you're picked, your account "
                  "gets activated for you.",
                  style: TextStyle(color: scheme.primary, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        if (tier1 != null) ...[
          const SizedBox(height: 20),
          const SectionHeader(title: 'Perks at LearnHub Ambassador'),
          for (final perk in tier1.perks)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(perk)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
