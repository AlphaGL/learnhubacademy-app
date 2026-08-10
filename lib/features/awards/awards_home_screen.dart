import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/awards_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';

class AwardsHomeScreen extends StatefulWidget {
  const AwardsHomeScreen({super.key});

  @override
  State<AwardsHomeScreen> createState() => _AwardsHomeScreenState();
}

class _AwardsHomeScreenState extends State<AwardsHomeScreen> {
  late Future<AwardsHome> _future;
  int? _votingRepId;

  @override
  void initState() {
    super.initState();
    _future = AwardsApiService.instance.home();
  }

  Future<void> _refresh() async {
    setState(() => _future = AwardsApiService.instance.home());
    await _future;
  }

  Future<void> _onVoteTap(AwardsHome home, CourseRep rep) async {
    if (home.isSubscriber && !home.subscriberHasVoted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cast your free vote?'),
          content: Text('Vote for ${rep.name}? You get one free vote per season.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.of(context).pop(true), child: const Text('Vote')),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() => _votingRepId = rep.id);
      try {
        await AwardsApiService.instance.castVote(rep.id);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Voted for ${rep.name}!')));
          await _refresh();
        }
      } on AwardsException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        }
      } finally {
        if (mounted) setState(() => _votingRepId = null);
      }
      return;
    }
    _showBuyVotesSheet(home, rep);
  }

  Future<void> _showBuyVotesSheet(AwardsHome home, CourseRep rep) async {
    int quantity = 1;
    final price = double.tryParse(home.season?.paidVotePrice ?? '0') ?? 0;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Buy votes for ${rep.name}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              const SizedBox(height: 4),
              Text('₦${price.toStringAsFixed(0)} per vote',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove_rounded),
                    onPressed: quantity > 1 ? () => setSheetState(() => quantity--) : null,
                  ),
                  SizedBox(
                    width: 60,
                    child: Text('$quantity',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add_rounded),
                    onPressed: quantity < 1000 ? () => setSheetState(() => quantity++) : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Total: ₦${(price * quantity).toStringAsFixed(0)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Pay & Vote',
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _buyVotes(rep, quantity);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buyVotes(CourseRep rep, int quantity) async {
    setState(() => _votingRepId = rep.id);
    try {
      final url = await AwardsApiService.instance.initiatePayment(rep.id, quantity);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Complete payment in your browser, then come back and pull to refresh.'),
          duration: Duration(seconds: 5),
        ));
      }
    } on AwardsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _votingRepId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Excellence Awards')),
      body: FutureBuilder<AwardsHome>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load Excellence Awards',
              message: snap.error.toString(),
              onRetry: () => setState(() => _future = AwardsApiService.instance.home()),
            );
          }
          final home = snap.data!;
          if (home.season == null) {
            return const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'No active competition',
              message: 'Check back when a new Excellence Awards season starts.',
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                PremiumCard(
                  gradient: AppTheme.brandGradient,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(home.season!.title,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                      if (home.season!.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(home.season!.description,
                            style: const TextStyle(color: Colors.white70)),
                      ],
                      const SizedBox(height: 10),
                      if (home.isSubscriber && !home.subscriberHasVoted)
                        const Pill('You have a free vote — pick a candidate below')
                      else if (home.isSubscriber)
                        const Pill('Free vote used — buy more to support a candidate'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                for (final faculty in home.faculties) ...[
                  SectionHeader(title: faculty.name),
                  const SizedBox(height: 8),
                  for (final rep in faculty.reps) ...[
                    _RepCard(
                      rep: rep,
                      voting: _votingRepId == rep.id,
                      onVote: () => _onVoteTap(home, rep),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RepCard extends StatelessWidget {
  const _RepCard({required this.rep, required this.voting, required this.onVote});
  final CourseRep rep;
  final bool voting;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: rep.photo.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: rep.photo,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (context, _, __) => Container(
                        width: 56,
                        height: 56,
                        color: scheme.surfaceContainerHighest,
                        child: const Icon(Icons.person_rounded)),
                  )
                : Container(
                    width: 56,
                    height: 56,
                    color: scheme.surfaceContainerHighest,
                    child: const Icon(Icons.person_rounded)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (rep.rankLabel.isNotEmpty) ...[
                      Text(rep.rankLabel, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(rep.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    ),
                  ],
                ),
                Text(rep.department,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: rep.votePercentage / 100, minHeight: 6),
                ),
                const SizedBox(height: 4),
                Text('${rep.votePercentage.toStringAsFixed(1)}% · ${rep.rawVoteCount} votes',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          voting
              ? const SizedBox(
                  height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2))
              : FilledButton.tonal(onPressed: onVote, child: const Text('Vote')),
        ],
      ),
    );
  }
}
