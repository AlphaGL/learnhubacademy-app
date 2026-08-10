import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/ambassador_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';

class AmbassadorReferralsScreen extends StatefulWidget {
  const AmbassadorReferralsScreen({super.key});

  @override
  State<AmbassadorReferralsScreen> createState() => _AmbassadorReferralsScreenState();
}

class _AmbassadorReferralsScreenState extends State<AmbassadorReferralsScreen> {
  late Future<List<Referral>> _future;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _future = AmbassadorApiService.instance.referrals();
  }

  void _setFilter(String status) {
    setState(() {
      _statusFilter = status;
      _future = AmbassadorApiService.instance.referrals(status: status);
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'confirmed':
        return AppTheme.success;
      case 'paid':
        return AppTheme.brand;
      case 'rejected':
        return AppTheme.danger;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('My Referrals')),
      body: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final status in ['all', 'pending', 'paid', 'confirmed', 'rejected'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(status[0].toUpperCase() + status.substring(1)),
                      selected: _statusFilter == status,
                      onSelected: (_) => _setFilter(status),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Referral>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SkeletonList();
                }
                if (snap.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load referrals',
                    message: snap.error.toString(),
                    onRetry: () => _setFilter(_statusFilter),
                  );
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'No referrals yet',
                    message: 'Share your referral link to start earning.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final r = items[i];
                    final date = DateTime.tryParse(r.registeredAt);
                    return PremiumCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.referredEmail,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Pill(r.status, color: _statusColor(r.status)),
                                    if (date != null) ...[
                                      const SizedBox(width: 8),
                                      Text(DateFormat('MMM d, y').format(date),
                                          style: TextStyle(
                                              color: scheme.onSurfaceVariant, fontSize: 12)),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (r.commissionAmount != null)
                            Text('₦${r.commissionAmount}',
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
