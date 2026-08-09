import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/supabase_service.dart';
import '../../shared/widgets/app_widgets.dart';
import '../../shared/widgets/skeletons.dart';

/// Reads from an app-owned `app_notifications` table (see sql/supabase_setup.sql).
/// FCM delivers the push; this screen shows the persisted history.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final user = SupabaseService.currentUser;
    if (user == null) return [];
    final rows = await SupabaseService.client
        .from('app_notifications')
        .select('id, title, body, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(100);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList(height: 64);
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications yet',
              message: 'Exam reminders and new materials will show up here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(() => _future = _load()),
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final n = items[i];
                final ts = DateTime.tryParse(n['created_at']?.toString() ?? '');
                return ListTile(
                  leading: const CircleAvatar(
                      child: Icon(Icons.notifications_outlined)),
                  title: Text(n['title']?.toString() ?? ''),
                  subtitle: Text(n['body']?.toString() ?? ''),
                  trailing: ts == null
                      ? null
                      : Text(DateFormat('MMM d').format(ts.toLocal()),
                          style: Theme.of(context).textTheme.bodySmall),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
