import 'package:flutter/material.dart';

import '../../core/services/leaderboard_api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<LeaderboardResult> _future;

  @override
  void initState() {
    super.initState();
    _future = LeaderboardApiService.instance.leaderboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leaderboard')),
      body: FutureBuilder<LeaderboardResult>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList();
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not load the leaderboard',
              message: snap.error.toString(),
              onRetry: () =>
                  setState(() => _future = LeaderboardApiService.instance.leaderboard()),
            );
          }
          final result = snap.data!;
          if (result.rows.isEmpty) {
            return const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'No rankings yet',
              message: 'Complete a few exams to appear on the leaderboard.',
            );
          }
          final myRankShown =
              result.myRow != null && result.rows.any((r) => r.studentId == result.myRow!.studentId);
          return RefreshIndicator(
            onRefresh: () async =>
                setState(() => _future = LeaderboardApiService.instance.leaderboard()),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (result.myRow != null && !myRankShown) ...[
                  _LeaderRow(row: result.myRow!, isMe: true),
                  const Divider(height: 28),
                ],
                for (final row in result.rows)
                  _LeaderRow(
                    row: row,
                    isMe: result.myRow != null && row.studentId == result.myRow!.studentId,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  const _LeaderRow({required this.row, required this.isMe});
  final LeaderboardRow row;
  final bool isMe;

  Color? _medalColor() {
    switch (row.rank) {
      case 1:
        return const Color(0xFFD4AF37);
      case 2:
        return const Color(0xFF9CA3AF);
      case 3:
        return const Color(0xFFB45309);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final medal = _medalColor();
    final card = PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: medal != null
                ? Icon(Icons.emoji_events_rounded, color: medal, size: 22)
                : Text('#${row.rank}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${row.name} (You)' : row.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                Text('${row.examsTaken} exams taken',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
              ],
            ),
          ),
          Text('${row.averageScore.toStringAsFixed(0)}%',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.brand)),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: isMe
          ? Container(
              decoration: BoxDecoration(
                color: AppTheme.brand.withOpacity(0.06),
                borderRadius: BorderRadius.circular(AppTheme.rLg),
              ),
              child: card,
            )
          : card,
    );
  }
}
