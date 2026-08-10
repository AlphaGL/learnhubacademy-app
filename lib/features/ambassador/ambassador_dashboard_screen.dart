import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/ambassador_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'ambassador_payouts_screen.dart';
import 'ambassador_referrals_screen.dart';
import 'ambassador_settings_screen.dart';

/// [embedded] is true when shown inline from AmbassadorHomeScreen (which
/// already provides the Scaffold/AppBar) — avoids a double app bar.
class AmbassadorDashboardScreen extends StatefulWidget {
  const AmbassadorDashboardScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<AmbassadorDashboardScreen> createState() => _AmbassadorDashboardScreenState();
}

class _AmbassadorDashboardScreenState extends State<AmbassadorDashboardScreen> {
  late Future<AmbassadorDashboard> _future;

  @override
  void initState() {
    super.initState();
    _future = AmbassadorApiService.instance.dashboard();
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Referral link copied')));
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<AmbassadorDashboard>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SkeletonList();
        }
        if (snap.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load your dashboard',
            message: snap.error.toString(),
            onRetry: () =>
                setState(() => _future = AmbassadorApiService.instance.dashboard()),
          );
        }
        final d = snap.data!;
        return RefreshIndicator(
          onRefresh: () async =>
              setState(() => _future = AmbassadorApiService.instance.dashboard()),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PremiumCard(
                gradient: AppTheme.brandGradient,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Pill(d.tierLabel),
                        const Spacer(),
                        Text('₦${d.totalEarnings}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('Total earnings', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(AppTheme.rSm),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(d.referralUrl,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                            onPressed: () => _copyLink(d.referralUrl),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (d.nextTier != null) ...[
                PremiumCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${d.nextTier!.needed} more to reach ${d.nextTier!.label}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(value: d.progressPct / 100, minHeight: 8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                      child: _StatBox(label: 'Confirmed', value: '${d.stats['confirmed']}')),
                  const SizedBox(width: 10),
                  Expanded(child: _StatBox(label: 'Pending', value: '${d.stats['pending']}')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _StatBox(
                          label: 'Unpaid earnings', value: '₦${d.pendingEarnings}', small: true)),
                ],
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Manage'),
              PremiumCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.people_outline_rounded),
                      title: const Text('My Referrals'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AmbassadorReferralsScreen())),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet_outlined),
                      title: const Text('Payouts'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AmbassadorPayoutsScreen())),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.settings_outlined),
                      title: const Text('Bank details'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AmbassadorSettingsScreen())),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.embedded) return body;
    return Scaffold(appBar: AppBar(title: const Text('Ambassador Programme')), body: body);
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value, this.small = false});
  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: small ? 14 : 18)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5)),
        ],
      ),
    );
  }
}
