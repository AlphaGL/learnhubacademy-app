import 'package:flutter/material.dart';

import '../../core/services/foundation_api_service.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';

class TopicDetailScreen extends StatefulWidget {
  const TopicDetailScreen({super.key, required this.topicId, required this.topicTitle});
  final int topicId;
  final String topicTitle;

  @override
  State<TopicDetailScreen> createState() => _TopicDetailScreenState();
}

class _TopicDetailScreenState extends State<TopicDetailScreen> {
  late Future<FoundationTopic> _future;

  @override
  void initState() {
    super.initState();
    _future = FoundationApiService.instance.topicDetail(widget.topicId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.topicTitle)),
      body: FutureBuilder<FoundationTopic>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList(count: 4, height: 90);
          }
          if (snap.hasError) {
            final isSubscription = snap.error is FoundationException;
            return EmptyState(
              icon: isSubscription ? Icons.workspace_premium_outlined : Icons.cloud_off_rounded,
              title: isSubscription ? 'Subscriber feature' : 'Could not load this note',
              message: snap.error.toString(),
              onRetry: isSubscription
                  ? null
                  : () => setState(() => _future = FoundationApiService.instance.topicDetail(widget.topicId)),
            );
          }
          final topic = snap.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PremiumCard(
              padding: const EdgeInsets.all(18),
              child: Text(
                topic.content ?? '',
                style: const TextStyle(fontSize: 15, height: 1.6),
              ),
            ),
          );
        },
      ),
    );
  }
}
