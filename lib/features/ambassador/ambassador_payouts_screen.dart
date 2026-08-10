import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/ambassador_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';
import 'ambassador_settings_screen.dart';

class AmbassadorPayoutsScreen extends StatefulWidget {
  const AmbassadorPayoutsScreen({super.key});

  @override
  State<AmbassadorPayoutsScreen> createState() => _AmbassadorPayoutsScreenState();
}

class _AmbassadorPayoutsScreenState extends State<AmbassadorPayoutsScreen> {
  late Future<PayoutsResult> _future;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _future = AmbassadorApiService.instance.payouts();
  }

  Future<void> _requestPayout() async {
    setState(() => _requesting = true);
    try {
      await AmbassadorApiService.instance.requestPayout();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Payout requested!')));
        setState(() => _future = AmbassadorApiService.instance.payouts());
      }
    } on AmbassadorException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.success;
      case 'failed':
        return AppTheme.danger;
      default:
        return AppTheme.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payouts')),
      body: FutureBuilder<PayoutsResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load payouts',
              message: snap.error.toString(),
              onRetry: () =>
                  setState(() => _future = AmbassadorApiService.instance.payouts()),
            );
          }
          final result = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              PremiumCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('₦${result.pendingEarnings}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
                    const Text('Confirmed, unpaid earnings'),
                    const SizedBox(height: 12),
                    if (!result.hasBankDetails)
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const AmbassadorSettingsScreen())),
                        child: const Text('Add bank details to request a payout'),
                      )
                    else if (result.hasOpenRequest)
                      const Text('A payout request is already being processed.',
                          style: TextStyle(color: AppTheme.warning))
                    else
                      GradientButton(
                        label: 'Request payout',
                        loading: _requesting,
                        onPressed: result.canRequest && !_requesting ? _requestPayout : null,
                      ),
                    if (result.hasBankDetails && !result.hasOpenRequest && !result.canRequest) ...[
                      const SizedBox(height: 8),
                      Text('Minimum payout is ₦${result.minPayout}.',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12.5)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'History'),
              if (result.payouts.isEmpty)
                const EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No payouts yet',
                  message: 'Your payout history will show up here.',
                )
              else
                for (final p in result.payouts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: PremiumCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('₦${p.amount}',
                                    style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(
                                  DateFormat('MMM d, y').format(
                                      DateTime.tryParse(p.initiatedAt) ?? DateTime.now()),
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Pill(p.status, color: _statusColor(p.status)),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
